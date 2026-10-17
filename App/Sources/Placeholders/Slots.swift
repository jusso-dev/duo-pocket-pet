import PocketPetCore
import SwiftUI

// Temporary stand-ins so the app builds before the real views land.
// - GlanceSlot: replaced by Software Engineer 2's GlanceView (#4).
// - StageSlot: replaced by the stage scene (#7).
// Delete each slot when its replacement merges.

struct GlanceSlot: View {
    let state: PetState

    var body: some View {
        VStack(spacing: 12) {
            PetSpriteView(state: state, maxScale: 6)
            Text(state.name).font(.title2.bold())
            Text(state.mood.accessibilityDescription.capitalized).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(state.name) is \(state.mood.accessibilityDescription)")
    }
}

struct StageSlot: View {
    let state: PetState
    let angleDegrees: Double

    var body: some View {
        VStack {
            PetSpriteView(state: state, onStage: true)
            Text("Stage at \(Int(angleDegrees)) degrees").font(.caption)
        }
    }
}
