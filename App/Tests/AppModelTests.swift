import Foundation
import PocketPetCore
import Testing
@testable import Hingeling

/// A clock a test can move forward. Read from the model's `@Sendable` clock closure.
private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date
    init(_ now: Date) { _now = now }
    var now: Date {
        get { lock.withLock { _now } }
        set { lock.withLock { _now = newValue } }
    }
}

private final class TestFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var isSet: Bool { lock.withLock { value } }
    func set() { lock.withLock { value = true } }
}

@MainActor
@Suite("AppModel")
struct AppModelTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func closedLaunchShowsGlanceAsleep() {
        let model = AppModel(store: InMemoryPetStore(), fold: MockFoldStateService(initial: .closed), clock: { [t0] in t0 })
        #expect(model.scene == .glance)
        #expect(model.state.isAsleep)
    }

    @Test func openingEntersHomeAndButtonsWork() {
        let model = AppModel(store: InMemoryPetStore(PetState(hunger: 0.8, bornAt: t0)), fold: MockFoldStateService(initial: .closed), clock: { [t0] in t0 })
        model.apply(.open)
        #expect(model.scene == .home)
        #expect(!model.state.isAsleep)
        #expect(model.perform(.feed) == .applied)
        #expect(model.lastRefusal == nil)
    }

    @Test func refusalIsShown() {
        let model = AppModel(store: InMemoryPetStore(PetState(hunger: 0.0, bornAt: t0)), fold: MockFoldStateService(initial: .open), clock: { [t0] in t0 })
        #expect(model.perform(.feed) == .refused(.notHungry))
        #expect(model.lastRefusal == .notHungry)
    }

    /// The live app builds `HingeFoldStateService`, which starts at `.unavailable`
    /// until the first hinge callback. Start the mock there, with a pet saved asleep.
    @Test func unavailableLaunchThenOpenWakesSavedSleeper() {
        let mock = MockFoldStateService(initial: .unavailable)
        let model = AppModel(store: InMemoryPetStore(PetState(isAsleep: true, bornAt: t0)), fold: mock, clock: { [t0] in t0 })
        #expect(model.scene == .standard)
        #expect(!model.state.isAsleep)
        model.apply(.open)
        #expect(model.scene == .home)
        #expect(!model.state.isAsleep)
        #expect(model.perform(.play) != .refused(.asleep))
    }

    @Test func backgroundSavesPendingHalfFoldChanges() throws {
        let store = InMemoryPetStore(PetState(bornAt: t0))
        let model = AppModel(store: store, fold: MockFoldStateService(initial: .partiallyOpen(angleDegrees: 90)), clock: { [t0] in t0 })
        model.apply(.partiallyOpen(angleDegrees: 110))
        model.apply(.partiallyOpen(angleDegrees: 130))
        let before = store.saveCount
        #expect(model.session.hasUnsavedChanges)
        model.enteredBackground()
        #expect(store.saveCount == before + 1)
        #expect(!model.session.hasUnsavedChanges)
    }

    @Test func becomingActiveCatchesUpStraightAway() throws {
        let clock = TestClock(t0)
        let store = InMemoryPetStore(PetState(hunger: 0.2, bornAt: t0))
        let model = AppModel(store: store, fold: MockFoldStateService(initial: .open), clock: { clock.now })
        let hungerBefore = model.state.hunger
        clock.now = t0.addingTimeInterval(2 * 3600)
        model.becameActive()
        #expect(model.state.lastUpdated == clock.now)
        #expect(model.state.ageSeconds == 2 * 3600)
        #expect(model.state.hunger > hungerBefore)
        #expect(try store.load()?.lastUpdated == clock.now)
    }

    @Test func fileStoreFailureFallsBackVisibly() {
        struct NoDisk: Error {}
        let store = AppModel.makeStore { throw NoDisk() }
        #expect((store as? InMemoryPetStore)?.fallbackReason != nil)
        let model = AppModel(store: store, fold: MockFoldStateService(initial: .open), clock: { [t0] in t0 })
        #expect(model.storageNotice?.contains("can't be saved") == true)
        model.dismissStorageNotice()
        #expect(model.storageNotice == nil)
    }

    @Test func corruptSaveIsShownWithTheKeptCopy() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("hingeling-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("pet.json")
        try Data("not json".utf8).write(to: url)
        let model = AppModel(store: FilePetStore(url: url), fold: MockFoldStateService(initial: .open), clock: { [t0] in t0 })
        let notice = try #require(model.storageNotice)
        #expect(notice.contains("pet.corrupt-20270115T080000Z.json"))
        model.dismissStorageNotice()
        #expect(model.storageNotice == nil)
    }

    @Test func failedWritesAreShown() {
        final class FailingStore: PetStore, @unchecked Sendable {
            struct Full: Error {}
            func load() throws -> PetState? { nil }
            func save(_ state: PetState) throws { throw Full() }
            func preserveUnreadableSave(at date: Date) throws -> URL? { nil }
        }
        let model = AppModel(store: FailingStore(), fold: MockFoldStateService(initial: .open), clock: { [t0] in t0 })
        #expect(model.session.lastSaveError != nil)
        model.dismissStorageNotice()
        #expect(model.storageNotice?.contains("Couldn't save") == true)
    }

    @Test func healthyStoreShowsNoNotice() {
        let model = AppModel(store: InMemoryPetStore(), fold: MockFoldStateService(initial: .open), clock: { [t0] in t0 })
        #expect(model.storageNotice == nil)
    }

    @Test func noHingeUsesStandardLayout() {
        let model = AppModel(store: InMemoryPetStore(), fold: StaticFoldStateService(.unavailable), clock: { [t0] in t0 })
        #expect(model.scene == .standard)
    }
}

/// Covers `AppModel.run()`: postures arrive through the stream, the tick fires,
/// cancelling stops both, and only one run is active at a time.
@MainActor
@Suite("AppModel.run")
struct AppModelRunTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    /// Polls until `condition` holds, yielding the main actor between checks.
    private func eventually(_ timeout: Duration = .seconds(5), _ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return condition()
    }

    @Test func deliversPosturesFromTheStream() async {
        let mock = MockFoldStateService(initial: .closed)
        let model = AppModel(store: InMemoryPetStore(), fold: mock, clock: { [t0] in t0 })
        let task = Task { await model.run() }
        #expect(await eventually { mock.subscriberCount == 1 })
        mock.send(.open)
        #expect(await eventually { model.scene == .home })
        #expect(!model.state.isAsleep)
        mock.send(.closed)
        #expect(await eventually { model.scene == .glance })
        #expect(model.state.isAsleep)
        task.cancel()
        await task.value
    }

    @Test func ticksOnTheInterval() async {
        let clock = TestClock(t0)
        let store = InMemoryPetStore(PetState(bornAt: t0))
        let model = AppModel(store: store, fold: MockFoldStateService(initial: .open), clock: { clock.now }, tickInterval: .milliseconds(10))
        let task = Task { await model.run() }
        clock.now = t0.addingTimeInterval(3600)
        #expect(await eventually { model.state.lastUpdated == clock.now })
        #expect(model.state.ageSeconds == 3600)
        task.cancel()
        await task.value
    }

    @Test func keepsTickingAfterAFiniteStreamEnds() async {
        let clock = TestClock(t0)
        let model = AppModel(store: InMemoryPetStore(PetState(bornAt: t0)), fold: StaticFoldStateService(.unavailable), clock: { clock.now }, tickInterval: .milliseconds(10))
        let task = Task { await model.run() }
        clock.now = t0.addingTimeInterval(600)
        #expect(await eventually { model.state.lastUpdated == clock.now })
        task.cancel()
        await task.value
    }

    @Test func cancellingStopsTheTickerAndUnsubscribes() async {
        let clock = TestClock(t0)
        let mock = MockFoldStateService(initial: .open)
        let model = AppModel(store: InMemoryPetStore(PetState(bornAt: t0)), fold: mock, clock: { clock.now }, tickInterval: .milliseconds(10))
        let task = Task { await model.run() }
        #expect(await eventually { mock.subscriberCount == 1 })
        task.cancel()
        // run() must return, not hang on the ticker.
        await task.value
        #expect(!model.isRunning)
        #expect(await eventually { mock.subscriberCount == 0 })
        let stopped = model.state.lastUpdated
        clock.now = t0.addingTimeInterval(3600)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(model.state.lastUpdated == stopped)
    }

    /// Every scene's RootView calls run(). Only one may subscribe and tick.
    @Test func secondRunReturnsWhileTheFirstIsActive() async {
        let mock = MockFoldStateService(initial: .open)
        let store = InMemoryPetStore(PetState(bornAt: t0))
        let model = AppModel(store: store, fold: mock, clock: { [t0] in t0 })
        let first = Task { await model.run() }
        #expect(await eventually { mock.subscriberCount == 1 })
        let secondReturned = TestFlag()
        let second = Task {
            await model.run()
            secondReturned.set()
        }
        #expect(await eventually { secondReturned.isSet })
        #expect(mock.subscriberCount == 1)
        second.cancel()
        await second.value
        #expect(model.isRunning)
        first.cancel()
        await first.value
        #expect(!model.isRunning)
        // A later scene can take over once the first one has gone.
        let third = Task { await model.run() }
        #expect(await eventually { mock.subscriberCount == 1 })
        third.cancel()
        await third.value
    }
}
