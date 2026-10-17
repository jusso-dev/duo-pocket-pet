import Foundation

/// A meetup between two nearby pets. Pure and clock-free: the transport feeds
/// it messages and ticks, and carries out the outputs.
///
/// 1. `start` sends hello. Each side waits for the other's hello, and answers
///    it with its own hello (once) and a dance invite.
/// 2. Once both are greeted the pets are together. They dance for
///    `playDuration` as soon as both invites are in, then stay together for
///    gifts and games until one side leaves.
/// 3. Each side's dance ends on its own timer with `.playedTogether`, which
///    the app turns into a happiness boost (once per pair per day, see
///    `MeetupLedger`).
///
/// A dropped connection or a handshake timeout ends the meetup. A dance that
/// is cut short gives no boost.
public struct MeetupMachine: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case idle
        case greeting(since: Date)
        case together(peer: PetCard, since: Date)
        case ended(MeetupEndReason)
    }

    public enum Dance: Equatable, Sendable {
        case waiting
        case dancing(since: Date)
        case done
    }

    public enum Output: Equatable, Sendable {
        case send(MeetupMessage)
        /// Greeted: add the peer to the pals book.
        case met(peer: PetCard)
        /// The first dance finished: raise happiness if the ledger allows it.
        case playedTogether(peer: PetCard)
        /// A present arrived.
        case receivedGift(Gift, from: PetCard)
        /// A Leaf, Pebble, Twig message for the game, when one is running.
        case game(MeetupMessage)
        case ended(MeetupEndReason)
    }

    public static let handshakeTimeout: TimeInterval = 15
    public static let playDuration: TimeInterval = 8

    public private(set) var phase: Phase = .idle
    public private(set) var dance: Dance = .waiting
    public let version: Int
    private var me: PetCard
    private var peerInvited = false

    public init(me: PetCard, version: Int = MeetupCodec.version) {
        self.me = me
        self.version = version
    }

    public var peer: PetCard? {
        if case .together(let peer, _) = phase { return peer }
        return nil
    }

    public var isTogether: Bool { peer != nil }

    public var isDancing: Bool {
        if case .dancing = dance { return true }
        return false
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
        return isTogether && moodChanged ? [.send(.pose(card.mood))] : []
    }

    /// Sends a present. Only while together.
    public func send(_ gift: Gift) -> [Output] {
        isTogether ? [.send(.gift(gift))] : []
    }

    /// Sends a game message. Only while together.
    public func sendGame(_ message: MeetupMessage) -> [Output] {
        isTogether ? [.send(message)] : []
    }

    public mutating func receive(_ message: MeetupMessage, at now: Date) -> [Output] {
        switch (phase, message) {
        case (.ended, _), (.idle, _):
            return []
        case (_, .goodbye(let reason)):
            return end(reason, sayGoodbye: false)
        case (.greeting, .hello(let version, let pet)):
            guard version == self.version else { return end(.versionMismatch, sayGoodbye: true) }
            phase = .together(peer: pet, since: now)
            // Say hello back, in case ours went out before the other side was
            // listening. A side that already has our hello ignores the repeat.
            var out: [Output] = [.met(peer: pet), .send(.hello(version: version, pet: me)), .send(.playInvite)]
            if peerInvited { out += beginDance(at: now) }
            return out
        case (.greeting, .playInvite):
            // The invite overtook the hello. Remember it.
            peerInvited = true
            return []
        case (.together, .playInvite):
            peerInvited = true
            return dance == .waiting ? beginDance(at: now) : []
        case (.together(let peer, let since), .pose(let mood)):
            phase = .together(peer: PetCard(name: peer.name, stage: peer.stage, mood: mood), since: since)
            return []
        case (.together(let peer, _), .gift(let gift)):
            return [.receivedGift(gift, from: peer)]
        case (.together, .gameInvite), (.together, .gameAccept), (.together, .gameMove), (.together, .gameQuit):
            return [.game(message)]
        default:
            // A repeated hello, or anything before hello: ignore.
            return []
        }
    }

    /// Call regularly (every second or so) to run the handshake timeout and the dance.
    public mutating func tick(at now: Date) -> [Output] {
        switch phase {
        case .greeting(let since):
            if now.timeIntervalSince(since) >= Self.handshakeTimeout { return end(.timedOut, sayGoodbye: true) }
            return []
        case .together(let peer, _):
            guard case .dancing(let since) = dance, now.timeIntervalSince(since) >= Self.playDuration else { return [] }
            dance = .done
            return [.playedTogether(peer: peer)]
        case .idle, .ended:
            return []
        }
    }

    /// The transport lost the peer.
    public mutating func disconnected() -> [Output] {
        end(.disconnected, sayGoodbye: false)
    }

    /// The player said goodbye, left the scene or turned meetups off.
    public mutating func leave() -> [Output] {
        end(isTogether ? .finished : .cancelled, sayGoodbye: true)
    }

    private mutating func beginDance(at now: Date) -> [Output] {
        dance = .dancing(since: now)
        return []
    }

    private mutating func end(_ reason: MeetupEndReason, sayGoodbye: Bool) -> [Output] {
        switch phase {
        case .ended, .idle: return []
        default: break
        }
        phase = .ended(reason)
        if isDancing { dance = .waiting }
        return (sayGoodbye ? [.send(.goodbye(reason))] : []) + [.ended(reason)]
    }
}
