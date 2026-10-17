import PocketPetCore
import SwiftUI

/// A compact meetup line for the stage and the home screen: the opt-in switch
/// (stage only), what's happening, and a way into the Nearby screen.
struct MeetupPanel: View {
    let meetup: MeetupController
    let petName: String
    /// Show the opt-in switch here. The home screen keeps it in the Nearby screen.
    var showsToggle = true
    var openNearby: (() -> Void)?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let p = RetroPalette.current(scheme, contrast)
        VStack(alignment: .leading, spacing: 8) {
            if showsToggle {
                MeetupToggle(meetup: meetup)
                if !meetup.isEnabled {
                    Text(MeetupToggle.privacyNote(petName: petName))
                        .font(.footnote.monospaced())
                        .foregroundStyle(p.backdropInk.color.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if meetup.isEnabled, let message = meetup.news ?? meetup.status.message(petName: petName) {
                Text(message)
                    .font(.footnote.monospaced())
                    .foregroundStyle(p.backdropInk.color.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let openNearby, meetup.friend != nil {
                Button(action: openNearby) {
                    KeycapLabel(title: "Gifts and games", icon: .pair)
                }
                .buttonStyle(KeycapButtonStyle())
                .accessibilityLabel("Gifts and games")
                .accessibilityHint("Opens the Nearby screen to send gifts and play with your friend")
            }
        }
    }
}

/// The opt-in switch for nearby play.
struct MeetupToggle: View {
    let meetup: MeetupController
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    static func privacyNote(petName: String) -> String {
        "Finds other Hingeling pets on the same Wi-Fi or close by. Only \(petName)'s name, life stage and mood are shared, and only while this is on."
    }

    var body: some View {
        let p = RetroPalette.current(scheme, contrast)
        Toggle(isOn: Binding(get: { meetup.isEnabled }, set: { meetup.setEnabled($0) })) {
            HStack(spacing: 8) {
                PixelIconView(icon: .pair, scale: 2, colour: p.backdropInk.color)
                Text("Meet nearby pets").font(.subheadline.monospaced().bold())
            }
        }
        .tint(p.bezelHighlight.color)
        .foregroundStyle(p.backdropInk.color)
        .accessibilityLabel("Meet nearby pets")
        .accessibilityHint("Looks for other Hingeling pets nearby. Your phone will ask for local network access the first time.")
    }
}

extension MeetupController.Status {
    /// The visiting pet, while together.
    var friend: PetCard? {
        if case .together(let friend) = self { return friend }
        return nil
    }
}

extension PetCard {
    /// A pet state that draws this card's pet. Only for showing a visitor.
    var sampleState: PetState { .sample(mood: mood, stage: stage, name: name) }
}
