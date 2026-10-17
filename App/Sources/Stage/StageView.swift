import PocketPetCore
import SwiftUI

/// Half folded: a small stage on one side of the fold and a cheer button on
/// the other. The spotlight tilts and dims with the hinge angle.
struct StageView: View {
    let model: AppModel
    let angleDegrees: Double
    @State private var cheerMessage: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var routine: StageRoutine { model.session.stageRoutine }

    var body: some View {
        FoldAwareSplit { _ in
            stage
        } second: { _ in
            audience
        } fallback: {
            VStack(spacing: 0) {
                stage
                audience
                    .frame(maxHeight: 180)
            }
        }
    }

    private var stage: some View {
        ZStack {
            Color.black.opacity(0.85)
            Spotlight(
                tilt: reduceMotion ? 0 : StageLighting.spotlightTilt(hingeDegrees: angleDegrees),
                intensity: StageLighting.spotlightIntensity(hingeDegrees: angleDegrees)
            )
            VStack(spacing: 12) {
                PetSpriteView(state: model.state, onStage: routine.usesStageFrames, maxScale: 10)
                Text(routine.caption(petName: model.state.name))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(routine.caption(petName: model.state.name))
        .accessibilityIdentifier("stage")
    }

    private var audience: some View {
        VStack(spacing: 12) {
            Button("Cheer", systemImage: "hands.clap") { cheer() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityHint("Cheers for \(model.state.name). Raises happiness, once every 30 seconds.")
            if let cheerMessage {
                Text(cheerMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cheer() {
        let message = model.cheer().message(petName: model.state.name)
        cheerMessage = message
        AccessibilityNotification.Announcement(message).post()
    }
}

/// A soft cone of light from above, tilted by the hinge.
private struct Spotlight: View {
    let tilt: Double
    let intensity: Double

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            Path { path in
                path.move(to: CGPoint(x: w / 2 - 12, y: 0))
                path.addLine(to: CGPoint(x: w / 2 + 12, y: 0))
                path.addLine(to: CGPoint(x: w / 2 + w * 0.35, y: h))
                path.addLine(to: CGPoint(x: w / 2 - w * 0.35, y: h))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [Color.yellow.opacity(0.55 * intensity), Color.yellow.opacity(0.08 * intensity)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .rotationEffect(.degrees(tilt), anchor: .top)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

extension CheerResult {
    /// Kind, short feedback for the cheer button.
    func message(petName: String) -> String {
        switch self {
        case .applied:
            return "\(petName) loved that."
        case .coolingDown(let remaining):
            let seconds = Int(remaining.rounded(.up))
            return "\(petName) is still bowing. Cheer again in \(seconds) seconds."
        case .asleep:
            return "\(petName) is asleep. Let them rest."
        }
    }
}

#Preview("Stage") {
    StageView(
        model: AppModel(store: InMemoryPetStore(.sample(mood: .content, stage: .grown)), fold: MockFoldStateService(initial: .partiallyOpen(angleDegrees: 110))),
        angleDegrees: 110
    )
}

#Preview("Tired pet bows") {
    StageView(
        model: AppModel(store: InMemoryPetStore(.sample(mood: .sleepy, stage: .young)), fold: MockFoldStateService(initial: .partiallyOpen(angleDegrees: 90))),
        angleDegrees: 90
    )
}
