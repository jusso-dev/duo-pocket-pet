import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import PocketPetCore

@Suite("Reserved insets")
struct ReservedInsetsTests {
    let bounds = CGRect(x: 0, y: 0, width: 400, height: 800)

    @Test func noRegionsMeansNoInsets() {
        #expect(ReservedInsets(bounds: bounds, occlusions: []).isZero)
    }

    @Test func cameraNearTheTopPushesContentDown() {
        // A camera centred near the top edge, like an inner front camera in portrait.
        let insets = ReservedInsets(bounds: bounds, occlusions: [CGRect(x: 180, y: 8, width: 40, height: 40)])
        #expect(insets == ReservedInsets(top: 48))
    }

    @Test func cameraInACornerUsesTheNearerEdge() {
        // Closer to the trailing edge (10 pt) than to the top (30 pt).
        let insets = ReservedInsets(bounds: bounds, occlusions: [CGRect(x: 350, y: 30, width: 40, height: 40)])
        #expect(insets == ReservedInsets(trailing: 50))
    }

    @Test func cameraNearTheLeadingEdgeInLandscape() {
        let wide = CGRect(x: 0, y: 0, width: 800, height: 400)
        let insets = ReservedInsets(bounds: wide, occlusions: [CGRect(x: 6, y: 180, width: 36, height: 36)])
        #expect(insets == ReservedInsets(leading: 42))
    }

    @Test func regionsOutsideTheBoundsChangeNothing() {
        // Already inside the safe area, so outside this view's bounds.
        let insets = ReservedInsets(bounds: CGRect(x: 0, y: 60, width: 400, height: 700), occlusions: [CGRect(x: 180, y: 10, width: 40, height: 40)])
        #expect(insets.isZero)
    }

    @Test func onlyThePartInsideTheBoundsCounts() {
        let inner = CGRect(x: 0, y: 30, width: 400, height: 700)
        let insets = ReservedInsets(bounds: inner, occlusions: [CGRect(x: 180, y: 10, width: 40, height: 40)])
        #expect(insets == ReservedInsets(top: 20))
    }

    @Test func severalRegionsTakeTheLargestInsetPerEdge() {
        let insets = ReservedInsets(bounds: bounds, occlusions: [
            CGRect(x: 100, y: 4, width: 20, height: 20),
            CGRect(x: 300, y: 2, width: 30, height: 40),
            CGRect(x: 190, y: 770, width: 20, height: 20),
        ])
        #expect(insets == ReservedInsets(top: 42, bottom: 30))
    }

    @Test func emptyRegionsAreIgnored() {
        #expect(ReservedInsets(bounds: bounds, occlusions: [CGRect(x: 100, y: 0, width: 0, height: 30)]).isZero)
    }
}
