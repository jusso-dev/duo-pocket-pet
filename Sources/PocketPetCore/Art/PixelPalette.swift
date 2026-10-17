// Original palette for the Hingeling creature.
//
// Ten colours drawn from Australian bush at dusk: moss and eucalyptus greens,
// sandstone, dusk violet and a warm ember accent. They are not taken from any
// existing toy, game or brand palette. See docs/art.md.

/// An sRGB colour stored as 8-bit channels, so the art data has no UI dependency.
public struct PixelColour: Equatable, Hashable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(_ hex: UInt32) {
        red = UInt8((hex >> 16) & 0xFF)
        green = UInt8((hex >> 8) & 0xFF)
        blue = UInt8(hex & 0xFF)
    }
}

/// Palette slots. `clear` is transparent; every other slot maps to one colour.
public enum PaletteSlot: UInt8, CaseIterable, Sendable {
    case clear = 0
    case outline      // deep bush shadow
    case body         // moss
    case bodyLight    // eucalyptus highlight
    case belly        // sandstone
    case crease       // the hinge crease down the creature's middle
    case eye          // near-black eye
    case cheek        // ember blush
    case accent       // dusk violet: Zs, sparkles, notes
    case elderTuft    // silver-grey for the elder stage
    case grime        // muddy brown specks when grubby

    /// The symbol used in sprite source strings.
    public var symbol: Character {
        switch self {
        case .clear: "."
        case .outline: "o"
        case .body: "b"
        case .bodyLight: "l"
        case .belly: "s"
        case .crease: "c"
        case .eye: "e"
        case .cheek: "r"
        case .accent: "a"
        case .elderTuft: "t"
        case .grime: "g"
        }
    }

    public init?(symbol: Character) {
        guard let match = PaletteSlot.allCases.first(where: { $0.symbol == symbol }) else { return nil }
        self = match
    }
}

public enum PixelPalette {
    /// Colour for each visible slot. `clear` has no colour.
    public static func colour(for slot: PaletteSlot) -> PixelColour? {
        switch slot {
        case .clear: nil
        case .outline: PixelColour(0x1F2A24)
        case .body: PixelColour(0x5E8C61)
        case .bodyLight: PixelColour(0x8DB596)
        case .belly: PixelColour(0xE3C9A0)
        case .crease: PixelColour(0x3F6648)
        case .eye: PixelColour(0x141414)
        case .cheek: PixelColour(0xD9774B)
        case .accent: PixelColour(0x7A6AA8)
        case .elderTuft: PixelColour(0xC4C8CC)
        case .grime: PixelColour(0x7A5A3A)
        }
    }

    /// Number of distinct visible colours. The ticket asks for 8 to 16.
    public static var visibleColourCount: Int {
        Set(PaletteSlot.allCases.compactMap(colour(for:))).count
    }
}
