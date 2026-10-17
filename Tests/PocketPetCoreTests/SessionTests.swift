import Foundation
import Testing
@testable import PocketPetCore

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
private func hours(_ h: Double) -> Date { t0.addingTimeInterval(h * 3600) }

@Suite("PetSceneMachine")
struct PetSceneMachineTests {
    @Test func launchClosedSleepsAndLaunchOpenWakes() {
        var closed = PetSceneMachine()
        #expect(closed.handle(.closed) == [.putToSleep])
        #expect(closed.scene == .glance)
        var open = PetSceneMachine()
        #expect(open.handle(.open) == [.wakeUp])
        var half = PetSceneMachine()
        #expect(half.handle(.partiallyOpen(angleDegrees: 90)) == [.wakeUp])
        var none = PetSceneMachine()
        #expect(none.handle(.unavailable) == [.wakeUp])
        #expect(none.scene == .standard)
    }

    @Test(arguments: [
        (FoldPosture.open, FoldPosture.closed, [SceneEffect.putToSleep], PetScene.glance),
        (.partiallyOpen(angleDegrees: 80), .closed, [.putToSleep], .glance),
        (.closed, .open, [.wakeUp], .home),
        (.closed, .partiallyOpen(angleDegrees: 110), [.wakeUp], .stage(angleDegrees: 110)),
        (.closed, .closed, [], .glance),
        (.open, .partiallyOpen(angleDegrees: 120), [], .stage(angleDegrees: 120)),
        (.partiallyOpen(angleDegrees: 120), .open, [], .home),
        (.open, .open, [], .home),
        (.closed, .unavailable, [.wakeUp], .standard),
        (.unavailable, .open, [.wakeUp], .home),
        (.unavailable, .partiallyOpen(angleDegrees: 100), [.wakeUp], .stage(angleDegrees: 100)),
        (.unavailable, .closed, [.putToSleep], .glance),
        (.unavailable, .unavailable, [], .standard),
        (.open, .unavailable, [], .standard),
    ])
    func transitions(from: FoldPosture, to: FoldPosture, effects: [SceneEffect], scene: PetScene) {
        var machine = PetSceneMachine()
        _ = machine.handle(from)
        #expect(machine.handle(to) == effects)
        #expect(machine.scene == scene)
    }
}

@Suite("PetSession")
struct PetSessionTests {
    @Test func startsNewPetAndSaves() {
        let store = InMemoryPetStore()
        let session = PetSession(store: store, now: t0, newPetName: "Moss")
        #expect(session.state.name == "Moss")
        #expect(store.saveCount == 1)
        #expect(session.recoveredFromError == nil)
    }

    @Test func catchesUpLoadedPet() throws {
        let store = InMemoryPetStore(.newborn(at: t0))
        let session = PetSession(store: store, now: hours(4))
        #expect(session.state.ageSeconds == 4 * 3600)
        #expect(try store.load()?.lastUpdated == hours(4))
    }

    @Test func closingSleepsAndReopeningWakesRested() {
        let store = InMemoryPetStore(PetState(energy: 0.3, bornAt: t0))
        var session = PetSession(store: store, now: t0)
        session.apply(.open, at: t0)
        #expect(session.scene == .home)
        #expect(!session.state.isAsleep)
        session.apply(.closed, at: t0)
        #expect(session.state.isAsleep)
        #expect(session.state.mood == .asleep)
        session.apply(.open, at: hours(2))
        #expect(!session.state.isAsleep)
        #expect(abs(session.state.energy - 0.6) < 0.0001)
    }

    /// The live hinge service starts at `.unavailable`, so this is the real
    /// launch path on an iPhone Duo: no reading, then the first open reading.
    @Test func launchWithNoHingeReadingThenOpenWakesSavedSleeper() {
        let store = InMemoryPetStore(PetState(energy: 0.3, isAsleep: true, bornAt: t0))
        var session = PetSession(store: store, now: t0)
        session.apply(.unavailable, at: t0)
        #expect(session.scene == .standard)
        #expect(!session.state.isAsleep)
        session.apply(.open, at: t0)
        #expect(session.scene == .home)
        #expect(!session.state.isAsleep)
        #expect(session.perform(.feed, at: t0) != .refused(.asleep))
    }

    /// A standard iPhone never gets a hinge reading. A pet saved asleep must
    /// still wake on launch, like opening the phone.
    @Test func launchWithNoHingeWakesSavedSleeper() throws {
        let store = InMemoryPetStore(PetState(isAsleep: true, bornAt: t0))
        var session = PetSession(store: store, now: t0)
        session.apply(.unavailable, at: t0)
        #expect(session.scene == .standard)
        #expect(!session.state.isAsleep)
        #expect(try store.load()?.isAsleep == false)
    }

    /// The first reading after `.unavailable` can be a close. The pet then sleeps.
    @Test func launchWithNoHingeReadingThenClosedSleeps() {
        var session = PetSession(store: InMemoryPetStore(PetState(isAsleep: true, bornAt: t0)), now: t0)
        session.apply(.unavailable, at: t0)
        session.apply(.closed, at: t0)
        #expect(session.scene == .glance)
        #expect(session.state.isAsleep)
    }

    @Test func homeActionsApplyAndSave() {
        let store = InMemoryPetStore(PetState(hunger: 0.8, happiness: 0.4, energy: 0.6, hygiene: 0.4, bornAt: t0))
        var session = PetSession(store: store, now: t0)
        session.apply(.open, at: t0)
        let before = store.saveCount
        #expect(session.perform(.feed, at: t0) == .applied)
        #expect(session.perform(.clean, at: t0) == .applied)
        #expect(session.perform(.play, at: t0) == .applied)
        #expect(store.saveCount == before + 3)
        #expect(session.state.hygiene == 1)
    }

    @Test func standardLayoutUsesBedtimeButton() {
        var session = PetSession(store: InMemoryPetStore(), now: t0)
        session.apply(.unavailable, at: t0)
        #expect(session.scene == .standard)
        #expect(!session.state.isAsleep)
        #expect(session.perform(.sleep, at: t0) == .applied)
        #expect(session.perform(.wake, at: hours(1)) == .applied)
    }

    /// A store that can't decode its save and has no way to move it aside.
    final class UnpreservableStore: PetStore, @unchecked Sendable {
        let loadError: any Error
        private(set) var saves = 0
        init(loadError: any Error) { self.loadError = loadError }
        func load() throws -> PetState? { throw loadError }
        func save(_ state: PetState) throws { saves += 1 }
    }

    @Test func corruptSaveStartsFreshPet() {
        let store = UnpreservableStore(loadError: PetCodecError.corrupt("bad"))
        var session = PetSession(store: store, now: t0)
        #expect(session.recoveredFromError != nil)
        #expect(session.state.ageSeconds == 0)
        // The store can't keep the bad save, so the session must never write over it.
        session.apply(.open, at: hours(1))
        _ = session.perform(.play, at: hours(1))
        session.tick(to: hours(2))
        #expect(store.saves == 0)
        #expect(!session.isSavingEnabled)
        #expect(session.lastSaveError != nil)
    }

    @Test func unreadableSaveIsNeverOverwritten() {
        struct Locked: Error {}
        let store = UnpreservableStore(loadError: Locked())
        var session = PetSession(store: store, now: t0)
        session.apply(.open, at: t0)
        #expect(store.saves == 0)
        #expect(!session.isSavingEnabled)
    }

    @Test func mockDrivenFullLoop() async {
        let mock = MockFoldStateService(initial: .closed)
        var session = PetSession(store: InMemoryPetStore(), now: t0)
        var seen: [PetScene] = []
        let stream = mock.updates
        mock.send(.open)
        mock.send(.partiallyOpen(angleDegrees: 95))
        mock.send(.closed)
        mock.finish()
        var clock = t0
        for await posture in stream {
            clock = clock.addingTimeInterval(60)
            session.apply(posture, at: clock)
            seen.append(session.scene)
        }
        #expect(seen == [.glance, .home, .stage(angleDegrees: 95), .glance])
        #expect(session.state.isAsleep)
    }
}
