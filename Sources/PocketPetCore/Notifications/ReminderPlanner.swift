import Foundation

/// A local notification to schedule.
public struct Reminder: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case hungry
        case grubby
        /// Both needs land at the same time, so they share one note.
        case hungryAndGrubby
        /// The opt-in good morning note while the pet sleeps.
        case morning
    }

    public let kind: Kind
    public let fireDate: Date
    public let title: String
    public let body: String

    /// Stable per kind, so a new plan replaces the old request.
    public var identifier: String { "reminder.\(kind.rawValue)" }
}

/// The hours when no reminder fires. Anything that would land inside them is
/// moved to the end, in the player's local time.
public struct QuietHours: Equatable, Sendable {
    /// Minutes after midnight.
    public var start: Int
    public var end: Int

    /// 21:00 to 08:00.
    public static let standard = QuietHours(startHour: 21, endHour: 8)

    public init(startHour: Int, startMinute: Int = 0, endHour: Int, endMinute: Int = 0) {
        start = startHour * 60 + startMinute
        end = endHour * 60 + endMinute
    }

    /// True when `date` falls inside quiet hours in `calendar`'s time zone.
    public func contains(_ date: Date, calendar: Calendar) -> Bool {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if start == end { return false }
        if start < end { return minute >= start && minute < end }
        return minute >= start || minute < end
    }

    /// The first moment at or after `date` that is outside quiet hours.
    public func nextAllowed(after date: Date, calendar: Calendar) -> Date {
        guard contains(date, calendar: calendar) else { return date }
        return nextEnd(after: date, calendar: calendar)
    }

    /// The next time quiet hours end, strictly after `date`.
    public func nextEnd(after date: Date, calendar: Calendar) -> Date {
        let components = DateComponents(hour: end / 60, minute: end % 60, second: 0)
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime) ?? date
    }
}

/// Works out when the pet will next need the player, as gentle local reminders.
/// Pure: the caller passes the time and the calendar (with its time zone).
public struct ReminderPlanner: Sendable {
    public var rules: PetRules
    public var quietHours: QuietHours
    public var calendar: Calendar
    /// The soonest a reminder fires, so a pet that already needs care when the
    /// app closes gets a nudge a little later rather than straight away.
    public var minimumLead: TimeInterval

    public init(rules: PetRules = .standard, quietHours: QuietHours = .standard, calendar: Calendar = .current, minimumLead: TimeInterval = 15 * 60) {
        self.rules = rules
        self.quietHours = quietHours
        self.calendar = calendar
        self.minimumLead = minimumLead
    }

    /// At most two reminders, earliest first.
    ///
    /// Awake: when hunger will reach `Mood.hungryAt` and when hygiene will drop
    /// to `Mood.grubbyAt`. Asleep: nothing, except the morning note when
    /// `morningNote` is on.
    public func plan(for state: PetState, at now: Date, morningNote: Bool = false) -> [Reminder] {
        let name = state.name
        if state.isAsleep {
            guard morningNote else { return [] }
            return [reminder(.morning, at: quietHours.nextEnd(after: now, calendar: calendar), name: name)]
        }

        var due: [(Reminder.Kind, Date)] = []
        if let hungry = crossing(from: state.hunger, to: Mood.hungryAt, perHour: rules.awake.hungerGainPerHour, at: now) {
            due.append((.hungry, hungry))
        }
        if let grubby = crossing(from: 1 - state.hygiene, to: 1 - Mood.grubbyAt, perHour: rules.awake.hygieneLossPerHour, at: now) {
            due.append((.grubby, grubby))
        }
        let adjusted = due
            .map { ($0.0, quietHours.nextAllowed(after: $0.1, calendar: calendar)) }
            .sorted { $0.1 < $1.1 }

        if adjusted.count == 2, adjusted[0].1 == adjusted[1].1 {
            return [reminder(.hungryAndGrubby, at: adjusted[0].1, name: name)]
        }
        return adjusted.map { reminder($0.0, at: $0.1, name: name) }
    }

    /// When a meter rising at `perHour` reaches `threshold`, no sooner than `minimumLead` from now.
    private func crossing(from value: Double, to threshold: Double, perHour: Double, at now: Date) -> Date? {
        guard perHour > 0 else { return nil }
        let hours = max(0, threshold - value) / perHour
        // Whole seconds, so rounding in the rates doesn't leave a fire date a hair early.
        return now.addingTimeInterval(max(minimumLead, (hours * 3600).rounded()))
    }

    private func reminder(_ kind: Reminder.Kind, at date: Date, name: String) -> Reminder {
        switch kind {
        case .hungry:
            Reminder(kind: kind, fireDate: date, title: "\(name) is getting peckish", body: "A snack would go down nicely when you have a moment.")
        case .grubby:
            Reminder(kind: kind, fireDate: date, title: "\(name) could use a wash", body: "Bath time is a good time, whenever suits you.")
        case .hungryAndGrubby:
            Reminder(kind: kind, fireDate: date, title: "\(name) would love some company", body: "A snack and a wash would go down nicely when you have a moment.")
        case .morning:
            Reminder(kind: kind, fireDate: date, title: "Good morning", body: "\(name) is ready to wake up whenever you are.")
        }
    }
}
