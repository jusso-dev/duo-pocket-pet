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

    @Test func noHingeUsesStandardLayout() {
        let model = AppModel(store: InMemoryPetStore(), fold: StaticFoldStateService(.unavailable), clock: { [t0] in t0 })
        #expect(model.scene == .standard)
    }
}
