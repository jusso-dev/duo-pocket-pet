import Foundation
import PocketPetCore
import Testing
@testable import Hingeling

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

    @Test func noHingeUsesStandardLayout() {
        let model = AppModel(store: InMemoryPetStore(), fold: StaticFoldStateService(.unavailable), clock: { [t0] in t0 })
        #expect(model.scene == .standard)
    }
}
