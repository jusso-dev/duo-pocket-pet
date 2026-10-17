import PocketPetCore
import SwiftUI

/// Half folded: a small stage on one side of the fold and a cheer button on
/// the other. The spotlight tilts and dims with the hinge angle.
struct StageView: View {
    let model: AppModel
    let angleDegrees: Double
    @State private var cheerMessage: String?
    @State private var showingNearby = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    private var routine: StageRoutine { model.session.stageRoutine }

    var body: some View {
        layout
            .sheet(isPresented: $showingNearby) {
                if let meetup = model.meetup {
                    NearbyView(model: model, meetup: meetup)
                }
            }
    }

    private var layout: some View {
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
        let p = RetroPalette.current(scheme)
        return ZStack {
            Curtains(colour: p.bezelHighlight.color)
            Spotlight(
                tilt: reduceMotion ? 0 : StageLighting.spotlightTilt(hingeDegrees: angleDegrees),
                intensity: StageLighting.spotlightIntensity(hingeDegrees: angleDegrees),
                colour: p.lcdGhost.color
            )
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    PetSpriteView(state: model.state, onStage: routine.usesStageFrames, maxScale: 10, halo: halo)
                    if let friend = model.meetup?.friend {
                        // A visiting pet dances alongside.
                        PetSpriteView(state: .sample(mood: friend.mood, stage: friend.stage, name: friend.name), onStage: true, maxScale: 10, halo: halo)
                    }
                }
                PixelText(text: routine.caption(petName: model.state.name), size: 2, colour: p.ink.color, alignment: .centre)
            }
            .padding(.horizontal, 36)
            .padding(.vertical)
        }
        .lcdPanel(padding: 0)
        .padding()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(routine.caption(petName: model.state.name))
        .accessibilityIdentifier("stage")
    }

    private var halo: Color? {
        scheme == .dark ? RetroPalette.backlight.inkSoft.color.opacity(0.55) : nil
    }

    private var audience: some View {
        let p = RetroPalette.current(scheme)
        return VStack(spacing: 12) {
            Button { cheer() } label: {
                KeycapLabel(title: "Cheer", icon: .burst)
            }
            .buttonStyle(KeycapButtonStyle())
            .frame(maxWidth: 240)
            .accessibilityLabel("Cheer")
            .accessibilityHint("Cheers for \(model.state.name). Raises happiness, once every 30 seconds.")
            if let cheerMessage {
                Text(cheerMessage)
                    .font(.callout.monospaced())
                    .foregroundStyle(p.backdropInk.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let meetup = model.meetup {
                MeetupPanel(meetup: meetup, petName: model.state.name) { showingNearby = true }
                    .frame(maxWidth: 420)
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

/// A dithered cone of light from above, tilted by the hinge. Every other
/// pixel is lit, like light on an old LCD.
private struct Spotlight: View {
    let tilt: Double
    let intensity: Double
    let colour: Color

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let w = size.width, h = size.height
            var path = Path()
            var y: CGFloat = 0
            while y < h {
                let half = 10 + (y / h) * w * 0.32
                var x = (w / 2 - half).rounded(.down)
                while x < w / 2 + half {
                    if (Int(x / 4) + Int(y / 4)) % 2 == 0 {
                        path.addRect(CGRect(x: x, y: y, width: 3, height: 3))
                    }
                    x += 4
                }
                y += 4
            }
            context.fill(path, with: .color(colour.opacity(0.4 + 0.6 * intensity)))
        }
        .rotationEffect(.degrees(tilt), anchor: .top)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// Pleated pixel curtains down both sides of the stage.
private struct Curtains: View {
    let colour: Color

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let curtain = min(36, size.width * 0.12)
            var path = Path()
            for side in [0, 1] {
                var x: CGFloat = 0
                while x < curtain {
                    // Pleats: a lit stripe every 6 pixels, wider at the hem.
                    path.addRect(CGRect(x: side == 0 ? x : size.width - x - 3, y: 0, width: 3, height: size.height))
                    x += 6
                }
            }
            context.fill(path, with: .color(colour))
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
