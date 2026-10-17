import PocketPetCore
import SwiftUI

/// The pet's home: the pet, its needs, and Feed, Clean and Play.
struct HomeView: View {
    let model: AppModel
    var showsBedtime = false

    var body: some View {
        VStack(spacing: 24) {
            PetSpriteSlot(state: model.state)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text("\(model.state.name) is \(model.state.mood.accessibilityDescription)")
                .font(.headline)

            NeedsPanel(state: model.state)

            if let refusal = model.lastRefusal {
                Text(refusal.message(petName: model.state.name))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            HStack(spacing: 12) {
                ActionButton(title: "Feed", systemImage: "fork.knife", hint: "Lowers hunger") { _ = model.perform(.feed) }
                ActionButton(title: "Clean", systemImage: "sparkles", hint: "Restores cleanliness") { _ = model.perform(.clean) }
                ActionButton(title: "Play", systemImage: "figure.play", hint: "Raises happiness, uses energy") { _ = model.perform(.play) }
                if showsBedtime {
                    if model.state.isAsleep {
                        ActionButton(title: "Wake", systemImage: "sun.max", hint: "Wakes your pet") { _ = model.perform(.wake) }
                    } else {
                        ActionButton(title: "Bedtime", systemImage: "moon.zzz", hint: "Puts your pet to sleep") { _ = model.perform(.sleep) }
                    }
                }
            }
        }
        .padding()
    }
}

struct NeedsPanel: View {
    let state: PetState

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            NeedRow(label: "Fullness", value: 1 - state.hunger)
            NeedRow(label: "Happiness", value: state.happiness)
            NeedRow(label: "Energy", value: state.energy)
            NeedRow(label: "Cleanliness", value: state.hygiene)
        }
    }
}

private struct NeedRow: View {
    let label: String
    let value: Double

    var body: some View {
        GridRow {
            Text(label)
            ProgressView(value: value)
                .frame(minWidth: 120)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
    }
}

private struct ActionButton: View {
    let title: String
    let systemImage: String
    let hint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityHint(hint)
    }
}
