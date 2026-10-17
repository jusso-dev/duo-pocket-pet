import PocketPetCore
import SwiftUI

/// Every iPhone without a hinge: the home screen with a Bedtime or Wake button
/// standing in for closing the phone, and the meetup switch.
struct StandardHomeView: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HomeView(model: model, showsBedtime: true)
            if let meetup = model.meetup {
                MeetupPanel(meetup: meetup, petName: model.state.name)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
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
