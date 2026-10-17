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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .background(RetroBackdrop())
            // Key on the kind, so a folding hinge doesn't restart the animation
            // every 2 degrees, and skip it entirely with Reduce Motion on.
            .animation(reduceMotion ? nil : .snappy, value: model.scene.kind)
            .task { await model.run() }
            .modifier(OptionalHingeReader(service: model.hinge))
            .safeAreaInset(edge: .top) {
                // Not on the glance: it is the whole outer screen while closed.
                if model.scene != .glance, let notice = model.storageNotice {
                    StorageNoticeBanner(text: notice, onDismiss: model.dismissStorageNotice)
                }
            }
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
            StageView(model: model, angleDegrees: angle)
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

/// A small banner for save problems, so the player knows when progress won't be kept.
private struct StorageNoticeBanner: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)
            Text(text)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}
