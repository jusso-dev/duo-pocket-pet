import PocketPetCore
import SwiftUI

/// Nearby play: pick a pet on the same Wi-Fi or close by, then dance, swap
/// gifts and play Leaf, Pebble, Twig. Also the pals book of every pet met.
struct NearbyView: View {
    let model: AppModel
    let meetup: MeetupController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    private var p: RetroPalette { .current(scheme, contrast) }
    private var petName: String { model.state.name }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MeetupToggle(meetup: meetup)
                    note(MeetupToggle.privacyNote(petName: petName))

                    if meetup.isEnabled {
                        if let friend = meetup.friend {
                            together(with: friend)
                        } else {
                            looking
                        }
                    }

                    if !meetup.pals.pals.isEmpty {
                        palsBook
                    }
                }
                .padding()
            }
            .background(RetroBackdrop())
            .navigationTitle("Nearby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Nothing to confirm here, so it's the system Close button (an
                // X with a "Close" label for VoiceOver), as the HIG asks for sheets.
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .onAppear { model.setNearbyOpen(true) }
        .onDisappear { model.setNearbyOpen(false) }
    }

    // MARK: - Looking

    private var looking: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Pets nearby")
            if let message = meetup.news ?? meetup.status.message(petName: petName) {
                note(message)
            }
            if meetup.nearby.isEmpty {
                note("No pets nearby yet. Both phones need Hingeling open with Meet nearby pets on, on the same Wi-Fi or close together.")
            } else {
                ForEach(meetup.nearby) { pet in
                    HStack(spacing: 12) {
                        if let card = pet.card {
                            PetSpriteView(state: card.sampleState, maxScale: 2)
                                .frame(width: 48, height: 48)
                            VStack(alignment: .leading, spacing: 4) {
                                PixelText(text: card.name, size: 2, colour: p.ink.color)
                                PixelText(text: card.stage.displayName, size: 1, colour: p.inkSoft.color)
                            }
                        } else {
                            PixelText(text: "A pet nearby", size: 2, colour: p.ink.color)
                        }
                        Spacer(minLength: 8)
                        Button { meetup.invite(pet) } label: {
                            KeycapLabel(title: "Hello", icon: .pair)
                        }
                        .buttonStyle(KeycapButtonStyle())
                        .fixedSize()
                        .accessibilityLabel("Say hello to \(pet.card?.name ?? "this pet")")
                    }
                    .lcdPanel(padding: 8)
                }
            }
        }
    }

    // MARK: - Together

    private func together(with friend: PetCard) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 10) {
                HStack(spacing: 16) {
                    PetSpriteView(state: model.state, onStage: meetup.isDancing, maxScale: 5, halo: halo)
                    PetSpriteView(state: friend.sampleState, onStage: meetup.isDancing, maxScale: 5, halo: halo)
                }
                .frame(height: 130)
                PixelText(text: "\(petName) and \(friend.name)", size: 2, colour: p.ink.color, alignment: .centre)
            }
            .lcdPanel()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(petName) is with \(friend.name), a \(friend.stage.displayName.lowercased()) pet who is \(friend.mood.accessibilityDescription)")

            if let news = meetup.news { note(news) }

            heading("Send a gift")
            keyRow {
                ForEach(Gift.allCases, id: \.self) { gift in
                    Button { meetup.send(gift) } label: {
                        KeycapLabel(title: gift.rawValue.capitalized, icon: gift.icon)
                    }
                    .buttonStyle(KeycapButtonStyle())
                    .accessibilityLabel("Send \(gift.phrase)")
                }
            }
            note("Up to \(MeetupLedger.giftsPerPairPerDay) gifts a day from each friend count.")

            heading("Leaf, Pebble, Twig")
            game(friend: friend)

            Button { meetup.leave() } label: {
                KeycapLabel(title: "Goodbye", icon: .sun)
            }
            .buttonStyle(KeycapButtonStyle())
            .accessibilityLabel("Say goodbye to \(friend.name)")
        }
    }

    @ViewBuilder
    private func game(friend: PetCard) -> some View {
        let game = meetup.game
        VStack(alignment: .leading, spacing: 10) {
            switch game.phase {
            case .idle, .finished:
                if case .finished(let won) = game.phase {
                    note(won ? "You won, \(game.myWins) to \(game.theirWins)." : "\(friend.name) won, \(game.theirWins) to \(game.myWins).")
                } else {
                    note("Leaf wraps pebble, pebble snaps twig, twig pokes through leaf. First to two wins.")
                }
                Button { meetup.inviteToGame() } label: {
                    KeycapLabel(title: "Play", icon: .leaf)
                }
                .buttonStyle(KeycapButtonStyle())
                .accessibilityLabel("Play Leaf, Pebble, Twig with \(friend.name)")
            case .invited:
                note("Waiting for \(friend.name) to say yes.")
                Button("Cancel") { meetup.quitGame() }
                    .foregroundStyle(p.backdropInk.color)
            case .askedByPeer:
                note("\(friend.name) wants to play Leaf, Pebble, Twig.")
                HStack(spacing: 8) {
                    Button { meetup.acceptGame() } label: { KeycapLabel(title: "Yes", icon: .leaf) }
                        .buttonStyle(KeycapButtonStyle())
                        .accessibilityLabel("Yes, play")
                    Button { meetup.quitGame() } label: { KeycapLabel(title: "Not now", icon: .moon) }
                        .buttonStyle(KeycapButtonStyle())
                        .accessibilityLabel("Not now")
                }
            case .playing(let round, let mine, _):
                note("Round \(round). You \(game.myWins), \(friend.name) \(game.theirWins).")
                if let last = game.lastRound {
                    note("You picked \(last.mine.title), \(friend.name) picked \(last.theirs.title). " + (last.iWon == nil ? "A tie." : last.iWon == true ? "You take the round." : "\(friend.name) takes the round."))
                }
                if let mine {
                    note("You picked \(mine.title). Waiting for \(friend.name).")
                } else {
                    keyRow {
                        ForEach(GameMove.allCases, id: \.self) { move in
                            Button { meetup.choose(move) } label: {
                                KeycapLabel(title: move.title, icon: move.icon)
                            }
                            .buttonStyle(KeycapButtonStyle())
                            .accessibilityLabel(move.title)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Pals

    private var palsBook: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Pals")
            ForEach(meetup.pals.pals) { pal in
                HStack(spacing: 12) {
                    PetSpriteView(state: pal.card.sampleState, maxScale: 2)
                        .frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 4) {
                        PixelText(text: pal.card.name, size: 2, colour: p.ink.color)
                        Text(palLine(pal))
                            .font(.caption.monospaced())
                            .foregroundStyle(p.inkSoft.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .lcdPanel(padding: 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(pal.card.name). \(palLine(pal))")
            }
        }
    }

    private func palLine(_ pal: PalBook.Pal) -> String {
        let met = pal.timesMet == 1 ? "Met once" : "Met \(pal.timesMet) times"
        let when = pal.lastMet.formatted(.dateTime.day().month(.abbreviated))
        let games = pal.gamesWon + pal.gamesLost > 0 ? ". Games \(pal.gamesWon) to \(pal.gamesLost)" : ""
        return "\(pal.card.stage.displayName). \(met), last on \(when)\(games)."
    }

    // MARK: - Bits

    private var halo: Color? {
        scheme == .dark ? p.inkSoft.color.opacity(0.55) : nil
    }

    /// Keycaps side by side when they fit, stacked when they don't.
    private func keyRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { content() }
            VStack(spacing: 8) { content() }
        }
    }

    private func heading(_ text: String) -> some View {
        PixelText(text: text, size: 2, colour: p.backdropInk.color)
            .accessibilityAddTraits(.isHeader)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.footnote.monospaced())
            .foregroundStyle(p.backdropInk.color.opacity(0.9))
            .fixedSize(horizontal: false, vertical: true)
    }
}
