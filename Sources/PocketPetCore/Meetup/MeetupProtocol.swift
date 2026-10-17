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

/// The meetup message set. Small, versioned and Codable.
public enum MeetupMessage: Equatable, Sendable {
    /// First message each side sends, with its protocol version.
    case hello(version: Int, pet: PetCard)
    /// The pet's mood changed while together.
    case pose(Mood)
    /// Ready to play. Play starts once both sides have sent this.
    case playInvite
    /// Leaving, with the reason.
    case goodbye(MeetupEndReason)
}

public enum MeetupEndReason: String, Codable, Equatable, Sendable {
    /// Played together and said goodbye.
    case finished
    /// The other side speaks a different protocol version.
    case versionMismatch
    /// No hello or no invite in time.
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
    }

    public static func encode(_ message: MeetupMessage) throws -> Data {
        let wire: Wire = switch message {
        case .hello(let version, let pet): Wire(type: "hello", version: version, pet: pet)
        case .pose(let mood): Wire(type: "pose", mood: mood)
        case .playInvite: Wire(type: "playInvite")
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
        case "goodbye":
            return .goodbye(wire.reason ?? .cancelled)
        default:
            return nil
        }
    }
}
