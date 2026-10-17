import Foundation

/// Colours for the retro UI: a pale LCD with dark ink by day, and a green
/// "backlight" with light ink in dark mode. Built from the creature's own bush
/// palette (see docs/art.md), not from any existing device or brand.
///
/// Kept in the core so contrast is checked by tests on Linux.
public struct RetroPalette: Equatable, Sendable {
    /// The dusk sky behind everything, top and bottom.
    public var backdropTop: RGB
    public var backdropBottom: RGB
    /// The frame around each LCD panel.
    public var bezel: RGB
    public var bezelHighlight: RGB
    /// The LCD itself, and its unlit pixel grid.
    public var lcd: RGB
    public var lcdGhost: RGB
    /// Text and lit pixels on the LCD.
    public var ink: RGB
    /// Secondary text on the LCD.
    public var inkSoft: RGB
    /// "Needs you" text and icons on the LCD.
    public var alert: RGB
    /// Chunky keycap buttons.
    public var keycap: RGB
    public var keycapHighlight: RGB
    public var keycapShadow: RGB
    public var keycapInk: RGB
    /// Text straight on the backdrop, outside any panel.
    public var backdropInk: RGB

    private static func hex(_ value: UInt32) -> RGB {
        RGB(Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    /// Daylight: a pale sage LCD.
    public static let daylight = RetroPalette(
        backdropTop: hex(0x2E264A), backdropBottom: hex(0x6E4E6C),
        bezel: hex(0x2B3A31), bezelHighlight: hex(0x3F6648),
        lcd: hex(0xD6DEC0), lcdGhost: hex(0xC7D0AE),
        ink: hex(0x1F2A24), inkSoft: hex(0x4A5A48), alert: hex(0x933D14),
        keycap: hex(0xE3C9A0), keycapHighlight: hex(0xF4E6CB), keycapShadow: hex(0x9C7F55), keycapInk: hex(0x1F2A24),
        backdropInk: hex(0xF4E6CB)
    )

    /// Dark mode: the backlight is on.
    public static let backlight = RetroPalette(
        backdropTop: hex(0x15121F), backdropBottom: hex(0x2E264A),
        bezel: hex(0x0F1A14), bezelHighlight: hex(0x2B3A31),
        lcd: hex(0x183326), lcdGhost: hex(0x1F3E30),
        ink: hex(0xCFEAC4), inkSoft: hex(0x9CC09A), alert: hex(0xFFB067),
        keycap: hex(0x3F6648), keycapHighlight: hex(0x5E8C61), keycapShadow: hex(0x1F2A24), keycapInk: hex(0xF4E6CB),
        backdropInk: hex(0xF4E6CB)
    )

    /// The same palette for Increase Contrast: the unlit-pixel grid is hidden
    /// and secondary text uses the full ink colour.
    public var increasedContrast: RetroPalette {
        var p = self
        p.lcdGhost = lcd
        p.inkSoft = ink
        p.keycapShadow = keycapInk
        return p
    }

    /// Pairs that carry text, with the contrast each must reach (WCAG AA, 4.5:1).
    public var textPairs: [(name: String, foreground: RGB, background: RGB)] {
        [
            ("ink on LCD", ink, lcd),
            ("soft ink on LCD", inkSoft, lcd),
            ("alert on LCD", alert, lcd),
            ("ink on keycap", keycapInk, keycap),
            ("backdrop ink on dusk", backdropInk, backdropBottom),
        ]
    }
}
