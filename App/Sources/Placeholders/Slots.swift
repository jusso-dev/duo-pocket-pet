import PocketPetCore
import SwiftUI

// Temporary stand-ins so the app builds before the real views land.
// - StageSlot: replaced by the stage scene (#7).
// Delete each slot when its replacement merges.

struct StageSlot: View {
    let state: PetState
    let angleDegrees: Double

    var body: some View {
        VStack(spacing: 12) {
            PetSpriteView(state: state, onStage: true)
            // No debug readout here: this view ships until the real stage (#7) lands.
            Text("\(state.name) is \(state.mood.accessibilityDescription)")
                .font(.headline)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}
