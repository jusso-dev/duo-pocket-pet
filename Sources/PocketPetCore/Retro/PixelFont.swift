import Foundation

/// A 5 by 7 pixel alphabet for the retro UI's short labels: names, scene
/// titles and button captions. Drawn for this project. Upper case only;
/// lower case is folded to upper and anything unknown becomes `?`.
///
/// Pixel text is decoration. Every view that shows it also gives VoiceOver the
/// real string, and longer sentences use the system font so Dynamic Type works.
public enum PixelFont {
    public static let glyphWidth = 5
    public static let glyphHeight = 7
    /// Blank columns between letters.
    public static let tracking = 1
    /// Blank rows between lines.
    public static let leading = 2
    /// One glyph cell plus tracking.
    public static var advance: Int { glyphWidth + tracking }
    public static var lineHeight: Int { glyphHeight + leading }

    public enum Alignment: Sendable { case leading, centre }

    /// The bitmap for one character.
    public static func glyph(_ character: Character) -> PixelBitmap {
        PixelBitmap(rows: rows(for: character) ?? rows(for: "?")!)
    }

    /// True when the font has a glyph for `character` (after folding case and accents).
    public static func supports(_ character: Character) -> Bool {
        rows(for: character) != nil
    }

    /// Lays out `text` across lines no wider than `maxWidth` pixels, breaking
    /// at spaces where it can and inside long words where it must.
    public static func layout(_ text: String, maxWidth: Int = .max, alignment: Alignment = .leading) -> PixelBitmap {
        // `maxWidth` defaults to `Int.max`, so add the tracking without overflowing.
        let maxColumns = maxWidth > Int.max - tracking ? Int.max / advance : (maxWidth + tracking) / advance
        let lines = wrap(normalise(text), maxColumns: max(1, maxColumns))
        let columns = lines.map(\.count).max() ?? 0
        let width = max(0, columns * advance - tracking)
        let height = lines.isEmpty ? 0 : lines.count * lineHeight - leading
        var out = PixelBitmap(width: width, height: height)
        for (row, line) in lines.enumerated() {
            let lineWidth = max(0, line.count * advance - tracking)
            let x0 = alignment == .centre ? (width - lineWidth) / 2 : 0
            for (i, ch) in line.enumerated() where ch != " " {
                out.draw(glyph(ch), x: x0 + i * advance, y: row * lineHeight)
            }
        }
        return out
    }

    /// Upper case, accents removed, whitespace collapsed.
    static func normalise(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_AU")).uppercased()
        return folded.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    static func wrap(_ text: String, maxColumns: Int) -> [String] {
        guard !text.isEmpty else { return [] }
        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ").map(String.init) {
            var word = word
            // Words longer than a line are split across lines.
            while word.count > maxColumns {
                if !current.isEmpty { lines.append(current); current = "" }
                lines.append(String(word.prefix(maxColumns)))
                word = String(word.dropFirst(maxColumns))
            }
            if current.isEmpty {
                current = word
            } else if current.count + 1 + word.count <= maxColumns {
                current += " " + word
            } else {
                lines.append(current)
                current = word
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    private static func rows(for character: Character) -> [String]? {
        let key = normalise(String(character)).first ?? character
        return glyphs[key]
    }

    private static let glyphs: [Character: [String]] = [
        " ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
        "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
        "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
        "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
        "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
        "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
        "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
        "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
        "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
        "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
        "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
        "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
        "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
        "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
        "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
        "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
        "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
        "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
        "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
        "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
        "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
        "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
        ".": [".....", ".....", ".....", ".....", ".....", ".##..", ".##.."],
        ",": [".....", ".....", ".....", ".....", ".##..", "..#..", ".#..."],
        "!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
        "?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
        ":": [".....", ".##..", ".##..", ".....", ".##..", ".##..", "....."],
        "-": [".....", ".....", ".....", ".###.", ".....", ".....", "....."],
        "'": ["..#..", "..#..", ".#...", ".....", ".....", ".....", "....."],
        "/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
        "%": ["##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"],
        "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
        "&": [".##..", "#..#.", "#.#..", ".#...", "#.#.#", "#..#.", ".##.#"],
        "(": ["...#.", "..#..", ".#...", ".#...", ".#...", "..#..", "...#."],
        ")": [".#...", "..#..", "...#.", "...#.", "...#.", "..#..", ".#..."],
    ]
}
