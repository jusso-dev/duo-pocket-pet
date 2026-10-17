import Foundation
import Testing
import UIKit
@testable import Hingeling

/// The app had no icon at all, so it showed the blank placeholder on the home
/// screen and couldn't be submitted. The tests are hosted in the app, so
/// `Bundle.main` is the built app.
@MainActor
@Suite("App icon")
struct AppIconTests {
    @Test func infoPlistNamesTheAppIcon() throws {
        let icons = try #require(Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any])
        let primary = try #require(icons["CFBundlePrimaryIcon"] as? [String: Any])
        #expect(primary["CFBundleIconName"] as? String == "AppIcon")
    }

    @Test func iconIsCompiledIntoTheAssetCatalogue() {
        #expect(UIImage(named: "AppIcon", in: .main, with: nil) != nil)
    }
}
