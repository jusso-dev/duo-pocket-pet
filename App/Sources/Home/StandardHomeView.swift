import PocketPetCore
import SwiftUI

/// Every iPhone without a hinge: the home screen with a Bedtime or Wake button
/// standing in for closing the phone. Nearby play opens from the home screen.
struct StandardHomeView: View {
    let model: AppModel

    var body: some View {
        HomeView(model: model, showsBedtime: true)
    }
}

#Preview("Standard iPhone") {
    StandardHomeView(model: AppModel(store: InMemoryPetStore(.sample(mood: .hungry, stage: .young)), fold: StaticFoldStateService(.unavailable)))
        .background(RetroBackdrop())
}

#Preview("Standard iPhone, landscape", traits: .landscapeLeft) {
    StandardHomeView(model: AppModel(store: InMemoryPetStore(.sample(mood: .content, stage: .grown)), fold: StaticFoldStateService(.unavailable)))
        .background(RetroBackdrop())
}

#Preview("Standard iPhone, largest text") {
    StandardHomeView(model: AppModel(store: InMemoryPetStore(.sample(mood: .grubby, stage: .elder, name: "Professor Wattlebottom")), fold: StaticFoldStateService(.unavailable)))
        .background(RetroBackdrop())
        .environment(\.dynamicTypeSize, .accessibility5)
}
