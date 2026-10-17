import Foundation

/// An sRGB colour with components from 0 to 1. Kept in the core so contrast can
/// be checked in tests without UIKit.
public struct RGB: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let white = RGB(1, 1, 1)
    public static let black = RGB(0, 0, 0)

    /// WCAG 2 relative luminance.
    public var luminance: Double {
        func linear(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG 2 contrast ratio between two colours, from 1 to 21.
    public func contrast(against other: RGB) -> Double {
        let (a, b) = (luminance, other.luminance)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

/// Colours for the glance, which is the main screen while the phone is closed.
public enum GlanceStyle {
    /// The "needs attention" mood line in light mode. System orange is about
    /// 2.2:1 on white, so this is a darker burnt orange that clears 4.5:1.
    public static let attentionLight = RGB(0.72, 0.31, 0.0)
    /// The same line in dark mode, on a black background.
    public static let attentionDark = RGB(1.0, 0.624, 0.039)
}
