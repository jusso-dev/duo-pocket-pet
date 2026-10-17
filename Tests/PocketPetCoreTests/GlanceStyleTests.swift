import Foundation
import Testing
@testable import PocketPetCore

@Suite("Glance colours")
struct GlanceStyleTests {
    /// WCAG AA for normal-size text.
    let minimum = 4.5

    @Test func attentionTextMeetsAAInLightMode() {
        #expect(GlanceStyle.attentionLight.contrast(against: .white) >= minimum)
    }

    @Test func attentionTextMeetsAAInDarkMode() {
        #expect(GlanceStyle.attentionDark.contrast(against: .black) >= minimum)
    }

    @Test func systemOrangeOnWhiteFailsAA() {
        // The colour the glance used before. Guards against switching back.
        let systemOrange = RGB(1.0, 0.584, 0.0)
        #expect(systemOrange.contrast(against: .white) < 3)
    }

    @Test func contrastMatchesKnownValues() {
        #expect(abs(RGB.black.contrast(against: .white) - 21) < 0.001)
        #expect(abs(RGB.white.contrast(against: .white) - 1) < 0.001)
    }
}
