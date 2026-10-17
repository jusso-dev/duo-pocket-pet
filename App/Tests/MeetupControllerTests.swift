import Foundation
import PocketPetCore
import SwiftUI
import Testing
@testable import Hingeling

/// An in-memory link between two transports. `send` on one arrives on the other,
/// and `invite` connects both ends, as an accepted invitation would.
private final class FakeTransport: MeetupTransport, @unchecked Sendable {
    let localKey: String
    let events: AsyncStream<MeetupTransportEvent>
    private let continuation: AsyncStream<MeetupTransportEvent>.Continuation
    private let lock = NSLock()
    private var _started = 0
    private var _advertised: PetCard?
    private var _autoInvite = false
    weak var other: FakeTransport?

    init(key: String) {
        localKey = key
        let (stream, continuation) = AsyncStream.makeStream(of: MeetupTransportEvent.self)
        events = stream
        self.continuation = continuation
    }

    var started: Int { lock.withLock { _started } }
    var advertised: PetCard? { lock.withLock { _advertised } }
    var autoInvite: Bool { lock.withLock { _autoInvite } }

    func start(advertising card: PetCard, autoInvite: Bool) {
        lock.withLock {
            _started += 1
            _advertised = card
            _autoInvite = autoInvite
        }
    }

    func stop() {}
    func send(_ data: Data) { other?.continuation.yield(.received(data)) }

    func invite(peer: String) {
        guard let other, other.localKey == peer else { return }
        inject(.connected(peer: other.localKey))
        other.inject(.connected(peer: localKey))
    }

    func inject(_ event: MeetupTransportEvent) { continuation.yield(event) }

    static func link(_ a: FakeTransport, _ b: FakeTransport) {
        a.other = b
        b.other = a
    }
}

private final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date
    init(_ now: Date) { _now = now }
    var now: Date {
        get { lock.withLock { _now } }
        set { lock.withLock { _now = newValue } }
    }
}

@MainActor
@Suite("Meetup controller")
struct MeetupControllerTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func defaults() -> UserDefaults {
        let name = "MeetupControllerTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    private func eventually(_ timeout: Duration = .seconds(5), _ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return condition()
    }

    private func model(
        _ transport: FakeTransport, name: String, clock: Clock, defaults: UserDefaults,
        fold: FoldPosture = .partiallyOpen(angleDegrees: 100), pet: PetState? = nil
    ) -> AppModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let meetup = MeetupController(transport: transport, defaults: defaults, clock: { clock.now }, calendar: calendar, tickInterval: .milliseconds(10))
        let state = pet ?? PetState(name: name, hunger: 0.5, happiness: 0.5, hygiene: 0.5, bornAt: t0)
        return AppModel(store: InMemoryPetStore(state), fold: MockFoldStateService(initial: fold), meetup: meetup, clock: { clock.now })
    }

    /// Two phones with meetups on, connected through the fake link.
    private func pair(clock: Clock) async -> (AppModel, AppModel, FakeTransport, FakeTransport) {
        let ta = FakeTransport(key: "a"), tb = FakeTransport(key: "b")
        FakeTransport.link(ta, tb)
        let a = model(ta, name: "Bip", clock: clock, defaults: defaults())
        // The second phone is a standard iPhone: no hinge, standard layout.
        let b = model(tb, name: "Moss", clock: clock, defaults: defaults(), fold: .unavailable)
        a.meetup?.setEnabled(true)
        b.meetup?.setEnabled(true)
        ta.invite(peer: "b")
        _ = await eventually { a.meetup?.friend?.name == "Moss" && b.meetup?.friend?.name == "Bip" }
        return (a, b, ta, tb)
    }

    @Test func offUntilThePlayerOptsIn() {
        let transport = FakeTransport(key: "a")
        let model = model(transport, name: "Bip", clock: Clock(t0), defaults: defaults())
        #expect(model.meetup?.status == .off)
        #expect(transport.started == 0)
        model.meetup?.setEnabled(true)
        #expect(transport.started == 1)
        #expect(transport.advertised?.name == "Bip")
        #expect(model.meetup?.status == .looking)
    }

    @Test func stageAutoInvitesAndTheNearbyScreenDoesNot() {
        let transport = FakeTransport(key: "a")
        let model = model(transport, name: "Bip", clock: Clock(t0), defaults: defaults(), fold: .open)
        model.meetup?.setEnabled(true)
        #expect(model.meetup?.status == .off)
        model.setNearbyOpen(true)
        #expect(model.meetup?.status == .looking)
        #expect(!transport.autoInvite)
        model.setNearbyOpen(false)
        #expect(model.meetup?.status == .off)
        model.apply(.partiallyOpen(angleDegrees: 90))
        #expect(model.meetup?.status == .looking)
        #expect(transport.autoInvite)
    }

    @Test func nearbyPetsAreListed() async {
        let transport = FakeTransport(key: "a")
        let model = model(transport, name: "Bip", clock: Clock(t0), defaults: defaults())
        model.meetup?.setEnabled(true)
        transport.inject(.found(peer: "b", card: PetCard(name: "Moss", stage: .elder, mood: .joyful)))
        transport.inject(.found(peer: "c", card: nil))
        #expect(await eventually { model.meetup?.nearby.count == 2 })
        #expect(model.meetup?.nearby.first?.card?.name == "Moss")
        transport.inject(.lost(peer: "b"))
        #expect(await eventually { model.meetup?.nearby.map(\.id) == ["c"] })
    }

    @Test func aDuoAndAStandardIPhoneDanceAndBothGetOneBoostADay() async {
        let clock = Clock(t0)
        let (a, b, _, _) = await pair(clock: clock)
        #expect(a.meetup?.friend?.name == "Moss")
        #expect(a.meetup?.pals.pals.first?.card.name == "Moss")
        let before = (a.state.happiness, b.state.happiness)
        clock.now = t0.addingTimeInterval(MeetupMachine.playDuration + 1)
        #expect(await eventually { (a.meetup?.news ?? "").contains("lovely dance") && (b.meetup?.news ?? "").contains("lovely dance") })
        #expect(a.state.happiness > before.0)
        #expect(b.state.happiness > before.1)
        // Still together after the dance.
        #expect(a.meetup?.friend != nil)
    }

    @Test func giftsLandAndAreLimitedPerDay() async {
        let clock = Clock(t0)
        let (a, b, _, _) = await pair(clock: clock)
        let hunger = b.state.hunger
        a.meetup?.send(.snack)
        #expect(await eventually { b.state.hunger < hunger })
        #expect(b.meetup?.news == "Bip sent a snack.")
        for _ in 1..<MeetupLedger.giftsPerPairPerDay { a.meetup?.send(.snack) }
        // Three snacks of 0.15 each.
        #expect(await eventually { abs(b.state.hunger - (hunger - 0.45)) < 0.001 })
        let afterLimit = b.state.hunger
        a.meetup?.send(.snack)
        #expect(await eventually { (b.meetup?.news ?? "").contains("plenty for today") })
        #expect(b.state.hunger == afterLimit)
    }

    @Test func leafPebbleTwigPlaysToTheEndAndIsRecorded() async {
        let clock = Clock(t0)
        let (a, b, _, _) = await pair(clock: clock)
        a.meetup?.inviteToGame()
        #expect(await eventually { b.meetup?.game.phase == .askedByPeer })
        b.meetup?.acceptGame()
        #expect(await eventually { a.meetup?.game.phase == .playing(round: 1, mine: nil, theirs: nil) })
        let happy = (a.state.happiness, b.state.happiness)
        for round in 1...2 {
            a.meetup?.choose(.leaf)
            b.meetup?.choose(.pebble)
            #expect(await eventually { a.meetup?.game.myWins == round && b.meetup?.game.theirWins == round })
        }
        #expect(a.meetup?.game.phase == .finished(won: true))
        #expect(b.meetup?.game.phase == .finished(won: false))
        #expect(a.state.happiness > happy.0)
        #expect(b.state.happiness > happy.1)
        #expect(a.meetup?.pals.pals.first?.gamesWon == 1)
        #expect(b.meetup?.pals.pals.first?.gamesLost == 1)
    }

    @Test func goodbyeEndsBothSidesAndKeepsLooking() async {
        let clock = Clock(t0)
        let (a, b, ta, _) = await pair(clock: clock)
        let starts = ta.started
        a.meetup?.leave()
        #expect(await eventually { a.meetup?.friend == nil && b.meetup?.friend == nil })
        #expect(b.meetup?.status == .ended(.finished))
        #expect(ta.started > starts)
    }

    @Test func droppedConnectionEndsWithoutADanceBoost() async {
        let clock = Clock(t0)
        let (a, _, ta, _) = await pair(clock: clock)
        let happiness = a.state.happiness
        ta.inject(.disconnected)
        #expect(await eventually { a.meetup?.status == .ended(.disconnected) })
        #expect(a.state.happiness == happiness)
    }

    @Test func palsSurviveARelaunch() async {
        let clock = Clock(t0)
        let store = defaults()
        let ta = FakeTransport(key: "a"), tb = FakeTransport(key: "b")
        FakeTransport.link(ta, tb)
        let a = model(ta, name: "Bip", clock: clock, defaults: store)
        let b = model(tb, name: "Moss", clock: clock, defaults: defaults())
        a.meetup?.setEnabled(true)
        b.meetup?.setEnabled(true)
        ta.invite(peer: "b")
        #expect(await eventually { a.meetup?.pals.pals.count == 1 })
        let again = MeetupController(transport: FakeTransport(key: "a"), defaults: store)
        #expect(again.pals.pals.first?.card.name == "Moss")
        #expect(again.isEnabled)
    }
}

@MainActor
@Suite("Share card")
struct ShareCardButtonTests {
    @Test func cardImageRenders() throws {
        let state = PetState.sample(mood: .joyful, stage: .grown)
        let image = try #require(ShareCardButton.image(for: state))
        let renderer = ImageRenderer(content: image)
        renderer.scale = 1
        let ui = try #require(renderer.uiImage)
        #expect(ui.size == CGSize(width: ShareCard.width * 4, height: ShareCard.height * 4))
    }

    @Test func buttonOnlyRedrawsWhenTheCardChanges() {
        var state = PetState.sample(mood: .content, stage: .young)
        let first = ShareCardButton(state: state)
        state.hunger += 0.01
        #expect(ShareCardButton(state: state) == first)
        state.name = "Moss"
        #expect(ShareCardButton(state: state) != first)
    }
}
