import Foundation
import PocketPetCore
import UserNotifications

/// Where reminders go. The system notification centre in the app, a fake in tests.
protocol ReminderCentre: Sendable {
    func requestAuthorization() async -> Bool
    /// Replaces every pending Hingeling reminder with `reminders`.
    func replacePending(with reminders: [Reminder]) async
}

struct SystemReminderCentre: ReminderCentre {
    static let identifiers = ["hungry", "grubby", "hungryAndGrubby", "morning"].map { "reminder.\($0)" }

    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func replacePending(with reminders: [Reminder]) async {
        let centre = UNUserNotificationCenter.current()
        centre.removePendingNotificationRequests(withIdentifiers: Self.identifiers)
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, reminder.fireDate.timeIntervalSinceNow), repeats: false)
            try? await centre.add(UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger))
        }
    }
}

/// Plans reminders from the saved pet and hands them to the centre, one plan
/// at a time and in order, so a quick run of saves can't leave a stale plan behind.
///
/// Nothing is scheduled, and permission isn't asked, until the player's first
/// feed. After that every save replans, so feeding cancels a hunger reminder.
final class ReminderScheduler: @unchecked Sendable {
    private enum Key {
        static let asked = "reminders.permissionAsked"
        static let morningNote = "reminders.morningNote"
    }

    private let lock = NSLock()
    private let centre: any ReminderCentre
    private let defaults: UserDefaults
    private let planner: ReminderPlanner
    private let clock: @Sendable () -> Date
    private let plans: AsyncStream<[Reminder]>.Continuation
    private var latest: PetState?

    init(
        centre: any ReminderCentre = SystemReminderCentre(),
        defaults: UserDefaults = .standard,
        planner: ReminderPlanner = ReminderPlanner(),
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.centre = centre
        self.defaults = defaults
        self.planner = planner
        self.clock = clock
        let (stream, continuation) = AsyncStream<[Reminder]>.makeStream(bufferingPolicy: .bufferingNewest(1))
        plans = continuation
        Task.detached { [centre] in
            for await plan in stream { await centre.replacePending(with: plan) }
        }
    }

    deinit {
        plans.finish()
    }

    var hasAskedPermission: Bool {
        lock.withLock { defaults.bool(forKey: Key.asked) }
    }

    var morningNote: Bool {
        get { lock.withLock { defaults.bool(forKey: Key.morningNote) } }
        set {
            lock.withLock { defaults.set(newValue, forKey: Key.morningNote) }
            replan()
        }
    }

    /// Called after every save.
    func stateSaved(_ state: PetState) {
        lock.withLock { latest = state }
        replan()
    }

    /// Called after a feed lands. Asks for permission the first time only.
    func playerFed() {
        let firstTime: Bool = lock.withLock {
            guard !defaults.bool(forKey: Key.asked) else { return false }
            defaults.set(true, forKey: Key.asked)
            return true
        }
        guard firstTime else { return }
        Task { [weak self, centre] in
            if await centre.requestAuthorization() { self?.replan() }
        }
    }

    /// The plan for the latest saved pet, or nil before the player's first feed.
    func currentPlan() -> [Reminder]? {
        let (asked, state, morning) = lock.withLock { (defaults.bool(forKey: Key.asked), latest, defaults.bool(forKey: Key.morningNote)) }
        guard asked, let state else { return nil }
        return planner.plan(for: state, at: clock(), morningNote: morning)
    }

    private func replan() {
        guard let plan = currentPlan() else { return }
        plans.yield(plan)
    }
}

/// Wraps the real store so every successful save replans reminders.
final class ReminderObservingStore: PetStore, @unchecked Sendable {
    let base: any PetStore
    let scheduler: ReminderScheduler

    init(base: any PetStore, scheduler: ReminderScheduler) {
        self.base = base
        self.scheduler = scheduler
    }

    func load() throws -> PetState? { try base.load() }

    func save(_ state: PetState) throws {
        try base.save(state)
        scheduler.stateSaved(state)
    }

    func preserveUnreadableSave(at date: Date) throws -> URL? {
        try base.preserveUnreadableSave(at: date)
    }
}
