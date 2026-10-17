import Foundation

/// 9 by 9 one-colour icons for the retro UI, drawn for this project.
public enum PixelIcon: String, CaseIterable, Sendable {
    /// A bowl with a sprig: feeding, and the fullness meter.
    case bowl
    /// Three bubbles: cleaning, and the cleanliness meter.
    case bubbles
    /// A striped ball: playing.
    case ball
    /// A crescent moon: bedtime.
    case moon
    /// A small sun: waking up.
    case sun
    /// A smiling face: the happiness meter.
    case smile
    /// A lightning bolt: the energy meter.
    case bolt
    /// A burst: cheering on the stage.
    case burst
    /// Two little figures: meeting nearby pets.
    case pair
    /// An exclamation in a bubble: the pet needs you.
    case attention
    /// A small leaf: all is well.
    case leaf

    public static let size = 9

    public var bitmap: PixelBitmap { PixelBitmap(rows: rows) }

    private var rows: [String] {
        switch self {
        case .bowl: [
            "......#..",
            ".....#...",
            "...#.#...",
            "....##...",
            "#########",
            "#.......#",
            ".#.....#.",
            "..#####..",
            ".........",
        ]
        case .bubbles: [
            ".....###.",
            "....#...#",
            "....#...#",
            ".##..###.",
            "#..#.....",
            "#..#..##.",
            ".##..#..#",
            "......##.",
            ".........",
        ]
        case .ball: [
            "..#####..",
            ".#..#..#.",
            "#...#...#",
            "#########",
            "#...#...#",
            "#...#...#",
            ".#..#..#.",
            "..#####..",
            ".........",
        ]
        case .moon: [
            "..####...",
            ".###.....",
            "###......",
            "###......",
            "###......",
            "####....#",
            ".#######.",
            "..#####..",
            ".........",
        ]
        case .sun: [
            "....#....",
            ".#.....#.",
            "...###...",
            "..#####..",
            "#.#####.#",
            "..#####..",
            "...###...",
            ".#.....#.",
            "....#....",
        ]
        case .smile: [
            "..#####..",
            ".#.....#.",
            "#..#.#..#",
            "#.......#",
            "#.#...#.#",
            "#..###..#",
            ".#.....#.",
            "..#####..",
            ".........",
        ]
        case .bolt: [
            ".....##..",
            "....##...",
            "...##....",
            "..#####..",
            "....##...",
            "...##....",
            "..##.....",
            ".##......",
            ".........",
        ]
        case .burst: [
            "....#....",
            ".#..#..#.",
            "..#...#..",
            "....#....",
            "##.###.##",
            "....#....",
            "..#...#..",
            ".#..#..#.",
            "....#....",
        ]
        case .pair: [
            ".##...##.",
            "#..#.#..#",
            "#..#.#..#",
            ".##...##.",
            "####.####",
            "####.####",
            "#..#.#..#",
            "#..#.#..#",
            ".........",
        ]
        case .attention: [
            ".#######.",
            "#...#...#",
            "#...#...#",
            "#...#...#",
            "#.......#",
            "#...#...#",
            ".#######.",
            "..#......",
            ".#.......",
        ]
        case .leaf: [
            ".....####",
            "...##...#",
            "..#....##",
            ".#....#.#",
            ".#...#..#",
            "#...#..#.",
            "#..#.##..",
            ".##......",
            "#........",
        ]
        }
    }
}

extension PetAction {
    /// The icon on this action's button.
    public var icon: PixelIcon {
        switch self {
        case .feed: .bowl
        case .clean: .bubbles
        case .play: .ball
        case .sleep: .moon
        case .wake: .sun
        }
    }
}

/// Segmented meters, like the bars on an old handheld's LCD.
public enum PixelMeter {
    public static let segments = 8

    /// How many of `count` segments are lit for `value` (0 to 1). Any value
    /// above zero lights at least one, so "nearly empty" never looks empty.
    public static func lit(_ value: Double, of count: Int = segments) -> Int {
        guard value.isFinite, value > 0, count > 0 else { return 0 }
        return min(count, max(1, Int((value * Double(count)).rounded())))
    }
}
