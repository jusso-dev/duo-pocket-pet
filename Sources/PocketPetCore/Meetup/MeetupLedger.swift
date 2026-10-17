import Foundation

/// Daily limits per pair of pets, so meeting the same friend over and over
/// doesn't pump a pet's meters. Saved by the app.
public struct MeetupLedger: Codable, Equatable, Sendable {
    /// Pair key to the day ("2026-10-17", in the player's calendar) of the last dance boost.
    public private(set) var lastBoost: [String: String] = [:]
    /// "day|kind|pair" to how many times that kind has counted today.
    public private(set) var usage: [String: Int] = [:]

    public init() {}

    /// The happiness one dance together adds.
    public static let boost: Meter = 0.15
    /// Gifts that count from one friend in a day. Later ones are thanked but do nothing.
    public static let giftsPerPairPerDay = 3
    /// Leaf, Pebble, Twig games that count with one friend in a day.
    public static let gamesPerPairPerDay = 3

    /// Records a dance boost for `pair` and returns true, or returns false if
    /// this pair already had one today.
    public mutating func claim(pair: String, at now: Date, calendar: Calendar) -> Bool {
        let day = Self.dayKey(now, calendar: calendar)
        if lastBoost[pair] == day { return false }
        lastBoost[pair] = day
        // Keep the ledger small: drop days that are no longer today.
        lastBoost = lastBoost.filter { $0.value == day }
        return true
    }

    /// Records a gift received from `pair`, or returns false past today's limit.
    public mutating func claimGift(pair: String, at now: Date, calendar: Calendar) -> Bool {
        claimUsage("gift", pair: pair, limit: Self.giftsPerPairPerDay, at: now, calendar: calendar)
    }

    /// Records a finished game with `pair`, or returns false past today's limit.
    public mutating func claimGame(pair: String, at now: Date, calendar: Calendar) -> Bool {
        claimUsage("game", pair: pair, limit: Self.gamesPerPairPerDay, at: now, calendar: calendar)
    }

    private mutating func claimUsage(_ kind: String, pair: String, limit: Int, at now: Date, calendar: Calendar) -> Bool {
        let day = Self.dayKey(now, calendar: calendar)
        usage = usage.filter { $0.key.hasPrefix(day + "|") }
        let key = "\(day)|\(kind)|\(pair)"
        let used = usage[key, default: 0]
        guard used < limit else { return false }
        usage[key] = used + 1
        return true
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastBoost = try c.decodeIfPresent([String: String].self, forKey: .lastBoost) ?? [:]
        usage = try c.decodeIfPresent([String: Int].self, forKey: .usage) ?? [:]
    }
}
