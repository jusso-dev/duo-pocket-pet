import Foundation

/// What one pet tells another. Only the pet's name, life stage and mood: never
/// anything about the player or the device.
public struct PetCard: Codable, Equatable, Sendable {
    public var name: String
    public var stage: LifeStage
    public var mood: Mood

    public init(name: String, stage: LifeStage, mood: Mood) {
        // Names are capped so a peer can't send a wall of text.
        self.name = String(name.prefix(PetCard.maxNameLength))
        self.stage = stage
        self.mood = mood
    }

    public init(state: PetState) {
        self.init(name: state.name, stage: state.lifeStage, mood: state.mood)
    }

    public static let maxNameLength = 40

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try c.decode(String.self, forKey: .name),
            stage: try c.decode(LifeStage.self, forKey: .stage),
            mood: try c.decode(Mood.self, forKey: .mood)
        )
    }
}

/// A present one pet sends another.
public enum Gift: String, Codable, CaseIterable, Sendable {
    /// Lowers hunger a little.
    case snack
    /// Raises happiness a little.
    case toy
    /// Freshens up: raises cleanliness a little.
    case bath
}

/// A move in Leaf, Pebble, Twig: leaf wraps pebble, pebble snaps twig, twig pokes through leaf.
public enum GameMove: String, Codable, CaseIterable, Sendable {
    case leaf
    case pebble
    case twig

    /// True when this move beats `other`.
    public func beats(_ other: GameMove) -> Bool {
        switch (self, other) {
        case (.leaf, .pebble), (.pebble, .twig), (.twig, .leaf): true
        default: false
        }
    }
}

/// The meetup message set. Small, versioned and Codable.
public enum MeetupMessage: Equatable, Sendable {
    /// First message each side sends, with its protocol version.
    case hello(version: Int, pet: PetCard)
    /// The pet's mood changed while together.
    case pose(Mood)
    /// Ready to dance together. The dance starts once both sides have sent this.
    case playInvite
    /// A present for the other pet.
    case gift(Gift)
    /// Leaf, Pebble, Twig: ask to play, agree, a move for a round, or stop.
    case gameInvite
    case gameAccept
    case gameMove(round: Int, move: GameMove)
    case gameQuit
    /// Leaving, with the reason.
    case goodbye(MeetupEndReason)
}

public enum MeetupEndReason: String, Codable, Equatable, Sendable {
    /// Said goodbye after spending time together.
    case finished
    /// The other side speaks a different protocol version.
    case versionMismatch
    /// No hello in time.
    case timedOut
    /// The connection dropped part way.
    case disconnected
    /// The player turned meetups off or left the scene.
    case cancelled
}

public enum MeetupCodec {
    /// Bump when the message set changes in a way older builds can't read.
    public static let version = 1

    private struct Wire: Codable {
        var type: String
        var version: Int?
        var pet: PetCard?
        var mood: Mood?
        var reason: MeetupEndReason?
        var gift: Gift?
        var round: Int?
        var move: GameMove?
    }

    public static func encode(_ message: MeetupMessage) throws -> Data {
        let wire: Wire = switch message {
        case .hello(let version, let pet): Wire(type: "hello", version: version, pet: pet)
        case .pose(let mood): Wire(type: "pose", mood: mood)
        case .playInvite: Wire(type: "playInvite")
        case .gift(let gift): Wire(type: "gift", gift: gift)
        case .gameInvite: Wire(type: "gameInvite")
        case .gameAccept: Wire(type: "gameAccept")
        case .gameMove(let round, let move): Wire(type: "gameMove", round: round, move: move)
        case .gameQuit: Wire(type: "gameQuit")
        case .goodbye(let reason): Wire(type: "goodbye", reason: reason)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(wire)
    }

    /// Nil for anything unreadable or unknown, so a newer peer's extra messages are ignored.
    public static func decode(_ data: Data) -> MeetupMessage? {
        guard data.count <= 4096, let wire = try? JSONDecoder().decode(Wire.self, from: data) else { return nil }
        switch wire.type {
        case "hello":
            guard let version = wire.version, let pet = wire.pet else { return nil }
            return .hello(version: version, pet: pet)
        case "pose":
            return wire.mood.map(MeetupMessage.pose)
        case "playInvite":
            return .playInvite
        case "gift":
            return wire.gift.map(MeetupMessage.gift)
        case "gameInvite":
            return .gameInvite
        case "gameAccept":
            return .gameAccept
        case "gameMove":
            guard let round = wire.round, let move = wire.move, (1...99).contains(round) else { return nil }
            return .gameMove(round: round, move: move)
        case "gameQuit":
            return .gameQuit
        case "goodbye":
            return .goodbye(wire.reason ?? .cancelled)
        default:
            return nil
        }
    }
}
