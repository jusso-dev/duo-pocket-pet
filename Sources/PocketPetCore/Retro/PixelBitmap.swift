import Foundation

/// A one-colour pixel image: each pixel is lit or not. Used for the retro UI's
/// lettering and icons, which the app draws in whatever ink the theme says.
public struct PixelBitmap: Equatable, Sendable {
    public let width: Int
    public let height: Int
    /// Row-major, `width * height` pixels.
    public private(set) var bits: [Bool]

    public init(width: Int, height: Int) {
        self.width = max(0, width)
        self.height = max(0, height)
        bits = Array(repeating: false, count: self.width * self.height)
    }

    /// From text rows, `#` for lit and anything else for unlit. Short rows are padded.
    public init(rows: [String]) {
        let width = rows.map(\.count).max() ?? 0
        self.init(width: width, height: rows.count)
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() where ch == "#" { self[x, y] = true }
        }
    }

    public subscript(x: Int, y: Int) -> Bool {
        get {
            guard x >= 0, y >= 0, x < width, y < height else { return false }
            return bits[y * width + x]
        }
        set {
            guard x >= 0, y >= 0, x < width, y < height else { return }
            bits[y * width + x] = newValue
        }
    }

    /// Lights every lit pixel of `other` with its top-left corner at (`x`, `y`).
    public mutating func draw(_ other: PixelBitmap, x: Int, y: Int) {
        for oy in 0..<other.height {
            for ox in 0..<other.width where other[ox, oy] { self[x + ox, y + oy] = true }
        }
    }

    public var litCount: Int { bits.lazy.filter { $0 }.count }

    /// Text form, `#` and `.`, for tests.
    public var ascii: String {
        (0..<height).map { y in String((0..<width).map { self[$0, y] ? "#" : "." }) }.joined(separator: "\n")
    }
}
