import Foundation
import Observation
import PocketPetCore
#if canImport(os)
import os
#endif

/// The app's single source of truth. Listens to a `FoldStateService`,
/// forwards postures and button taps to `PetSession`, and ticks every 30 seconds.
@MainActor
@Observable
final class AppModel {
    private(set) var session: PetSession
    private(set) var lastRefusal: ActionResult.Refusal?
    /// Why the pet can't be kept between launches, if the file store failed.
    let storageFallbackReason: String?
    /// True once the player has dismissed the storage notice for this launch.
    private(set) var storageNoticeDismissed = false
    let hinge: HingeFoldStateService?
    /// Local reminders, or nil in tests and previews.
    @ObservationIgnored let reminders: ReminderScheduler?
    /// True once the player has fed the pet, which is when reminders are first offered.
    private(set) var remindersOffered: Bool
    /// The opt-in good morning note while the pet sleeps.
    private(set) var morningNoteEnabled: Bool
    private let fold: any FoldStateService
    private let clock: @Sendable () -> Date
    private let tickInterval: Duration
    @ObservationIgnored private var foldTask: Task<Void, Never>?
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    /// True while a `run()` is listening. Every scene's `RootView` calls `run()`,
    /// and only the first one may subscribe and tick.
    @ObservationIgnored private(set) var isRunning = false

    var state: PetState { session.state }
    var scene: PetScene { session.scene }

    init(
        store: any PetStore,
        fold: any FoldStateService,
        hinge: HingeFoldStateService? = nil,
        reminders: ReminderScheduler? = nil,
        rules: PetRules = .standard,
        clock: @escaping @Sendable () -> Date = { Date() },
        tickInterval: Duration = .seconds(30)
    ) {
        self.fold = fold
        self.hinge = hinge
        self.reminders = reminders
        self.clock = clock
        self.tickInterval = tickInterval
        remindersOffered = reminders?.hasAskedPermission ?? false
        morningNoteEnabled = reminders?.morningNote ?? false
        storageFallbackReason = (store as? InMemoryPetStore)?.fallbackReason
        // Every save replans the reminders, so feeding cancels a hunger reminder.
        let observed: any PetStore = reminders.map { ReminderObservingStore(base: store, scheduler: $0) } ?? store
        session = PetSession(store: observed, rules: rules, now: clock())
        session.apply(fold.current, at: clock())
    }

    static func live(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppModel {
        #if targetEnvironment(simulator)
        // UI tests, screenshots and demos. See `DebugLaunchOptions`.
        let options = DebugLaunchOptions(arguments: arguments, now: Date())
        if options.isActive {
            let store: any PetStore = options.pet.map { InMemoryPetStore($0) } ?? makeStore()
            if options.playsDemoScript {
                // Start like the live hinge service, which reports `.unavailable`
                // until its first callback. The demo script then closes it at once.
                let mock = MockFoldStateService(initial: .unavailable)
                Task { await mock.play(MockFoldStateService.demoScript) }
                return AppModel(store: store, fold: mock)
            }
            if let fold = options.fold {
                return AppModel(store: store, fold: MockFoldStateService(initial: fold), reminders: debugReminders(options), rules: options.rules)
            }
            return liveFold(store: store, reminders: debugReminders(options), rules: options.rules)
        }
        #endif
        return liveFold(store: makeStore(), reminders: ReminderScheduler())
    }

    /// Reminders on the simulator, planned with the debug rules so `-fastRules` speeds them up too.
    private static func debugReminders(_ options: DebugLaunchOptions) -> ReminderScheduler {
        ReminderScheduler(planner: ReminderPlanner(rules: options.rules, minimumLead: options.fastRules ? 10 : 15 * 60))
    }

    /// The hinge on iOS 27.1 and later. Earlier systems have no hinge API at
    /// all, so they get a fixed `.unavailable` and the standard layout.
    private static func liveFold(store: any PetStore, reminders: ReminderScheduler, rules: PetRules = .standard) -> AppModel {
        if #available(iOS 27.1, *) {
            let hinge = HingeFoldStateService()
            return AppModel(store: store, fold: hinge, hinge: hinge, reminders: reminders, rules: rules)
        }
        return AppModel(store: store, fold: StaticFoldStateService(.unavailable), reminders: reminders, rules: rules)
    }

    /// The file store, or an in-memory one that remembers why, so the app can
    /// tell the player that nothing will be kept. The failure is logged.
    static func makeStore(_ makeFileStore: () throws -> any PetStore = { try FilePetStore.standard() }) -> any PetStore {
        do {
            return try makeFileStore()
        } catch {
            #if canImport(os)
            Logger(subsystem: "dev.jusso.hingeling", category: "storage")
                .error("No file store, using memory only: \(String(describing: error), privacy: .public)")
            #endif
            return InMemoryPetStore(fallbackReason: String(describing: error))
        }
    }

    /// A short message about saving, for the banner, or nil when all is well.
    /// `recoveredFromError` and `lastSaveError` used to be set but never shown.
    var storageNotice: String? {
        let name = session.state.name
        if session.lastSaveError != nil, session.isSavingEnabled, storageFallbackReason == nil {
            // A failed write. Shown until a save works again, even if dismissed.
            return "Couldn't save \(name) just now. The app will try again shortly."
        }
        if storageNoticeDismissed { return nil }
        if storageFallbackReason != nil {
            return "\(name) can't be saved on this device right now, so progress will be lost when the app closes."
        }
        if !session.isSavingEnabled {
            return "Your saved pet couldn't be read, so this session won't be saved. The old save hasn't been touched."
        }
        if session.recoveredFromError != nil {
            let kept = session.preservedUnreadableSave.map { " A copy was kept as \($0.lastPathComponent)." } ?? ""
            return "Your saved pet couldn't be read, so \(name) has just hatched.\(kept)"
        }
        return nil
    }

    /// Hides the notice for the rest of this launch. A failed write still shows,
    /// because it is new information each time.
    func dismissStorageNotice() {
        storageNoticeDismissed = true
    }

    /// Starts listening. Called from `RootView.task`, cancelled with the view.
    ///
    /// The 30-second tick runs in its own task rather than a task group, because
    /// Swift 6.4's region-based isolation checker rejects `@MainActor` child tasks
    /// that capture `self` here ("pattern ... does not understand how to check").
    ///
    /// The app supports multiple scenes, and each one runs this. A second call
    /// while one is already running returns straight away, so there is only
    /// ever one fold subscription and one ticker.
    func run() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        let stream = fold.updates
        let interval = tickInterval
        let ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let self, !Task.isCancelled else { return }
                self.session.tick(to: self.clock())
            }
        }
        await withTaskCancellationHandler {
            for await posture in stream { apply(posture) }
            // Keep ticking after the fold stream ends, until the view cancels us.
            await ticker.value
        } onCancel: {
            ticker.cancel()
        }
    }

    func apply(_ posture: FoldPosture) {
        session.apply(posture, at: clock())
    }

    /// Writes any half-fold angle changes that are only in memory. Called when
    /// the scene leaves the foreground, so nothing is lost if the app is killed.
    func enteredBackground() {
        session.saveIfNeeded()
    }

    /// Catches the meters up straight away when the app comes back to the
    /// foreground, instead of showing stale values until the next 30 second tick.
    func becameActive() {
        session.tick(to: clock())
    }

    /// Cheers for the pet on the half-fold stage.
    @discardableResult
    func cheer() -> CheerResult {
        session.cheer(at: clock())
    }

    @discardableResult
    func perform(_ action: PetAction) -> ActionResult {
        let result = session.perform(action, at: clock())
        if case .refused(let reason) = result { lastRefusal = reason } else { lastRefusal = nil }
        if action == .feed, result == .applied, let reminders {
            // Permission is asked after the first feed, never at launch.
            reminders.playerFed()
            remindersOffered = true
        }
        return result
    }

    func setMorningNote(_ enabled: Bool) {
        reminders?.morningNote = enabled
        morningNoteEnabled = enabled
    }
}

extension ActionResult {
    /// What VoiceOver should say after a button tap, applied or refused.
    func announcement(for action: PetAction, petName: String) -> String {
        switch self {
        case .refused(let reason):
            return reason.message(petName: petName)
        case .applied:
            switch action {
            case .feed: return "You fed \(petName)."
            case .clean: return "\(petName) is squeaky clean."
            case .play: return "You played with \(petName)."
            case .sleep: return "\(petName) is going to sleep."
            case .wake: return "\(petName) is awake."
            }
        }
    }
}

extension ActionResult.Refusal {
    func message(petName: String) -> String {
        switch self {
        case .asleep: "\(petName) is asleep. Let them rest."
        case .alreadyAsleep: "\(petName) is already asleep."
        case .alreadyAwake: "\(petName) is already awake."
        case .notHungry: "\(petName) is full right now."
        case .alreadyClean: "\(petName) is already squeaky clean."
        case .tooTired: "\(petName) is too tired to play. Try a nap."
        }
    }
}
