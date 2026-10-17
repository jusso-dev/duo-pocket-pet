import Foundation

/// An RGBA image as plain bytes, so the share card is built and tested without UIKit.
public struct RGBAImage: Equatable, Sendable {
    public let width: Int
    public let height: Int
    /// Row-major, four bytes a pixel (red, green, blue, alpha).
    public private(set) var bytes: [UInt8]

    public init(width: Int, height: Int, fill: RGB) {
        self.width = width
        self.height = height
        let px = Self.channels(fill)
        bytes = Array((0..<(width * height)).map { _ in px }.joined())
    }

    public func pixel(x: Int, y: Int) -> (UInt8, UInt8, UInt8) {
        let i = (y * width + x) * 4
        return (bytes[i], bytes[i + 1], bytes[i + 2])
    }

    mutating func fill(x: Int, y: Int, width w: Int, height h: Int, _ colour: (UInt8, UInt8, UInt8)) {
        let x0 = max(0, x), y0 = max(0, y), x1 = min(width, x + w), y1 = min(height, y + h)
        guard x0 < x1, y0 < y1 else { return }
        for py in y0..<y1 {
            for px in x0..<x1 {
                let i = (py * width + px) * 4
                bytes[i] = colour.0
                bytes[i + 1] = colour.1
                bytes[i + 2] = colour.2
                bytes[i + 3] = 255
            }
        }
    }

    static func channels(_ c: RGB) -> [UInt8] {
        [UInt8((c.red * 255).rounded()), UInt8((c.green * 255).rounded()), UInt8((c.blue * 255).rounded()), 255]
    }

    static func tuple(_ c: RGB) -> (UInt8, UInt8, UInt8) {
        let ch = channels(c)
        return (ch[0], ch[1], ch[2])
    }
}

/// The picture behind the Share button: the pet on its LCD with its name, life
/// stage and day, in the retro style. Only what any meetup would share; nothing
/// about the player.
public enum ShareCard {
    /// Size in card pixels before scaling.
    public static let width = 120
    public static let height = 156

    /// The words that go with the picture.
    public static func caption(for state: PetState) -> String {
        let day = Int(state.ageSeconds / 86_400) + 1
        return "Meet \(state.name), a \(state.lifeStage.displayName.lowercased()) Hingeling on day \(day). They're \(state.mood.accessibilityDescription) right now."
    }

    /// Renders the card. `scale` multiplies every card pixel, so the image is
    /// `width * scale` by `height * scale` with hard pixel edges.
    public static func render(_ state: PetState, palette: RetroPalette = .daylight, scale: Int = 4) -> RGBAImage {
        let s = max(1, scale)
        var img = RGBAImage(width: width * s, height: height * s, fill: palette.backdropTop)
        func box(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: RGB) {
            img.fill(x: x * s, y: y * s, width: w * s, height: h * s, RGBAImage.tuple(c))
        }
        func bitmap(_ b: PixelBitmap, _ x: Int, _ y: Int, _ c: RGB, _ k: Int = 1) {
            let colour = RGBAImage.tuple(c)
            for by in 0..<b.height {
                for bx in 0..<b.width where b[bx, by] {
                    img.fill(x: (x + bx * k) * s, y: (y + by * k) * s, width: k * s, height: k * s, colour)
                }
            }
        }

        // Dusk backdrop: the bottom half a shade lighter.
        box(0, height / 2, width, height - height / 2, palette.backdropBottom)

        // Bezel and LCD with stepped corners.
        box(5, 4, width - 10, 102, palette.bezel)
        box(4, 5, width - 8, 100, palette.bezel)
        box(9, 9, width - 18, 92, palette.lcd)
        for gy in stride(from: 10, to: 100, by: 2) {
            for gx in stride(from: 10, to: width - 10, by: 2) where (gx + gy) % 4 == 0 {
                box(gx, gy, 1, 1, palette.lcdGhost)
            }
        }

        // The pet, three card pixels to a sprite pixel.
        let frame = PetAnimator(state: state).frame(at: Date(timeIntervalSinceReferenceDate: 0), reduceMotion: true)
        let k = 3
        let sx = (width - PixelFrame.size * k) / 2
        let sy = 14
        for y in 0..<frame.height {
            for x in 0..<frame.width {
                guard let c = PixelPalette.colour(for: frame[x, y]) else { continue }
                box(sx + x * k, sy + y * k, k, k, RGB(Double(c.red) / 255, Double(c.green) / 255, Double(c.blue) / 255))
            }
        }

        // Name, then stage and day, under the screen.
        let name = PixelFont.layout(fitting(state.name, scale: 2), alignment: .centre)
        bitmap(name, (width - name.width * 2) / 2, 112, palette.backdropInk, 2)
        let day = Int(state.ageSeconds / 86_400) + 1
        let line = PixelFont.layout("\(state.lifeStage.displayName) Day \(day)", alignment: .centre)
        bitmap(line, (width - line.width) / 2, 132, palette.backdropInk)
        let brand = PixelFont.layout("Hingeling")
        bitmap(brand, (width - brand.width) / 2, 145, palette.lcdGhost)
        return img
    }

    /// Cuts a name to fit one line across the card at `scale`.
    static func fitting(_ name: String, scale: Int) -> String {
        let columns = (width - 8 + PixelFont.tracking * scale) / (PixelFont.advance * scale)
        let clean = PixelFont.normalise(name)
        return clean.count <= columns ? clean : String(clean.prefix(max(1, columns - 1))) + "."
    }
}
