/// The words the glance view shows and reads out, kept free of UI code so they
/// can be tested on any platform.
public struct GlanceContent: Equatable, Sendable {
    public let name: String
    /// For example "Young".
    public let stageLabel: String
    /// For example "Asleep" or "In need of a clean".
    public let moodLine: String
    /// The single VoiceOver label, for example "Bip is asleep".
    public let accessibilityLabel: String
    /// Read after the label, for example "Young. Needs you".
    public let accessibilityValue: String
    public let needsAttention: Bool

    public init(state: PetState) {
        let mood = state.mood
        name = state.name
        stageLabel = state.lifeStage.displayName
        moodLine = mood.accessibilityDescription.prefix(1).uppercased() + mood.accessibilityDescription.dropFirst()
        accessibilityLabel = "\(state.name) is \(mood.accessibilityDescription)"
        needsAttention = mood.needsAttention
        accessibilityValue = needsAttention ? "\(stageLabel). Needs you" : stageLabel
    }
}

extension LifeStage {
    /// Title-case name for display.
    public var displayName: String {
        switch self {
        case .newborn: "Newborn"
        case .young: "Young"
        case .grown: "Grown"
        case .elder: "Elder"
        }
    }
}
