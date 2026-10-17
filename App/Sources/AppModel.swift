import Foundation
import Observation
import PocketPetCore

/// The app's single source of truth. Listens to a `FoldStateService`,
/// forwards postures and button taps to `PetSession`, and ticks every 30 seconds.
@MainActor
@Observable
final class AppModel {
    private(set) var session: PetSession
    private(set) var lastRefusal: ActionResult.Refusal?
    let hinge: HingeFoldStateService?
    private let fold: any FoldStateService
    private let clock: @Sendable () -> Date
    @ObservationIgnored private var foldTask: Task<Void, Never>?
    @ObservationIgnored private var tickTask: Task<Void, Never>?

    var state: PetState { session.state }
    var scene: PetScene { session.scene }

    init(
        store: any PetStore,
        fold: any FoldStateService,
        hinge: HingeFoldStateService? = nil,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fold = fold
        self.hinge = hinge
        self.clock = clock
        session = PetSession(store: store, now: clock())
        session.apply(fold.current, at: clock())
    }

    static func live() -> AppModel {
        let store: any PetStore = (try? FilePetStore.standard()) ?? InMemoryPetStore()
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-mockFold") {
            let mock = MockFoldStateService(initial: .closed)
            Task { await mock.play(MockFoldStateService.demoScript) }
            return AppModel(store: store, fold: mock)
        }
        #endif
        let hinge = HingeFoldStateService()
        return AppModel(store: store, fold: hinge, hinge: hinge)
    }

    /// Starts listening. Called from `RootView.task`, cancelled with the view.
    func run() async {
        let stream = fold.updates
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                for await posture in stream { self.apply(posture) }
            }
            group.addTask { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    self.session.tick(to: self.clock())
                }
            }
        }
    }

    func apply(_ posture: FoldPosture) {
        session.apply(posture, at: clock())
    }

    @discardableResult
    func perform(_ action: PetAction) -> ActionResult {
        let result = session.perform(action, at: clock())
        if case .refused(let reason) = result { lastRefusal = reason } else { lastRefusal = nil }
        return result
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
