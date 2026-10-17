import Foundation

extension PixelFrame {
    /// The clear pixels that touch a filled one, up, down, left or right.
    ///
    /// On the dark "backlight" LCD the creature's near-black outline would
    /// vanish, so the app lights these pixels to give it a glowing edge.
    public var halo: PixelBitmap {
        var out = PixelBitmap(width: width, height: height)
        for y in 0..<height {
            for x in 0..<width where self[x, y] == .clear {
                if self[x - 1, y] != .clear || self[x + 1, y] != .clear || self[x, y - 1] != .clear || self[x, y + 1] != .clear {
                    out[x, y] = true
                }
            }
        }
        return out
    }
}
