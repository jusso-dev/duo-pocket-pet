import PocketPetCore
import SwiftUI

/// Every iPhone without a hinge: a compact glance header, then the home screen
/// with a Bedtime or Wake button standing in for closing the phone.
struct StandardHomeView: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            GlanceHeader(state: model.state)
            HomeView(model: model, showsBedtime: true)
        }
    }
}

/// One line with the pet's name, life stage and mood, like the glance a closed
/// iPhone Duo shows. Reads as a single VoiceOver element.
struct GlanceHeader: View {
    let state: PetState

    private var content: GlanceContent { GlanceContent(state: state) }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                name
                Text(content.stageLabel).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                mood
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    name
                    Text(content.stageLabel).foregroundStyle(.secondary)
                }
                mood
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
        .accessibilityValue(content.accessibilityValue)
        .accessibilityIdentifier("glanceHeader")
    }

    private var name: some View {
        Text(content.name).font(.subheadline.bold()).lineLimit(1).truncationMode(.tail)
    }

    private var mood: some View {
        Label(content.moodLine, systemImage: content.needsAttention ? "exclamationmark.circle.fill" : "leaf.fill")
            .foregroundStyle(content.needsAttention ? Color.glanceAttention : Color.secondary)
    }
}

#Preview("Standard iPhone") {
    StandardHomeView(model: AppModel(store: InMemoryPetStore(.sample(mood: .hungry, stage: .young)), fold: StaticFoldStateService(.unavailable)))
}

#Preview("Standard iPhone, landscape", traits: .landscapeLeft) {
    StandardHomeView(model: AppModel(store: InMemoryPetStore(.sample(mood: .content, stage: .grown)), fold: StaticFoldStateService(.unavailable)))
}

#Preview("Standard iPhone, largest text") {
    StandardHomeView(model: AppModel(store: InMemoryPetStore(.sample(mood: .grubby, stage: .elder, name: "Professor Wattlebottom")), fold: StaticFoldStateService(.unavailable)))
        .environment(\.dynamicTypeSize, .accessibility5)
}
