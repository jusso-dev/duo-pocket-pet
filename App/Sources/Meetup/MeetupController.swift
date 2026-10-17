import Foundation
import Observation
import PocketPetCore

/// Nearby play between pets on the local network: opt-in, one visitor at a
/// time. Pets that meet dance together, then can swap gifts and play Leaf,
/// Pebble, Twig until one side leaves. Every pet met goes in the pals book.
///
/// It runs while the stage (half folded), the standard iPhone layout or the
/// Nearby screen is showing, and only once the player has opted in. The local
/// network permission prompt appears the first time it starts looking.
@MainActor
@Observable
final class MeetupController {
    enum Status: Equatable {
        case off
        case looking
        case greeting
        case together(with: PetCard)
        case ended(MeetupEndReason)
    }

    /// A pet advertising nearby.
    struct NearbyPet: Identifiable, Equatable {
        let id: String
        var card: PetCard?
    }

    private enum Key {
        static let enabled = "meetup.enabled"
        static let ledger = "meetup.ledger"
        static let pals = "meetup.pals"
    }

    private(set) var isEnabled: Bool
    private(set) var status: Status = .off
    private(set) var nearby: [NearbyPet] = []
    /// True while the welcome dance is running.
    private(set) var isDancing = false
    /// The latest thing that happened, for the status line: a gift, a boost, a game result.
    private(set) var news: String?
    private(set) var game = PebbleGame()
    private(set) var pals: PalBook

    @ObservationIgnored private let transport: any MeetupTransport
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let tickInterval: Duration
    @ObservationIgnored private var machine: MeetupMachine?
    @ObservationIgnored private var peerKey: String?
    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var autoInvite = false
    @ObservationIgnored private var eventTask: Task<Void, Never>?
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    /// True while meetups are on and a scene allows them. The event task stays
    /// alive regardless: cancelling a task that reads an AsyncStream ends the
    /// stream for good, so it only ignores events while this is false.
    @ObservationIgnored private var isRunning = false
    /// Our pet as it is now. Set by `AppModel`.
    @ObservationIgnored var currentCard: () -> PetCard = { PetCard(name: "Bip", stage: .newborn, mood: .content) }
    /// Raises happiness by the amount. Returns true when it landed.
    @ObservationIgnored var applyBoost: (Meter) -> Bool = { _ in false }
    /// Applies a gift. Returns true when it landed.
    @ObservationIgnored var applyGift: (Gift) -> Bool = { _ in false }

    init(
        transport: any MeetupTransport,
        defaults: UserDefaults = .standard,
        clock: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current,
        tickInterval: Duration = .seconds(1)
    ) {
        self.transport = transport
        self.defaults = defaults
        self.clock = clock
        self.calendar = calendar
        self.tickInterval = tickInterval
        isEnabled = defaults.bool(forKey: Key.enabled)
        pals = defaults.data(forKey: Key.pals).flatMap { try? JSONDecoder().decode(PalBook.self, from: $0) } ?? PalBook()
    }

    var friend: PetCard? {
        if case .together(let friend) = status { return friend }
        return nil
    }

    // MARK: - Player actions

    /// The player's opt-in.
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Key.enabled)
        refresh()
    }

    /// Whether a scene that allows meetups is on screen. `autoInvite` is for
    /// the half-fold stage, where two Duos meet without picking from a list.
    func setActive(_ active: Bool, autoInvite: Bool = false) {
        let changed = active != isActive || autoInvite != self.autoInvite
        isActive = active
        self.autoInvite = autoInvite
        if changed { refresh(restart: active) }
    }

    /// Invites a pet from the nearby list.
    func invite(_ pet: NearbyPet) {
        guard machine == nil else { return }
        transport.invite(peer: pet.id)
    }

    /// Says goodbye to the visiting pet and goes back to looking.
    func leave() {
        guard var machine else { return }
        let out = machine.leave()
        self.machine = machine
        handle(out)
    }

    func send(_ gift: Gift) {
        guard let machine, let friend = machine.peer else { return }
        handle(machine.send(gift))
        news = "You sent \(friend.name) \(gift.phrase)."
    }

    func inviteToGame() {
        sendGame(game.invite())
        gameMaybeFinished()
    }

    func acceptGame() {
        sendGame(game.accept())
        gameMaybeFinished()
    }

    func quitGame() {
        sendGame(game.quit())
        gameMaybeFinished()
    }

    func choose(_ move: GameMove) {
        sendGame(game.choose(move))
        gameMaybeFinished()
    }

    /// Our pet's mood changed. Shared with the visitor while together.
    func petChanged() {
        guard var machine else { return }
        let out = machine.updateMe(currentCard())
        self.machine = machine
        handle(out)
    }

    // MARK: - Running

    private func refresh(restart: Bool = false) {
        if isEnabled && isActive {
            if eventTask == nil {
                let events = transport.events
                eventTask = Task { [weak self] in
                    for await event in events {
                        guard let self else { return }
                        if self.isRunning { self.on(event) }
                    }
                }
            }
            if !isRunning {
                isRunning = true
                let interval = tickInterval
                tickTask = Task { [weak self] in
                    while !Task.isCancelled {
                        try? await Task.sleep(for: interval)
                        guard let self, !Task.isCancelled else { return }
                        self.tick()
                    }
                }
                status = .looking
                transport.start(advertising: currentCard(), autoInvite: autoInvite)
            } else if restart, machine == nil {
                transport.start(advertising: currentCard(), autoInvite: autoInvite)
            }
        } else {
            guard isRunning else { status = .off; return }
            // Off first, so saying goodbye doesn't start looking again.
            isRunning = false
            if var machine {
                handle(machine.leave())
                self.machine = machine
            }
            tickTask?.cancel()
            tickTask = nil
            machine = nil
            peerKey = nil
            nearby = []
            isDancing = false
            game = PebbleGame()
            transport.stop()
            status = .off
        }
    }

    func on(_ event: MeetupTransportEvent) {
        switch event {
        case .found(let peer, let card):
            if let i = nearby.firstIndex(where: { $0.id == peer }) {
                nearby[i].card = card ?? nearby[i].card
            } else {
                nearby.append(NearbyPet(id: peer, card: card))
            }
        case .lost(let peer):
            nearby.removeAll { $0.id == peer }
        case .connected(let peer):
            peerKey = [transport.localKey, peer].sorted().joined(separator: "+")
            var machine = MeetupMachine(me: currentCard())
            let out = machine.start(at: clock())
            self.machine = machine
            status = .greeting
            news = nil
            game = PebbleGame()
            handle(out)
        case .received(let data):
            guard var machine, let message = MeetupCodec.decode(data) else { return }
            let out = machine.receive(message, at: clock())
            self.machine = machine
            handle(out)
        case .disconnected:
            guard var machine else { return }
            let out = machine.disconnected()
            self.machine = machine
            handle(out)
        }
    }

    func tick() {
        guard var machine else { return }
        let out = machine.tick(at: clock())
        self.machine = machine
        handle(out)
    }

    private func sendGame(_ messages: [MeetupMessage]) {
        guard let machine else { return }
        for message in messages { handle(machine.sendGame(message)) }
    }

    private func handle(_ outputs: [MeetupMachine.Output]) {
        for output in outputs {
            switch output {
            case .send(let message):
                if let data = try? MeetupCodec.encode(message) { transport.send(data) }
            case .met(let peer):
                pals.met(peer, key: peerKey ?? peer.name, at: clock())
                savePals()
            case .playedTogether(let peer):
                var ledger = loadLedger()
                let fresh = ledger.claim(pair: pairKey(peer), at: clock(), calendar: calendar)
                // Only save the claim once the boost lands, so an asleep pet
                // doesn't use up today's allowance.
                if fresh && applyBoost(MeetupLedger.boost) {
                    saveLedger(ledger)
                    news = "\(currentCard().name) had a lovely dance with \(peer.name)."
                } else if fresh {
                    news = "\(currentCard().name) is asleep. Let them rest."
                } else {
                    news = "\(currentCard().name) danced with \(peer.name) again. Today's boost is already used."
                }
            case .receivedGift(let gift, let from):
                var ledger = loadLedger()
                let counts = ledger.claimGift(pair: pairKey(from), at: clock(), calendar: calendar)
                if counts && applyGift(gift) {
                    saveLedger(ledger)
                    news = "\(from.name) sent \(gift.phrase)."
                } else if counts {
                    news = "\(from.name) sent \(gift.phrase), but \(currentCard().name) is asleep."
                } else {
                    news = "\(from.name) sent \(gift.phrase). That's plenty for today, thank you."
                }
            case .game(let message):
                game.receive(message)
                gameMaybeFinished()
            case .ended(let reason):
                status = .ended(reason)
                machine = nil
                peerKey = nil
                isDancing = false
                game = PebbleGame()
                if isRunning {
                    // Drop this peer and look again, so the next pet nearby can say hello.
                    transport.stop()
                    nearby = []
                    transport.start(advertising: currentCard(), autoInvite: autoInvite)
                }
            }
        }
        if let machine {
            if let peer = machine.peer { status = .together(with: peer) }
            isDancing = machine.isDancing
        }
    }

    /// Rewards a finished game once, within today's limit for this pal.
    private func gameMaybeFinished() {
        guard case .finished(let won) = game.phase else {
            // A new game, or one under way: the next finish counts.
            rewardedGame = false
            return
        }
        guard !rewardedGame, let machine, let friend = machine.peer else { return }
        rewardedGame = true
        var ledger = loadLedger()
        let counts = ledger.claimGame(pair: pairKey(friend), at: clock(), calendar: calendar)
        if counts && applyBoost(won ? 0.1 : 0.05) { saveLedger(ledger) }
        pals.recordGame(with: pairKey(friend), won: won)
        savePals()
        news = won ? "\(currentCard().name) won Leaf, Pebble, Twig." : "\(friend.name) won Leaf, Pebble, Twig. Good game."
    }

    @ObservationIgnored private var rewardedGame = false

    private func pairKey(_ peer: PetCard) -> String { peerKey ?? peer.name }

    private func loadLedger() -> MeetupLedger {
        guard let data = defaults.data(forKey: Key.ledger) else { return MeetupLedger() }
        return (try? JSONDecoder().decode(MeetupLedger.self, from: data)) ?? MeetupLedger()
    }

    private func saveLedger(_ ledger: MeetupLedger) {
        if let data = try? JSONEncoder().encode(ledger) { defaults.set(data, forKey: Key.ledger) }
    }

    private func savePals() {
        if let data = try? JSONEncoder().encode(pals) { defaults.set(data, forKey: Key.pals) }
    }
}

extension Gift {
    /// "a snack", "a toy", "a bath".
    var phrase: String {
        switch self {
        case .snack: "a snack"
        case .toy: "a toy"
        case .bath: "a bubble bath"
        }
    }

    var icon: PixelIcon {
        switch self {
        case .snack: .bowl
        case .toy: .ball
        case .bath: .bubbles
        }
    }
}

extension GameMove {
    var title: String { rawValue.capitalized }
}

extension MeetupController.Status {
    /// Short, kind status text for the meetup panel.
    func message(petName: String) -> String? {
        switch self {
        case .off: nil
        case .looking: "Looking for pets nearby."
        case .greeting: "\(petName) is saying hello."
        case .together(let friend): "\(petName) is with \(friend.name)."
        case .ended(.versionMismatch): "That pet needs a different version of Hingeling."
        case .ended(.disconnected): "The other pet had to go."
        case .ended(.timedOut): "Couldn't reach the other pet. Still looking."
        case .ended(.finished): "Said goodbye. Still looking."
        case .ended(.cancelled): nil
        }
    }
}
