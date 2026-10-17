import PocketPetCore
import SwiftUI

/// The compact view shown while an iPhone Duo is closed.
///
/// A closed Duo behaves like a compact iPhone, so this is an ordinary compact
/// layout. It shows the pet, its name, life stage and mood, takes no input and
/// reads as one VoiceOver element, for example "Bip is asleep".
struct GlanceView: View {
    let state: PetState

    private var content: GlanceContent { GlanceContent(state: state) }

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
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
        .accessibilityValue(content.accessibilityValue)
        .accessibilityIdentifier("glance")
    }

    private func sprite(min side: CGFloat) -> some View {
        PetSpriteView(state: state, maxScale: 8)
            .frame(minWidth: side, idealWidth: 192, maxWidth: 192, minHeight: side, idealHeight: 192, maxHeight: 192)
    }

    private func labels(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(content.name)
                .font(.title.bold())
                .multilineTextAlignment(alignment == .center ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(content.stageLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Label {
                Text(content.moodLine)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: content.needsAttention ? "exclamationmark.circle.fill" : "leaf.fill")
            }
            .font(.headline)
            .foregroundStyle(content.needsAttention ? Color.orange : Color.secondary)
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
