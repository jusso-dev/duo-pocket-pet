import PocketPetCore
import SwiftUI

// Temporary stand-ins so the app builds before the real views land.
// - StageSlot: replaced by the stage scene (#7).
// Delete each slot when its replacement merges.

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
