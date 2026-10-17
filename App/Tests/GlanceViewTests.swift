import Foundation
import PocketPetCore
import SwiftUI
import Testing
import UIKit
@testable import Hingeling

@MainActor
@Suite("Glance view")
struct GlanceViewTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func closedPostureShowsGlanceForAsleepPet() {
        let model = AppModel(store: InMemoryPetStore(), fold: MockFoldStateService(initial: .closed), clock: { [t0] in t0 })
        #expect(model.scene == .glance)
        #expect(GlanceContent(state: model.state).accessibilityLabel == "Bip is asleep")
    }

    @Test func rendersEveryMoodOnACompactScreen() throws {
        // 5.4 inch compact iPhone, portrait and landscape, minus a typical safe area.
        let sizes = [CGSize(width: 375, height: 812 - 44 - 34), CGSize(width: 812 - 88, height: 375 - 21)]
        for size in sizes {
            for mood in Mood.allCases {
                let renderer = ImageRenderer(content: GlanceView(state: .sample(mood: mood, stage: .grown)).frame(width: size.width, height: size.height))
                renderer.scale = 1
                let image = try #require(renderer.uiImage, "no image for \(mood) at \(size)")
                #expect(image.size == size)
            }
        }
    }

    @Test func longNameFitsAtLargestTextSizeWithoutClipping() {
        // 5.4 inch portrait safe area. The glance can't scroll, so its natural
        // height at this width must fit, or the text would clip.
        let safeArea = CGSize(width: 375, height: 812 - 44 - 34)
        let view = GlanceView(state: .sample(mood: .grubby, stage: .elder, name: "Professor Wattlebottom"))
            .environment(\.dynamicTypeSize, .accessibility5)
        let host = UIHostingController(rootView: view)
        let needed = host.sizeThatFits(in: CGSize(width: safeArea.width, height: .greatestFiniteMagnitude))
        #expect(needed.height <= safeArea.height, "needs \(needed.height) pt, has \(safeArea.height)")
    }
}
