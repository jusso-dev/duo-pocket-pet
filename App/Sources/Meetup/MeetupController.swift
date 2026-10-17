import Foundation
import Observation
import PocketPetCore

/// Runs meetups with nearby pets: opt-in, one peer at a time, and a happiness
/// boost at most once per pair per day.
///
/// The app turns it on while the stage scene (half folded) or the standard
/// iPhone layout is showing, and only if the player has opted in. The local
/// network permission prompt appears the first time it starts looking.
@MainActor
@Observable
final class MeetupController {
    enum Status: Equatable {
        case off
        case looking
        case greeting
        case playing(with: PetCard)
        case finished(with: PetCard, boosted: Bool)
        case ended(MeetupEndReason)
    }

    private enum Key {
        static let enabled = "meetup.enabled"
        static let ledger = "meetup.ledger"
    }

    private(set) var isEnabled: Bool
    private(set) var status: Status = .off

    @ObservationIgnored private let transport: any MeetupTransport
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let tickInterval: Duration
    @ObservationIgnored private var machine: MeetupMachine?
    @ObservationIgnored private var peerKey: String?
    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var eventTask: Task<Void, Never>?
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    /// Our pet as it is now. Set by `AppModel`.
    @ObservationIgnored var currentCard: () -> PetCard = { PetCard(name: "Bip", stage: .newborn, mood: .content) }
    /// Applies the boost. Returns true when it landed.
    @ObservationIgnored var applyBoost: () -> Bool = { false }

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
    }

    /// The player's opt-in.
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Key.enabled)
        refresh()
    }

    /// Whether a scene that allows meetups is on screen.
    func setActive(_ active: Bool) {
        isActive = active
        refresh()
    }

    /// Our pet's mood changed. Shared with the peer while together.
    func petChanged() {
        guard var machine else { return }
        let out = machine.updateMe(currentCard())
        self.machine = machine
        handle(out)
    }

    private func refresh() {
        if isEnabled && isActive {
            guard eventTask == nil else { return }
            status = .looking
            transport.start()
            let events = transport.events
            eventTask = Task { [weak self] in
                for await event in events {
                    guard let self, !Task.isCancelled else { return }
                    self.on(event)
                }
            }
            let interval = tickInterval
            tickTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: interval)
                    guard let self, !Task.isCancelled else { return }
                    self.tick()
                }
            }
        } else {
            guard eventTask != nil else { status = .off; return }
            if var machine {
                handle(machine.cancel())
                self.machine = machine
            }
            eventTask?.cancel()
            tickTask?.cancel()
            eventTask = nil
            tickTask = nil
            machine = nil
            peerKey = nil
            transport.stop()
            status = .off
        }
    }

    func on(_ event: MeetupTransportEvent) {
        switch event {
        case .connected(let peer):
            peerKey = [transport.localKey, peer].sorted().joined(separator: "+")
            var machine = MeetupMachine(me: currentCard())
            let out = machine.start(at: clock())
            self.machine = machine
            status = .greeting
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

    private func handle(_ outputs: [MeetupMachine.Output]) {
        for output in outputs {
            switch output {
            case .send(let message):
                if let data = try? MeetupCodec.encode(message) { transport.send(data) }
            case .playedTogether(let peer):
                var ledger = loadLedger()
                let fresh = ledger.claim(pair: peerKey ?? peer.name, at: clock(), calendar: calendar)
                saveLedger(ledger)
                let boosted = fresh && applyBoost()
                status = .finished(with: peer, boosted: boosted)
            case .ended(let reason):
                if case .finished = status {} else { status = .ended(reason) }
                machine = nil
                peerKey = nil
                if isEnabled && isActive && eventTask != nil {
                    // Drop this peer and look again, so the next pet nearby can say hello.
                    transport.stop()
                    transport.start()
                }
            }
        }
        if let machine, case .playing(let peer, _) = machine.phase {
            status = .playing(with: peer)
        }
    }

    private func loadLedger() -> MeetupLedger {
        guard let data = defaults.data(forKey: Key.ledger) else { return MeetupLedger() }
        return (try? JSONDecoder().decode(MeetupLedger.self, from: data)) ?? MeetupLedger()
    }

    private func saveLedger(_ ledger: MeetupLedger) {
        if let data = try? JSONEncoder().encode(ledger) { defaults.set(data, forKey: Key.ledger) }
    }
}

extension MeetupController.Status {
    /// Short, kind status text for the meetup panel.
    func message(petName: String) -> String? {
        switch self {
        case .off: nil
        case .looking: "Looking for pets nearby."
        case .greeting: "\(petName) is saying hello."
        case .playing(let friend): "\(petName) is playing with \(friend.name)."
        case .finished(let friend, true): "\(petName) had a lovely time with \(friend.name)."
        case .finished(let friend, false): "\(petName) played with \(friend.name) again. Today's boost is already used."
        case .ended(.versionMismatch): "That pet needs a different version of Hingeling."
        case .ended(.disconnected): "The other pet had to go."
        case .ended(.timedOut): "Couldn't reach the other pet. Still looking."
        case .ended(.cancelled), .ended(.finished): nil
        }
    }
}
