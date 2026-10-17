import Foundation
import PocketPetCore
import Testing
@testable import Hingeling

/// An in-memory link between two transports. `send` on one arrives on the other.
private final class FakeTransport: MeetupTransport, @unchecked Sendable {
    let localKey: String
    let events: AsyncStream<MeetupTransportEvent>
    private let continuation: AsyncStream<MeetupTransportEvent>.Continuation
    private let lock = NSLock()
    private var _started = 0
    weak var other: FakeTransport?

    init(key: String) {
        localKey = key
        let (stream, continuation) = AsyncStream.makeStream(of: MeetupTransportEvent.self)
        events = stream
        self.continuation = continuation
    }

    var started: Int { lock.withLock { _started } }
    func start() { lock.withLock { _started += 1 } }
    func stop() {}
    func send(_ data: Data) { other?.continuation.yield(.received(data)) }
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

    private func model(_ transport: FakeTransport, name: String, clock: Clock, defaults: UserDefaults, fold: FoldPosture = .partiallyOpen(angleDegrees: 100)) -> AppModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let meetup = MeetupController(transport: transport, defaults: defaults, clock: { clock.now }, calendar: calendar, tickInterval: .milliseconds(10))
        return AppModel(store: InMemoryPetStore(PetState(name: name, happiness: 0.5, bornAt: t0)), fold: MockFoldStateService(initial: fold), meetup: meetup, clock: { clock.now })
    }

    @Test func offUntilThePlayerOptsIn() {
        let transport = FakeTransport(key: "a")
        let model = model(transport, name: "Bip", clock: Clock(t0), defaults: defaults())
        #expect(model.meetup?.status == .off)
        #expect(transport.started == 0)
        model.meetup?.setEnabled(true)
        #expect(transport.started == 1)
        #expect(model.meetup?.status == .looking)
    }

    @Test func onlyLooksOnTheStageOrStandardLayout() {
        let transport = FakeTransport(key: "a")
        let model = model(transport, name: "Bip", clock: Clock(t0), defaults: defaults(), fold: .open)
        model.meetup?.setEnabled(true)
        #expect(model.meetup?.status == .off)
        model.apply(.partiallyOpen(angleDegrees: 90))
        #expect(model.meetup?.status == .looking)
        model.apply(.open)
        #expect(model.meetup?.status == .off)
    }

    @Test func twoPetsPlayAndBothGetOneBoostADay() async {
        let clock = Clock(t0)
        let ta = FakeTransport(key: "a"), tb = FakeTransport(key: "b")
        FakeTransport.link(ta, tb)
        let a = model(ta, name: "Bip", clock: clock, defaults: defaults())
        // The second phone is a standard iPhone: no hinge, standard layout.
        let b = model(tb, name: "Moss", clock: clock, defaults: defaults(), fold: .unavailable)
        a.meetup?.setEnabled(true)
        b.meetup?.setEnabled(true)
        ta.inject(.connected(peer: "b"))
        tb.inject(.connected(peer: "a"))
        #expect(await eventually { a.meetup?.status.friend?.name == "Moss" && b.meetup?.status.friend?.name == "Bip" })

        let before = (a.state.happiness, b.state.happiness)
        clock.now = t0.addingTimeInterval(MeetupMachine.playDuration + 1)
        #expect(await eventually {
            if case .finished(_, true) = a.meetup?.status, case .finished(_, true) = b.meetup?.status { return true }
            return false
        })
        #expect(a.state.happiness > before.0)
        #expect(b.state.happiness > before.1)
    }

    @Test func droppedConnectionEndsWithoutABoost() async {
        let clock = Clock(t0)
        let ta = FakeTransport(key: "a"), tb = FakeTransport(key: "b")
        FakeTransport.link(ta, tb)
        let a = model(ta, name: "Bip", clock: clock, defaults: defaults())
        let b = model(tb, name: "Moss", clock: clock, defaults: defaults())
        a.meetup?.setEnabled(true)
        b.meetup?.setEnabled(true)
        ta.inject(.connected(peer: "b"))
        tb.inject(.connected(peer: "a"))
        #expect(await eventually { a.meetup?.status.friend != nil })
        let happiness = a.state.happiness
        ta.inject(.disconnected)
        #expect(await eventually { a.meetup?.status == .ended(.disconnected) })
        #expect(a.state.happiness == happiness)
    }
}
