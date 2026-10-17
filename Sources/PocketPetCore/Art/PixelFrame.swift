/// One frame of pixel art: a fixed-size grid of palette slots.
public struct PixelFrame: Equatable, Sendable {
    public static let size = 24

    public let width: Int
    public let height: Int
    /// Row-major, `width * height` slots.
    public private(set) var pixels: [PaletteSlot]

    public init(width: Int = PixelFrame.size, height: Int = PixelFrame.size) {
        self.width = width
        self.height = height
        pixels = Array(repeating: .clear, count: width * height)
    }

    public subscript(x: Int, y: Int) -> PaletteSlot {
        get {
            guard contains(x: x, y: y) else { return .clear }
            return pixels[y * width + x]
        }
        set {
            guard contains(x: x, y: y) else { return }
            pixels[y * width + x] = newValue
        }
    }

    public func contains(x: Int, y: Int) -> Bool {
        x >= 0 && y >= 0 && x < width && y < height
    }

    /// Draws `rows` with its top-left corner at (`x`, `y`). `.` leaves pixels untouched.
    public mutating func stamp(_ rows: [String], x: Int, y: Int) {
        for (dy, row) in rows.enumerated() {
            for (dx, symbol) in row.enumerated() {
                guard let slot = PaletteSlot(symbol: symbol), slot != .clear else { continue }
                self[x + dx, y + dy] = slot
            }
        }
    }

    /// Moves every pixel by (`dx`, `dy`), dropping what falls off the edge.
    public func shifted(dx: Int, dy: Int) -> PixelFrame {
        var out = PixelFrame(width: width, height: height)
        for y in 0..<height {
            for x in 0..<width where self[x, y] != .clear {
                out[x + dx, y + dy] = self[x, y]
            }
        }
        return out
    }

    /// The number of non-clear pixels.
    public var filledCount: Int { pixels.lazy.filter { $0 != .clear }.count }

    /// Text form, one row per line, handy for tests and debugging.
    public var ascii: String {
        (0..<height).map { y in String((0..<width).map { self[$0, y].symbol }) }.joined(separator: "\n")
    }
}
