import PocketPetCore
import SwiftUI

/// The compact view shown while an iPhone Duo is closed.
///
/// A closed Duo behaves like a compact iPhone, so this is an ordinary compact
/// layout. It shows the pet, its name, life stage and mood, takes no input and
/// reads as one VoiceOver element, for example "Bip is asleep".
struct GlanceView: View {
    let state: PetState
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    private var content: GlanceContent { GlanceContent(state: state) }
    private var palette: RetroPalette { .current(scheme, contrast) }

    var body: some View {
        // Side by side when there's room (landscape), stacked otherwise, and a
        // smaller sprite as a last resort at the largest accessibility text
        // sizes. No scroll view: the glance takes no input, so anything that
        // needed scrolling would be unreachable. Text wraps rather than clips.
        ViewThatFits {
            HStack(spacing: 24) {
                sprite(min: 96)
                labels(alignment: .leading)
            }
            VStack(spacing: 16) {
                sprite(min: 96)
                labels(alignment: .center)
            }
            VStack(spacing: 8) {
                sprite(min: 48)
                labels(alignment: .center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .lcdPanel()
        .padding()
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
        .accessibilityValue(content.accessibilityValue)
        .accessibilityIdentifier("glance")
    }

    private func sprite(min side: CGFloat) -> some View {
        PetSpriteView(state: state, maxScale: 8, halo: scheme == .dark ? palette.inkSoft.color.opacity(0.55) : nil)
            .frame(minWidth: side, idealWidth: 192, maxWidth: 192, minHeight: side, idealHeight: 192, maxHeight: 192)
    }

    private var moodIcon: PixelIcon {
        if state.isAsleep { return .moon }
        return content.needsAttention ? .attention : .leaf
    }

    private func labels(alignment: HorizontalAlignment) -> some View {
        let pixelAlignment: PixelFont.Alignment = alignment == .center ? .centre : .leading
        let moodColour = content.needsAttention ? palette.alert.color : palette.ink.color
        return VStack(alignment: alignment, spacing: 10) {
            PixelText(text: content.name, size: 5, colour: palette.ink.color, alignment: pixelAlignment)
            PixelText(text: content.stageLabel, size: 2, colour: palette.inkSoft.color, alignment: pixelAlignment)
            HStack(spacing: 8) {
                PixelIconView(icon: moodIcon, scale: 2, colour: moodColour)
                PixelText(text: content.moodLine, size: 2, colour: moodColour)
            }
        }
    }
}

// MARK: - Previews

#Preview("Every mood") {
    TabView {
        ForEach(Mood.allCases, id: \.self) { mood in
            GlanceView(state: .sample(mood: mood, stage: .young))
                .tabItem { Text(mood.rawValue) }
        }
    }
    .tabViewStyle(.page(indexDisplayMode: .always))
}

#Preview("Every life stage") {
    VStack {
        ForEach(LifeStage.allCases, id: \.self) { stage in
            GlanceView(state: .sample(mood: .content, stage: stage))
        }
    }
}

#Preview("Landscape", traits: .landscapeLeft) {
    GlanceView(state: .sample(mood: .hungry, stage: .grown))
}

#Preview("Largest text, long name") {
    GlanceView(state: .sample(mood: .grubby, stage: .elder, name: "Professor Wattlebottom"))
        .environment(\.dynamicTypeSize, .accessibility5)
}
