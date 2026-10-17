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
        // Side by side when there's room (landscape), stacked otherwise. The
        // scroll view is a last resort for the largest accessibility sizes so
        // the name wraps rather than clips.
        ViewThatFits(in: .vertical) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 24) {
                    sprite
                    labels(alignment: .leading)
                }
                VStack(spacing: 16) {
                    sprite
                    labels(alignment: .center)
                }
            }
            ScrollView {
                VStack(spacing: 16) {
                    sprite.frame(height: 120)
                    labels(alignment: .center)
                }
                .frame(maxWidth: .infinity)
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

    private var sprite: some View {
        PetSpriteView(state: state, maxScale: 8)
            .frame(minWidth: 96, idealWidth: 192, maxWidth: 192, minHeight: 96, idealHeight: 192, maxHeight: 192)
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
