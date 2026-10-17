import PocketPetCore
import SwiftUI

// The retro look: pixel lettering, LCD panels with a faint unlit-pixel grid,
// chunky keycap buttons and segmented meters. Daylight LCD in light mode, a
// green backlight in dark mode. Colours come from `RetroPalette` in the core,
// where their contrast is tested.

extension RGB {
    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
}

extension RetroPalette {
    static func current(_ scheme: ColorScheme) -> RetroPalette {
        scheme == .dark ? .backlight : .daylight
    }
}

extension EnvironmentValues {
    /// The retro palette for the current colour scheme.
    var retro: RetroPalette { RetroPalette.current(colorScheme) }
}

/// The dusk sky behind every scene.
struct RetroBackdrop: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = RetroPalette.current(scheme)
        LinearGradient(colors: [p.backdropTop.color, p.backdropBottom.color], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

/// A rectangle with stepped, pixel-style corners.
struct SteppedRectangle: Shape {
    var step: CGFloat = 4

    func path(in rect: CGRect) -> Path {
        let s = min(step, rect.width / 4, rect.height / 4)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + s, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - s, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - s, y: rect.minY + s / 2))
        p.addLine(to: CGPoint(x: rect.maxX - s / 2, y: rect.minY + s / 2))
        p.addLine(to: CGPoint(x: rect.maxX - s / 2, y: rect.minY + s))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + s))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - s))
        p.addLine(to: CGPoint(x: rect.maxX - s / 2, y: rect.maxY - s))
        p.addLine(to: CGPoint(x: rect.maxX - s / 2, y: rect.maxY - s / 2))
        p.addLine(to: CGPoint(x: rect.maxX - s, y: rect.maxY - s / 2))
        p.addLine(to: CGPoint(x: rect.maxX - s, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + s, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + s, y: rect.maxY - s / 2))
        p.addLine(to: CGPoint(x: rect.minX + s / 2, y: rect.maxY - s / 2))
        p.addLine(to: CGPoint(x: rect.minX + s / 2, y: rect.maxY - s))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - s))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + s))
        p.addLine(to: CGPoint(x: rect.minX + s / 2, y: rect.minY + s))
        p.addLine(to: CGPoint(x: rect.minX + s / 2, y: rect.minY + s / 2))
        p.addLine(to: CGPoint(x: rect.minX + s, y: rect.minY + s / 2))
        p.closeSubpath()
        return p
    }
}

/// An LCD panel: a dark bezel, the screen, and a faint grid of unlit pixels.
struct LCDPanel: ViewModifier {
    var padding: CGFloat = 12
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let p = RetroPalette.current(scheme)
        content
            .padding(padding)
            .background {
                LCDGrid(colour: p.lcdGhost.color)
                    .background(p.lcd.color)
                    .clipShape(SteppedRectangle(step: 4))
            }
            .padding(6)
            .background {
                SteppedRectangle(step: 8)
                    .fill(p.bezel.color)
                    .overlay(alignment: .top) {
                        // A thin highlight along the top edge, like moulded plastic.
                        Rectangle().fill(p.bezelHighlight.color).frame(height: 2).padding(.horizontal, 10).padding(.top, 2)
                    }
            }
    }
}

/// The unlit pixel grid behind the LCD content.
private struct LCDGrid: View {
    let colour: Color

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            var path = Path()
            var y: CGFloat = 3
            while y < size.height - 2 {
                var x: CGFloat = 3
                while x < size.width - 2 {
                    path.addRect(CGRect(x: x, y: y, width: 3, height: 3))
                    x += 4
                }
                y += 4
            }
            context.fill(path, with: .color(colour))
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

extension View {
    func lcdPanel(padding: CGFloat = 12) -> some View {
        modifier(LCDPanel(padding: padding))
    }
}

/// Draws a one-colour pixel bitmap at a whole-number scale, with hard edges.
struct PixelBitmapView: View {
    let bitmap: PixelBitmap
    var scale: Int = 2
    var colour: Color

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, _ in
            let s = CGFloat(scale)
            var path = Path()
            for y in 0..<bitmap.height {
                for x in 0..<bitmap.width where bitmap[x, y] {
                    path.addRect(CGRect(x: CGFloat(x) * s, y: CGFloat(y) * s, width: s, height: s))
                }
            }
            context.fill(path, with: .color(colour))
        }
        .frame(width: CGFloat(bitmap.width * scale), height: CGFloat(bitmap.height * scale))
        .accessibilityHidden(true)
    }
}

/// A pixel icon. Decorative: the control it sits on carries the label.
struct PixelIconView: View {
    let icon: PixelIcon
    var scale: Int = 2
    var colour: Color

    var body: some View {
        PixelBitmapView(bitmap: icon.bitmap, scale: scale, colour: colour)
    }
}

/// Lettering in the pixel font, wrapped to the width it is offered.
///
/// VoiceOver reads `text` as written, and the size follows Dynamic Type in
/// whole-pixel steps. Use it for short labels; sentences use the system font.
struct PixelText: View {
    let text: String
    /// Pixel size at the default text size. Scales with Dynamic Type.
    var size: CGFloat = 2
    var colour: Color
    var alignment: PixelFont.Alignment = .leading
    /// The largest pixel size at any text size, so big lettering doesn't
    /// crowd out everything else at the accessibility sizes.
    var maxScale = 6

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Whole pixels, so letters stay crisp.
    private var scale: Int {
        min(maxScale, max(1, Int((size * Self.factor(for: dynamicTypeSize)).rounded())))
    }

    var body: some View {
        PixelTextLayout(text: text, scale: scale, alignment: alignment) {
            Canvas(rendersAsynchronously: false) { context, canvasSize in
                let bitmap = PixelFont.layout(text, maxWidth: Int(canvasSize.width) / scale, alignment: alignment)
                let s = CGFloat(scale)
                let x0 = alignment == .centre ? ((canvasSize.width - CGFloat(bitmap.width) * s) / 2).rounded(.down) : 0
                var path = Path()
                for y in 0..<bitmap.height {
                    for x in 0..<bitmap.width where bitmap[x, y] {
                        path.addRect(CGRect(x: x0 + CGFloat(x) * s, y: CGFloat(y) * s, width: s, height: s))
                    }
                }
                context.fill(path, with: .color(colour))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
        .accessibilityAddTraits(.isStaticText)
    }

    /// Roughly how much the body style grows at each Dynamic Type size.
    static func factor(for size: DynamicTypeSize) -> CGFloat {
        switch size {
        case .xSmall, .small: 0.85
        case .medium, .large: 1
        case .xLarge, .xxLarge: 1.25
        case .xxxLarge: 1.5
        case .accessibility1, .accessibility2: 2
        case .accessibility3, .accessibility4: 2.5
        case .accessibility5: 3
        @unknown default: 1
        }
    }
}

/// Sizes pixel text: as wide as it needs, wrapping to the proposed width.
private struct PixelTextLayout: Layout {
    let text: String
    let scale: Int
    let alignment: PixelFont.Alignment

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // Huge or infinite proposals mean "no limit"; converting them to Int would trap.
        let maxWidth = proposal.width.map { $0.isFinite && $0 < 1_000_000 ? Int($0) / scale : Int.max } ?? Int.max
        let bitmap = PixelFont.layout(text, maxWidth: maxWidth, alignment: alignment)
        let width = CGFloat(bitmap.width * scale)
        // Centred text takes the whole width offered, so it centres in it.
        let proposed = proposal.width.flatMap { $0.isFinite ? $0 : nil }
        return CGSize(width: alignment == .centre ? max(width, proposed ?? width) : width, height: CGFloat(bitmap.height * scale))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
        }
    }
}

/// A chunky keycap: a raised face on a darker base that presses down.
struct KeycapButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let p = RetroPalette.current(scheme)
        let pressed = configuration.isPressed
        configuration.label
            .foregroundStyle(p.keycapInk.color)
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                SteppedRectangle(step: 6)
                    .fill(p.keycap.color)
                    .overlay(alignment: .top) {
                        Rectangle().fill(p.keycapHighlight.color).frame(height: 3).padding(.horizontal, 8).padding(.top, 3)
                    }
            }
            .offset(y: pressed ? 3 : 0)
            .background {
                SteppedRectangle(step: 6)
                    .fill(p.keycapShadow.color)
                    .offset(y: 4)
            }
            .padding(.bottom, 4)
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Rectangle())
    }
}

/// The face of a keycap: a pixel icon and a pixel caption.
struct KeycapLabel: View {
    let title: String
    let icon: PixelIcon
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let ink = RetroPalette.current(scheme).keycapInk.color
        HStack(spacing: 8) {
            PixelIconView(icon: icon, scale: 3, colour: ink)
            PixelText(text: title, size: 2, colour: ink, maxScale: 5)
                .fixedSize()
        }
    }
}

/// A segmented meter, like the bars on an old handheld.
struct SegmentMeter: View {
    let value: Double
    var segments = PixelMeter.segments
    let lit: Color
    let unlit: Color

    var body: some View {
        let on = PixelMeter.lit(value, of: segments)
        HStack(spacing: 3) {
            ForEach(0..<segments, id: \.self) { i in
                Rectangle()
                    .fill(i < on ? lit : unlit)
                    .frame(minWidth: 6, maxWidth: 14)
            }
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }
}
