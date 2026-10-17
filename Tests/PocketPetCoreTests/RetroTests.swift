import Foundation
import Testing
@testable import PocketPetCore

@Suite("Pixel font")
struct PixelFontTests {
    @Test func everyGlyphIsFiveBySeven() {
        for ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?:-'/%+&() " {
            let g = PixelFont.glyph(ch)
            #expect(g.width == 5 && g.height == 7, "\(ch)")
            if ch != " " { #expect(g.litCount > 0, "\(ch)") }
        }
    }

    @Test func lettersAreDistinct() {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let shapes = Set(letters.map { PixelFont.glyph($0).ascii })
        #expect(shapes.count == letters.count)
    }

    @Test func lowerCaseAndAccentsFold() {
        #expect(PixelFont.glyph("b") == PixelFont.glyph("B"))
        #expect(PixelFont.glyph("é") == PixelFont.glyph("E"))
        #expect(PixelFont.glyph("ß") == PixelFont.glyph("?") || PixelFont.supports("ß"))
        #expect(PixelFont.glyph("🦘") == PixelFont.glyph("?"))
    }

    @Test func layoutSizesAndWraps() {
        let one = PixelFont.layout("BIP")
        #expect(one.width == 3 * 6 - 1)
        #expect(one.height == 7)
        // 40 pixels fits 6 columns, so "BIP" and "HUNGRY" go on separate lines.
        let two = PixelFont.layout("Bip hungry", maxWidth: 40)
        #expect(two.height == 2 * 9 - 2)
        #expect(two.width <= 40)
        #expect(PixelFont.wrap("BIP IS HUNGRY", maxColumns: 6) == ["BIP IS", "HUNGRY"])
    }

    @Test func longWordsBreak() {
        #expect(PixelFont.wrap("WATTLEBOTTOM", maxColumns: 5) == ["WATTL", "EBOTT", "OM"])
        #expect(PixelFont.layout("", maxWidth: 10).height == 0)
    }

    @Test func centredLinesSitInTheMiddle() {
        let block = PixelFont.layout("AAA A", maxWidth: 17, alignment: .centre)
        // Second line is one glyph in a three-glyph-wide block: it starts at column 6.
        var firstLit = -1
        for x in 0..<block.width where block[x, 9 + 3] { firstLit = x; break }
        #expect(firstLit == 6)
    }
}

@Suite("Pixel icons and meters")
struct PixelIconTests {
    @Test func iconsAreNineByNineAndDistinct() {
        for icon in PixelIcon.allCases {
            #expect(icon.bitmap.width == 9 && icon.bitmap.height == 9, "\(icon)")
            #expect(icon.bitmap.litCount >= 10, "\(icon)")
        }
        #expect(Set(PixelIcon.allCases.map(\.bitmap.ascii)).count == PixelIcon.allCases.count)
    }

    @Test func everyActionHasAnIcon() {
        #expect(Set(PetAction.allCases.map(\.icon)).count == PetAction.allCases.count)
    }

    @Test func meterSegments() {
        #expect(PixelMeter.lit(0) == 0)
        #expect(PixelMeter.lit(0.01) == 1)
        #expect(PixelMeter.lit(0.5) == 4)
        #expect(PixelMeter.lit(1) == 8)
        #expect(PixelMeter.lit(7) == 8)
        #expect(PixelMeter.lit(.nan) == 0)
    }
}

@Suite("Retro palette")
struct RetroPaletteTests {
    @Test(arguments: [("daylight", RetroPalette.daylight), ("backlight", RetroPalette.backlight)])
    func textMeetsAA(name: String, palette: RetroPalette) {
        for pair in palette.textPairs {
            let ratio = pair.foreground.contrast(against: pair.background)
            #expect(ratio >= 4.5, "\(name): \(pair.name) is \(ratio)")
        }
    }

    @Test(arguments: [RetroPalette.daylight, RetroPalette.backlight])
    func unlitPixelsStayFaint(palette: RetroPalette) {
        // The ghost grid should be visible but well below the ink.
        let ghost = palette.lcdGhost.contrast(against: palette.lcd)
        #expect(ghost > 1.02 && ghost < 1.5)
        #expect(palette.ink.contrast(against: palette.lcdGhost) >= 4.5)
    }
}

@Suite("Sprite halo")
struct SpriteHaloTests {
    @Test func haloWrapsTheSpriteWithoutCoveringIt() {
        var frame = PixelFrame(width: 5, height: 5)
        frame[2, 2] = .body
        let halo = frame.halo
        #expect(halo.litCount == 4)
        #expect(halo[1, 2] && halo[3, 2] && halo[2, 1] && halo[2, 3])
        #expect(!halo[2, 2])
    }

    @Test func everyPoseHasAHalo() {
        let frame = PetSprites.frames(for: .mood(.content), stage: .young)[0]
        let halo = frame.halo
        #expect(halo.litCount > 20)
        for y in 0..<frame.height {
            for x in 0..<frame.width where halo[x, y] { #expect(frame[x, y] == .clear) }
        }
    }
}

@Suite("Pixel font limits")
struct PixelFontLimitTests {
    /// The default width is `Int.max`; adding the tracking to it used to overflow and trap.
    @Test func noWidthLimitDoesNotOverflow() {
        #expect(PixelFont.layout("BIP IS HUNGRY", maxWidth: .max).height == PixelFont.glyphHeight)
        #expect(PixelFont.layout("BIP", maxWidth: .max - 1).width == 17)
    }
}

@Suite("Increase Contrast")
struct IncreasedContrastTests {
    @Test(arguments: [RetroPalette.daylight, RetroPalette.backlight])
    func gridGoesAndSoftTextGetsFullInk(palette: RetroPalette) {
        let strong = palette.increasedContrast
        #expect(strong.lcdGhost == strong.lcd)
        #expect(strong.inkSoft == strong.ink)
        for pair in strong.textPairs {
            #expect(pair.foreground.contrast(against: pair.background) >= 4.5, "\(pair.name)")
        }
        // Every text pair is at least as strong as before.
        for (before, after) in zip(palette.textPairs, strong.textPairs) {
            #expect(after.foreground.contrast(against: after.background) >= before.foreground.contrast(against: before.background))
        }
    }
}
