import Foundation

/// The handshake and play session between two nearby pets. Pure and
/// clock-free: the transport feeds it messages and ticks, and carries out
/// the outputs.
///
/// 1. `start` sends hello. Each side waits for the other's hello, and answers
///    it with its own hello (once) and a play invite.
/// 2. Play waits for both invites.
/// 3. With both invites in, the pets play for `playDuration`.
/// 4. Then each side gets a happiness boost (at most once per pair per day,
///    see `MeetupLedger`) and says goodbye.
///
/// A dropped connection or a timeout at any step ends the meetup with no boost.
public struct MeetupMachine: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case idle
        case greeting(since: Date)
        case inviting(peer: PetCard, since: Date)
        case playing(peer: PetCard, since: Date)
        case ended(MeetupEndReason)
    }

    public enum Output: Equatable, Sendable {
        case send(MeetupMessage)
        /// Play finished: raise happiness if the ledger allows it for this pair today.
        case playedTogether(peer: PetCard)
        case ended(MeetupEndReason)
    }

    public static let handshakeTimeout: TimeInterval = 15
    public static let playDuration: TimeInterval = 8

    public private(set) var phase: Phase = .idle
    public let version: Int
    private var me: PetCard
    private var peerInvited = false

    public init(me: PetCard, version: Int = MeetupCodec.version) {
        self.me = me
        self.version = version
    }

    public var peer: PetCard? {
        switch phase {
        case .inviting(let peer, _), .playing(let peer, _): peer
        default: nil
        }
    }

    public var isFinished: Bool {
        if case .ended = phase { return true }
        return false
    }

    public mutating func start(at now: Date) -> [Output] {
        guard phase == .idle else { return [] }
        phase = .greeting(since: now)
        return [.send(.hello(version: version, pet: me))]
    }

    /// Our own pet's mood changed. Shared while together.
    public mutating func updateMe(_ card: PetCard) -> [Output] {
        let moodChanged = card.mood != me.mood
        me = card
        switch phase {
        case .inviting, .playing: return moodChanged ? [.send(.pose(card.mood))] : []
        default: return []
        }
    }

    public mutating func receive(_ message: MeetupMessage, at now: Date) -> [Output] {
        switch (phase, message) {
        case (.ended, _), (.idle, _):
            return []
        case (.playing(let peer, let since), .goodbye(.finished)) where now.timeIntervalSince(since) >= Self.playDuration / 2:
            // The other side's play timer ran out a moment before ours. Count it.
            phase = .ended(.finished)
            return [.playedTogether(peer: peer), .ended(.finished)]
        case (_, .goodbye(let reason)):
            // Any other goodbye, including a "finished" that came too early, ends with no boost.
            return end(reason == .finished ? .cancelled : reason, sayGoodbye: false)
        case (.greeting, .hello(let version, let pet)):
            guard version == self.version else { return end(.versionMismatch, sayGoodbye: true) }
            phase = .inviting(peer: pet, since: now)
            // Say hello back, in case ours went out before the other side was
            // listening. A side that already has our hello ignores the repeat.
            var out: [Output] = [.send(.hello(version: version, pet: me)), .send(.playInvite)]
            if peerInvited { out += beginPlay(peer: pet, at: now) }
            return out
        case (.greeting, .playInvite):
            // The invite overtook the hello. Remember it.
            peerInvited = true
            return []
        case (.inviting(let peer, _), .playInvite):
            peerInvited = true
            return beginPlay(peer: peer, at: now)
        case (.inviting(let peer, let since), .pose(let mood)):
            phase = .inviting(peer: PetCard(name: peer.name, stage: peer.stage, mood: mood), since: since)
            return []
        case (.playing(let peer, let since), .pose(let mood)):
            phase = .playing(peer: PetCard(name: peer.name, stage: peer.stage, mood: mood), since: since)
            return []
        default:
            // A repeated hello or invite, or a pose before hello: ignore.
            return []
        }
    }

    /// Call regularly (every second or so) to run timeouts and finish play.
    public mutating func tick(at now: Date) -> [Output] {
        switch phase {
        case .greeting(let since), .inviting(_, let since):
            if now.timeIntervalSince(since) >= Self.handshakeTimeout { return end(.timedOut, sayGoodbye: true) }
            return []
        case .playing(let peer, let since):
            guard now.timeIntervalSince(since) >= Self.playDuration else { return [] }
            phase = .ended(.finished)
            return [.playedTogether(peer: peer), .send(.goodbye(.finished)), .ended(.finished)]
        case .idle, .ended:
            return []
        }
    }

    /// The transport lost the peer.
    public mutating func disconnected() -> [Output] {
        end(.disconnected, sayGoodbye: false)
    }

    /// The player left the scene or turned meetups off.
    public mutating func cancel() -> [Output] {
        end(.cancelled, sayGoodbye: true)
    }

    private mutating func beginPlay(peer: PetCard, at now: Date) -> [Output] {
        phase = .playing(peer: peer, since: now)
        return []
    }

    private mutating func end(_ reason: MeetupEndReason, sayGoodbye: Bool) -> [Output] {
        switch phase {
        case .ended, .idle: return []
        default: break
        }
        phase = .ended(reason)
        return (sayGoodbye ? [.send(.goodbye(reason))] : []) + [.ended(reason)]
    }
}

/// Remembers which pairs have had today's meetup boost. Saved by the app.
public struct MeetupLedger: Codable, Equatable, Sendable {
    /// Pair key to the day ("2026-10-17", in the player's calendar) of the last boost.
    public private(set) var lastBoost: [String: String] = [:]

    public init() {}

    /// The happiness one meetup adds.
    public static let boost: Meter = 0.15

    /// Records a boost for `pair` and returns true, or returns false if this
    /// pair already had one today.
    public mutating func claim(pair: String, at now: Date, calendar: Calendar) -> Bool {
        let day = Self.dayKey(now, calendar: calendar)
        if lastBoost[pair] == day { return false }
        lastBoost[pair] = day
        // Keep the ledger small: drop days that are no longer today.
        lastBoost = lastBoost.filter { $0.value == day }
        return true
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
