import PocketPetCore
import SwiftUI

/// The opt-in switch for meetups, what's happening now, and the friend when one visits.
struct MeetupPanel: View {
    let meetup: MeetupController
    let petName: String
    /// Show the visiting pet's sprite here. The stage draws it on the stage instead.
    var showsFriend = true
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = RetroPalette.current(scheme)
        VStack(alignment: .leading, spacing: 6) {
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
            if !meetup.isEnabled {
                Text("Only \(petName)'s name, life stage and mood are shared, and only while this is on.")
                    .font(.footnote.monospaced())
                    .foregroundStyle(p.backdropInk.color.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            } else if let message = meetup.status.message(petName: petName) {
                HStack(spacing: 8) {
                    if showsFriend, let friend = meetup.status.friend {
                        PetSpriteView(state: .sample(mood: friend.mood, stage: friend.stage, name: friend.name), maxScale: 2)
                            .frame(width: 48, height: 48)
                    }
                    Text(message)
                        .font(.footnote.monospaced())
                        .foregroundStyle(p.backdropInk.color.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

extension MeetupController.Status {
    /// The visiting pet while playing or just after.
    var friend: PetCard? {
        switch self {
        case .playing(let friend), .finished(let friend, _): friend
        default: nil
        }
    }
}
