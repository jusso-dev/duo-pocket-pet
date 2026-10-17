import PocketPetCore
import SwiftUI

/// A reaction to play once, stamped with when it started.
struct PetReactionCue: Equatable {
    let reaction: PetReaction
    let startedAt: Date
}

/// Draws the Hingeling at a whole-number scale with hard pixel edges.
///
/// The sprite picks the largest whole-number scale that fits the space it is
/// given, so pixels never blur. With Reduce Motion on it holds a still frame
/// and skips reactions.
struct PetSpriteView: View {
    let state: PetState
    var onStage = false
    var reaction: PetReactionCue?
    /// Upper bound on the scale, so the sprite doesn't fill a whole iPad.
    var maxScale = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let scale = Self.scale(for: proxy.size, maxScale: maxScale)
            let side = CGFloat(PixelFrame.size * scale)
            TimelineView(.periodic(from: .now, by: reduceMotion ? 3600 : PetSpriteView.tick)) { timeline in
                PixelCanvas(frame: animator.frame(at: timeline.date, reduceMotion: reduceMotion), scale: scale)
                    .frame(width: side, height: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: CGFloat(PixelFrame.size * 2), minHeight: CGFloat(PixelFrame.size * 2))
        .accessibilityHidden(true)
    }

    /// Fast enough for reaction frames; loop frames change less often.
    static let tick: TimeInterval = PetAnimator.reactionFrameDuration / 2

    private var animator: PetAnimator {
        var animator = PetAnimator(state: state, onStage: onStage)
        if let reaction { animator.play(reaction.reaction, at: reaction.startedAt) }
        return animator
    }

    /// Largest whole-number scale that fits `size`, at least 1.
    static func scale(for size: CGSize, maxScale: Int) -> Int {
        let fit = Int(floor(min(size.width, size.height) / CGFloat(PixelFrame.size)))
        return max(1, min(maxScale, fit))
    }
}

/// Paints one frame as solid squares, so scaling is nearest-neighbour by construction.
private struct PixelCanvas: View {
    let frame: PixelFrame
    let scale: Int

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, _ in
            let s = CGFloat(scale)
            for y in 0..<frame.height {
                for x in 0..<frame.width {
                    guard let colour = PixelPalette.colour(for: frame[x, y]) else { continue }
                    context.fill(Path(CGRect(x: CGFloat(x) * s, y: CGFloat(y) * s, width: s, height: s)), with: .color(colour.swiftUI))
                }
            }
        }
        .drawingGroup(opaque: false, colorMode: .nonLinear)
    }
}

extension PixelColour {
    var swiftUI: Color {
        Color(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255, opacity: 1)
    }
}

// MARK: - Previews

#Preview("Every mood and stage") {
    ScrollView {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(LifeStage.allCases, id: \.self) { stage in
                GridRow {
                    ForEach(Mood.allCases, id: \.self) { mood in
                        VStack(spacing: 2) {
                            PetSpriteView(state: .sample(mood: mood, stage: stage), maxScale: 3)
                                .frame(width: 72, height: 72)
                            Text("\(stage.rawValue) \(mood.rawValue)").font(.caption2)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

#Preview("Reactions") {
    ReactionPreview()
}

#Preview("Stage routine") {
    PetSpriteView(state: .sample(mood: .content, stage: .grown), onStage: true)
}

private struct ReactionPreview: View {
    @State private var cue: PetReactionCue?

    var body: some View {
        VStack {
            PetSpriteView(state: .sample(mood: .content, stage: .young), reaction: cue)
            HStack {
                ForEach(PetReaction.allCases, id: \.self) { reaction in
                    Button(reaction.rawValue.capitalized) { cue = PetReactionCue(reaction: reaction, startedAt: .now) }
                }
            }
        }
        .padding()
    }
}
