import PocketPetCore
import SwiftUI

/// Picks the scene for the current fold posture.
///
/// A closed iPhone Duo behaves like a compact iPhone, so the glance is simply
/// the compact layout shown while the posture is `.closed`. There is no
/// separate outer-display API involved.
struct RootView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
            .animation(.snappy, value: model.scene)
            .task { await model.run() }
            .modifier(OptionalHingeReader(service: model.hinge))
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { model.becameActive() } else { model.enteredBackground() }
            }
    }

    @ViewBuilder private var content: some View {
        switch model.scene {
        case .glance:
            GlanceView(state: model.state)
        case .home:
            HomeView(model: model)
        case .stage(let angle):
            StageSlot(state: model.state, angleDegrees: angle)
        case .standard:
            StandardHomeView(model: model)
        }
    }
}

private struct OptionalHingeReader: ViewModifier {
    let service: HingeFoldStateService?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let service {
            content.readsHinge(into: service)
        } else {
            content
        }
    }
}
