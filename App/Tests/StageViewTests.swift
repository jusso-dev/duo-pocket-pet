import Foundation
import PocketPetCore
import SwiftUI
import Testing
import UIKit
@testable import Hingeling

@MainActor
@Suite("Stage")
struct StageViewTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func halfFoldShowsTheStageAndCheeringIsRateLimited() {
        let model = AppModel(store: InMemoryPetStore(PetState(happiness: 0.5, bornAt: t0)), fold: MockFoldStateService(initial: .partiallyOpen(angleDegrees: 100)), clock: { [t0] in t0 })
        #expect(model.scene == .stage(angleDegrees: 100))
        #expect(model.cheer() == .applied)
        #expect(model.state.happiness > 0.5)
        let again = model.cheer()
        #expect(again == .coolingDown(remaining: 30))
        #expect(again.message(petName: "Bip").contains("30 seconds"))
    }

    @Test func stageRendersOnACompactScreen() throws {
        let model = AppModel(store: InMemoryPetStore(.sample(mood: .sleepy, stage: .young)), fold: MockFoldStateService(initial: .partiallyOpen(angleDegrees: 90)))
        let screen = CGSize(width: 375, height: 647)
        let renderer = ImageRenderer(content: StageView(model: model, angleDegrees: 90).frame(width: screen.width, height: screen.height))
        renderer.scale = 1
        #expect(try #require(renderer.uiImage).size == screen)
    }
}
