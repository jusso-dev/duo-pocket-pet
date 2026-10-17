import Foundation

/// Leaf, Pebble, Twig between two nearby pets: first to two round wins.
/// Leaf wraps pebble, pebble snaps twig, twig pokes through leaf. A tied round
/// is played again.
///
/// Pure: the app passes messages in and sends the ones that come out. Each
/// side shows the other's move only once both have chosen.
public struct PebbleGame: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case idle
        /// We asked and are waiting for an answer.
        case invited
        /// They asked: accept or decline.
        case askedByPeer
        /// Playing round `round`.
        case playing(round: Int, mine: GameMove?, theirs: GameMove?)
        case finished(won: Bool)
    }

    public struct RoundResult: Equatable, Sendable {
        public let round: Int
        public let mine: GameMove
        public let theirs: GameMove
        /// True, false, or nil for a tie.
        public let iWon: Bool?
    }

    public static let winsNeeded = 2

    public private(set) var phase: Phase = .idle
    public private(set) var myWins = 0
    public private(set) var theirWins = 0
    public private(set) var lastRound: RoundResult?
    /// A move that arrived for a round we haven't reached yet.
    private var early: (round: Int, move: GameMove)?

    public init() {}

    public static func == (lhs: PebbleGame, rhs: PebbleGame) -> Bool {
        lhs.phase == rhs.phase && lhs.myWins == rhs.myWins && lhs.theirWins == rhs.theirWins && lhs.lastRound == rhs.lastRound
            && lhs.early?.round == rhs.early?.round && lhs.early?.move == rhs.early?.move
    }

    public var isRunning: Bool {
        switch phase {
        case .invited, .askedByPeer, .playing: true
        case .idle, .finished: false
        }
    }

    /// Ask the other pet to play.
    public mutating func invite() -> [MeetupMessage] {
        guard !isRunning else { return [] }
        reset()
        phase = .invited
        return [.gameInvite]
    }

    /// Accept their invitation.
    public mutating func accept() -> [MeetupMessage] {
        guard phase == .askedByPeer else { return [] }
        let theirs = early?.round == 1 ? early?.move : nil
        early = nil
        phase = .playing(round: 1, mine: nil, theirs: theirs)
        return [.gameAccept]
    }

    /// Decline, or stop a game part way.
    public mutating func quit() -> [MeetupMessage] {
        guard isRunning else { return [] }
        reset()
        return [.gameQuit]
    }

    /// Choose a move for the current round.
    public mutating func choose(_ move: GameMove) -> [MeetupMessage] {
        guard case .playing(let round, nil, let theirs) = phase else { return [] }
        phase = .playing(round: round, mine: move, theirs: theirs)
        resolveIfReady()
        return [.gameMove(round: round, move: move)]
    }

    /// Handles a game message from the other side.
    public mutating func receive(_ message: MeetupMessage) {
        switch (phase, message) {
        case (.idle, .gameInvite), (.finished, .gameInvite):
            reset()
            phase = .askedByPeer
        case (.invited, .gameInvite):
            // Both asked at once: just start.
            phase = .playing(round: 1, mine: nil, theirs: nil)
        case (.invited, .gameAccept):
            phase = .playing(round: 1, mine: nil, theirs: nil)
        case (.playing(let round, let mine, nil), .gameMove(let theirRound, let move)):
            if theirRound == round {
                phase = .playing(round: round, mine: mine, theirs: move)
                resolveIfReady()
            } else if theirRound == round + 1 {
                early = (theirRound, move)
            }
        case (.askedByPeer, .gameMove(let theirRound, let move)) where theirRound == 1:
            // They started before our accept reached them.
            early = (1, move)
        case (_, .gameQuit):
            if isRunning { reset() }
        default:
            break
        }
    }

    private mutating func resolveIfReady() {
        guard case .playing(let round, let mine?, let theirs?) = phase else { return }
        let iWon: Bool? = mine == theirs ? nil : mine.beats(theirs)
        lastRound = RoundResult(round: round, mine: mine, theirs: theirs, iWon: iWon)
        if iWon == true { myWins += 1 }
        if iWon == false { theirWins += 1 }
        if myWins >= Self.winsNeeded || theirWins >= Self.winsNeeded {
            phase = .finished(won: myWins > theirWins)
            early = nil
            return
        }
        let next = round + 1
        var theirsNext: GameMove?
        if let early, early.round == next { theirsNext = early.move }
        early = nil
        phase = .playing(round: next, mine: nil, theirs: theirsNext)
    }

    private mutating func reset() {
        phase = .idle
        myWins = 0
        theirWins = 0
        lastRound = nil
        early = nil
    }
}
