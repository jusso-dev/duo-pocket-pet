import Foundation

extension PetState {
    /// A pet in a given mood and life stage, for previews, snapshots and tests.
    public static func sample(
        mood: Mood,
        stage: LifeStage,
        name: String = "Bip",
        at date: Date = Date(timeIntervalSinceReferenceDate: 800_000_000)
    ) -> PetState {
        let age: TimeInterval = switch stage {
        case .newborn: 3600
        case .young: LifeStage.youngAfter + 3600
        case .grown: LifeStage.grownAfter + 3600
        case .elder: LifeStage.elderAfter + 3600
        }
        var state = PetState(name: name, hunger: 0.2, happiness: 0.6, energy: 0.8, hygiene: 1.0, ageSeconds: age, bornAt: date.addingTimeInterval(-age), lastUpdated: date)
        switch mood {
        case .asleep: state.isAsleep = true
        case .hungry: state.hunger = 0.9
        case .grubby: state.hygiene = 0.1
        case .sleepy: state.energy = 0.1
        case .glum: state.happiness = 0.1
        case .content: break
        case .joyful: state.happiness = 0.95
        }
        return state
    }
}
