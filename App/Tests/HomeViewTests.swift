import Foundation
import PocketPetCore
import SwiftUI
import Testing
import UIKit
@testable import Hingeling

@MainActor
@Suite("Home view")
struct HomeViewTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    /// A 4.7 inch compact iPhone is 375 pt wide. HomeView pads 16 pt each side.
    private let availableWidth: CGFloat = 375 - 32

    private func items(_ titles: [String]) -> [ActionRow.Item] {
        titles.map { ActionRow.Item(title: $0, systemImage: "circle", hint: "", action: {}) }
    }

    /// Ideal (unconstrained) size, the space the content asks for.
    private func idealSize(_ view: some View, _ size: DynamicTypeSize) throws -> CGSize {
        let renderer = ImageRenderer(content: view.environment(\.dynamicTypeSize, size))
        renderer.scale = 1
        return try #require(renderer.uiImage).size
    }

    /// The bug: four buttons in one row at AX sizes. Their labels alone need
    /// more than a compact screen's width, so the old HStack truncated them.
    @Test(arguments: [DynamicTypeSize.accessibility1, .accessibility3, .accessibility5])
    func fourButtonsFitACompactScreen(size: DynamicTypeSize) throws {
        let titles = ["Feed", "Clean", "Play", "Bedtime"]
        let oneRow = try idealSize(HStack(spacing: 12) {
            ForEach(titles, id: \.self) { Button($0, systemImage: "circle") {}.buttonStyle(.borderedProminent) }
        }, size)
        #expect(oneRow.width > availableWidth, "one row needs \(oneRow.width) pt, so it must not be used at \(size)")

        let row = try idealSize(ActionRow(buttons: items(titles), dynamicTypeSize: size), size)
        #expect(row.width <= availableWidth, "ActionRow needs \(row.width) pt at \(size)")
    }

    @Test func standardSizeKeepsOneRowWhenItFits() throws {
        let row = try idealSize(ActionRow(buttons: items(["Feed", "Clean", "Play"]), dynamicTypeSize: .large), .large)
        // A row is about one button tall. A stack of three would be three times that.
        let single = try idealSize(Button("Feed", systemImage: "circle") {}.buttonStyle(.borderedProminent), .large)
        #expect(row.height < single.height * 2)
    }

    /// The whole standard-iPhone home screen at the largest size scrolls rather
    /// than clipping, so it renders at the screen size whatever the content.
    @Test func homeRendersAtTheLargestTextSize() throws {
        let model = AppModel(store: InMemoryPetStore(PetState(hunger: 0.9, bornAt: t0)), fold: StaticFoldStateService(.unavailable), clock: { [t0] in t0 })
        let screen = CGSize(width: 375, height: 667 - 20)
        let renderer = ImageRenderer(content: HomeView(model: model, showsBedtime: true)
            .environment(\.dynamicTypeSize, .accessibility5)
            .frame(width: screen.width, height: screen.height))
        renderer.scale = 1
        #expect(try #require(renderer.uiImage).size == screen)
    }

    /// Smallest and largest iPhones, both orientations, and a narrow Split View
    /// width. The standard layout fills the space it is given at every size.
    @Test(arguments: [
        CGSize(width: 320, height: 548),   // narrow Split View column, or the smallest phone
        CGSize(width: 375, height: 647),   // 4.7 inch portrait
        CGSize(width: 667, height: 355),   // 4.7 inch landscape
        CGSize(width: 440, height: 896),   // Pro Max portrait
        CGSize(width: 956, height: 400),   // Pro Max landscape
    ])
    func standardLayoutFillsEveryScreen(screen: CGSize) throws {
        for size in [DynamicTypeSize.large, .accessibility3] {
            let model = AppModel(store: InMemoryPetStore(PetState(hunger: 0.9, bornAt: t0)), fold: StaticFoldStateService(.unavailable), clock: { [t0] in t0 })
            let renderer = ImageRenderer(content: StandardHomeView(model: model)
                .environment(\.dynamicTypeSize, size)
                .frame(width: screen.width, height: screen.height))
            renderer.scale = 1
            #expect(try #require(renderer.uiImage).size == screen, "at \(size)")
        }
    }
}
