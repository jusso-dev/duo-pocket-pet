import PocketPetCore
import SwiftUI

/// The pet's home: the pet, its needs, and Feed, Clean and Play.
///
/// At accessibility text sizes the screen scrolls and the buttons stack, so
/// nothing truncates or clips off a compact screen.
struct HomeView: View {
    let model: AppModel
    var showsBedtime = false
    @State private var reaction: PetReactionCue?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView {
                content(spriteHeight: 160)
            }
        } else {
            content(spriteHeight: nil)
        }
    }

    private func content(spriteHeight: CGFloat?) -> some View {
        VStack(spacing: 24) {
            PetSpriteView(state: model.state, reaction: reaction)
                .frame(maxWidth: .infinity, maxHeight: spriteHeight ?? .infinity)
                .frame(height: spriteHeight)

            Text("\(model.state.name) is \(model.state.mood.accessibilityDescription)")
                .font(.headline)
                .multilineTextAlignment(.center)

            NeedsPanel(state: model.state)

            if let refusal = model.lastRefusal {
                Text(refusal.message(petName: model.state.name))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            ActionRow(buttons: buttons, dynamicTypeSize: dynamicTypeSize)
        }
        .padding()
    }

    private var buttons: [ActionRow.Item] {
        var items: [ActionRow.Item] = [
            .init(title: "Feed", systemImage: "fork.knife", hint: "Lowers hunger") { perform(.feed, reaction: .feed) },
            .init(title: "Clean", systemImage: "sparkles", hint: "Restores cleanliness") { perform(.clean, reaction: .clean) },
            .init(title: "Play", systemImage: "figure.play", hint: "Raises happiness, uses energy") { perform(.play, reaction: .play) },
        ]
        if showsBedtime {
            if model.state.isAsleep {
                items.append(.init(title: "Wake", systemImage: "sun.max", hint: "Wakes your pet") { perform(.wake, reaction: nil) })
            } else {
                items.append(.init(title: "Bedtime", systemImage: "moon.zzz", hint: "Puts your pet to sleep") { perform(.sleep, reaction: nil) })
            }
        }
        return items
    }

    private func perform(_ action: PetAction, reaction kind: PetReaction?) {
        let result = model.perform(action)
        if result == .applied, let kind {
            reaction = PetReactionCue(reaction: kind, startedAt: .now)
        }
        // VoiceOver users hear the outcome, applied or refused.
        AccessibilityNotification.Announcement(result.announcement(for: action, petName: model.state.name)).post()
    }
}

/// Feed, Clean, Play and, without a hinge, Bedtime or Wake.
///
/// In a row when the labels fit, otherwise stacked. At accessibility sizes it
/// always stacks, because four labels can't share a compact screen's width.
struct ActionRow: View {
    struct Item: Identifiable {
        let title: String
        let systemImage: String
        let hint: String
        let action: () -> Void
        var id: String { title }
    }

    let buttons: [Item]
    let dynamicTypeSize: DynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            column
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { ForEach(buttons) { ActionButton(item: $0) } }
                column
            }
        }
    }

    private var column: some View {
        VStack(spacing: 12) { ForEach(buttons) { ActionButton(item: $0) } }
    }
}

struct NeedsPanel: View {
    let state: PetState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            // Label above bar, so long labels don't squeeze the bars off screen.
            VStack(alignment: .leading, spacing: 12) {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.label)
                        ProgressView(value: row.value)
                    }
                    .needAccessibility(label: row.label, value: row.value)
                }
            }
        } else {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                ForEach(rows) { row in
                    GridRow {
                        Text(row.label)
                        ProgressView(value: row.value)
                            .frame(minWidth: 120)
                    }
                    .needAccessibility(label: row.label, value: row.value)
                }
            }
        }
    }

    private struct Row: Identifiable {
        let label: String
        let value: Double
        var id: String { label }
    }

    private var rows: [Row] {
        [
            Row(label: "Fullness", value: 1 - state.hunger),
            Row(label: "Happiness", value: state.happiness),
            Row(label: "Energy", value: state.energy),
            Row(label: "Cleanliness", value: state.hygiene),
        ]
    }
}

private extension View {
    func needAccessibility(label: String, value: Double) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue("\(Int((value * 100).rounded())) percent")
    }
}

private struct ActionButton: View {
    let item: ActionRow.Item

    var body: some View {
        Button(action: item.action) {
            Label(item.title, systemImage: item.systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityHint(item.hint)
    }
}
