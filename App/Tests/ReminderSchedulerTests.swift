import Foundation
import PocketPetCore
import Testing
@testable import Hingeling

/// Records what the scheduler asks of the notification centre.
private final class FakeCentre: ReminderCentre, @unchecked Sendable {
    private let lock = NSLock()
    private var _authRequests = 0
    private var _plans: [[Reminder]] = []
    let grants: Bool

    init(grants: Bool = true) { self.grants = grants }

    var authRequests: Int { lock.withLock { _authRequests } }
    var plans: [[Reminder]] { lock.withLock { _plans } }

    func requestAuthorization() async -> Bool {
        lock.withLock { _authRequests += 1 }
        return grants
    }

    func replacePending(with reminders: [Reminder]) async {
        lock.withLock { _plans.append(reminders) }
    }
}

@MainActor
@Suite("Reminders")
struct ReminderSchedulerTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func freshDefaults() -> UserDefaults {
        let name = "ReminderSchedulerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func eventually(_ timeout: Duration = .seconds(5), _ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return condition()
    }

    private func model(_ centre: FakeCentre, defaults: UserDefaults, pet: PetState) -> AppModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        // Quiet hours that never apply, so the dates are easy to check.
        let planner = ReminderPlanner(quietHours: QuietHours(startHour: 0, endHour: 0), calendar: calendar)
        let scheduler = ReminderScheduler(centre: centre, defaults: defaults, planner: planner, clock: { [t0] in t0 })
        return AppModel(store: InMemoryPetStore(pet), fold: StaticFoldStateService(.unavailable), reminders: scheduler, clock: { [t0] in t0 })
    }

    @Test func permissionIsAskedAfterTheFirstFeedOnly() async {
        let centre = FakeCentre()
        let model = model(centre, defaults: freshDefaults(), pet: PetState(hunger: 0.8, bornAt: t0))
        #expect(!model.remindersOffered)
        _ = model.perform(.play)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(centre.authRequests == 0)
        #expect(centre.plans.isEmpty)

        #expect(model.perform(.feed) == .applied)
        #expect(model.remindersOffered)
        #expect(await eventually { centre.authRequests == 1 })
        #expect(await eventually { !centre.plans.isEmpty })

        _ = model.perform(.feed)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(centre.authRequests == 1)
    }

    @Test func feedingPushesTheHungerReminderBack() async throws {
        let centre = FakeCentre()
        let defaults = freshDefaults()
        let model = model(centre, defaults: defaults, pet: PetState(hunger: 0.8, bornAt: t0))
        _ = model.perform(.feed)
        #expect(await eventually { !centre.plans.isEmpty })
        let first = try #require(centre.plans.last?.first { $0.kind == .hungry })
        _ = model.perform(.feed)
        #expect(await eventually { (centre.plans.last?.first { $0.kind == .hungry }?.fireDate ?? .distantPast) > first.fireDate })
    }

    @Test func asleepClearsRemindersUnlessTheMorningNoteIsOn() async {
        let centre = FakeCentre()
        let model = model(centre, defaults: freshDefaults(), pet: PetState(hunger: 0.8, bornAt: t0))
        _ = model.perform(.feed)
        #expect(await eventually { !(centre.plans.last ?? []).isEmpty })
        _ = model.perform(.sleep)
        #expect(await eventually { centre.plans.last == [] })
        model.setMorningNote(true)
        #expect(model.morningNoteEnabled)
        #expect(await eventually { centre.plans.last?.map(\.kind) == [.morning] })
    }

    @Test func deniedPermissionSchedulesNothing() async {
        let centre = FakeCentre(grants: false)
        let model = model(centre, defaults: freshDefaults(), pet: PetState(hunger: 0.8, bornAt: t0))
        _ = model.perform(.feed)
        #expect(await eventually { centre.authRequests == 1 })
        // Saves still replan, but the system drops requests without permission.
        // The scheduler never asks again.
        _ = model.perform(.play)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(centre.authRequests == 1)
    }
}
