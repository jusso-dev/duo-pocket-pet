import Foundation

/// Pets this one has met nearby, newest first. Only what the meetup shared:
/// the pet's name, life stage and mood. Saved by the app.
public struct PalBook: Codable, Equatable, Sendable {
    public struct Pal: Codable, Equatable, Sendable, Identifiable {
        /// The pair key from the transport, so a pal is the same pal across renames.
        public let id: String
        public var card: PetCard
        public let firstMet: Date
        public var lastMet: Date
        public var timesMet: Int
        public var gamesWon: Int
        public var gamesLost: Int
    }

    public static let capacity = 50

    public private(set) var pals: [Pal] = []

    public init() {}

    /// Records a meeting. A pal seen again moves to the top with its details refreshed.
    public mutating func met(_ card: PetCard, key: String, at now: Date) {
        if let i = pals.firstIndex(where: { $0.id == key }) {
            var pal = pals.remove(at: i)
            pal.card = card
            pal.lastMet = now
            pal.timesMet += 1
            pals.insert(pal, at: 0)
        } else {
            pals.insert(Pal(id: key, card: card, firstMet: now, lastMet: now, timesMet: 1, gamesWon: 0, gamesLost: 0), at: 0)
            if pals.count > Self.capacity { pals.removeLast(pals.count - Self.capacity) }
        }
    }

    /// Records a finished Leaf, Pebble, Twig game against a pal.
    public mutating func recordGame(with key: String, won: Bool) {
        guard let i = pals.firstIndex(where: { $0.id == key }) else { return }
        if won { pals[i].gamesWon += 1 } else { pals[i].gamesLost += 1 }
    }

    public func pal(_ key: String) -> Pal? {
        pals.first { $0.id == key }
    }
}
