import Foundation
import Testing
@testable import PocketPetCore

@Suite("ReminderPlanner")
struct ReminderPlannerTests {
    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func date(_ text: String, _ zone: String = "UTC") -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: zone)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: text)!
    }

    private var utc: ReminderPlanner { ReminderPlanner(calendar: calendar("UTC")) }

    @Test func hungerAndHygieneCrossingsAreScheduled() {
        let now = date("2026-10-17 09:00")
        // Hunger 0.4 reaches 0.7 in 5 hours. Hygiene 1.0 drops to 0.3 in about 23.3 hours.
        let plan = utc.plan(for: PetState(hunger: 0.4, hygiene: 1.0, bornAt: now), at: now)
        #expect(plan.map(\.kind) == [.hungry, .grubby])
        #expect(plan[0].fireDate == date("2026-10-17 14:00"))
        #expect(plan.count <= 2)
        #expect(plan[0].identifier == "reminder.hungry")
    }

    @Test func quietHoursPushToTheMorning() throws {
        let now = date("2026-10-17 18:00")
        // Hunger crosses at 23:00, inside quiet hours, so it moves to 08:00.
        let plan = utc.plan(for: PetState(hunger: 0.4, bornAt: now), at: now)
        let hungry = try #require(plan.first { $0.kind == .hungry })
        #expect(hungry.fireDate == date("2026-10-18 08:00"))
    }

    @Test func earlyMorningCrossingWaitsUntilEight() throws {
        let now = date("2026-10-17 01:00")
        let plan = utc.plan(for: PetState(hunger: 0.64, bornAt: now), at: now)
        let hungry = try #require(plan.first { $0.kind == .hungry })
        #expect(hungry.fireDate == date("2026-10-17 08:00"))
    }

    @Test func quietHoursFollowTheTimeZone() throws {
        // 10:00 UTC is 21:00 in Sydney (daylight time), so a 1 hour crossing lands in quiet hours there.
        let now = date("2026-10-17 10:00")
        let state = PetState(hunger: 0.64, bornAt: now)
        let inUTC = try #require(utc.plan(for: state, at: now).first { $0.kind == .hungry })
        #expect(inUTC.fireDate == date("2026-10-17 11:00"))
        let sydney = ReminderPlanner(calendar: calendar("Australia/Sydney"))
        let inSydney = try #require(sydney.plan(for: state, at: now).first { $0.kind == .hungry })
        #expect(inSydney.fireDate == date("2026-10-18 08:00", "Australia/Sydney"))
    }

    @Test func alreadyHungryGetsALaterNudgeNotAnInstantOne() throws {
        let now = date("2026-10-17 12:00")
        let plan = utc.plan(for: PetState(hunger: 0.9, bornAt: now), at: now)
        let hungry = try #require(plan.first { $0.kind == .hungry })
        #expect(hungry.fireDate == now.addingTimeInterval(15 * 60))
    }

    @Test func needsLandingTogetherShareOneNote() {
        let now = date("2026-10-17 20:00")
        // Both cross during quiet hours, so both move to 08:00 and merge.
        let plan = utc.plan(for: PetState(hunger: 0.6, hygiene: 0.35, bornAt: now), at: now)
        #expect(plan.map(\.kind) == [.hungryAndGrubby])
        #expect(plan[0].fireDate == date("2026-10-18 08:00"))
    }

    @Test func feedingPushesTheHungerReminderBack() throws {
        let now = date("2026-10-17 09:00")
        var engine = PetEngine(state: PetState(hunger: 0.6, bornAt: now))
        let before = try #require(utc.plan(for: engine.state, at: now).first { $0.kind == .hungry })
        engine.feed(at: now)
        let after = try #require(utc.plan(for: engine.state, at: now).first { $0.kind == .hungry })
        #expect(after.fireDate > before.fireDate)
    }

    @Test func asleepMeansNoRemindersUnlessTheMorningNoteIsOn() {
        let now = date("2026-10-17 22:30")
        let asleep = PetState(hunger: 0.9, hygiene: 0.1, isAsleep: true, bornAt: now)
        #expect(utc.plan(for: asleep, at: now).isEmpty)
        let plan = utc.plan(for: asleep, at: now, morningNote: true)
        #expect(plan.map(\.kind) == [.morning])
        #expect(plan[0].fireDate == date("2026-10-18 08:00"))
        #expect(plan[0].body.contains("Bip"))
    }

    @Test func copyIsKind() {
        let now = date("2026-10-17 09:00")
        let all = utc.plan(for: PetState(hunger: 0.9, hygiene: 0.2, bornAt: now), at: now)
            + utc.plan(for: PetState(hunger: 0.4, bornAt: now), at: now)
            + utc.plan(for: PetState(isAsleep: true, bornAt: now), at: now, morningNote: true)
        for reminder in all {
            let text = (reminder.title + " " + reminder.body).lowercased()
            for word in ["neglect", "sad", "starving", "dying", "forgot", "abandon", "!"] {
                #expect(!text.contains(word), "\(reminder.kind): \(text)")
            }
        }
    }

    @Test func quietHoursContains() {
        let cal = calendar("UTC")
        #expect(QuietHours.standard.contains(date("2026-10-17 21:00"), calendar: cal))
        #expect(QuietHours.standard.contains(date("2026-10-17 07:59"), calendar: cal))
        #expect(!QuietHours.standard.contains(date("2026-10-17 08:00"), calendar: cal))
        #expect(!QuietHours.standard.contains(date("2026-10-17 20:59"), calendar: cal))
    }
}
