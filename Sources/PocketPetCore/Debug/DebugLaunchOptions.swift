import Foundation

/// Launch arguments for UI tests, screenshots and demos on the simulator.
/// The app only reads these in simulator builds.
///
/// - `-mockFold`: play `MockFoldStateService.demoScript`.
/// - `-fold closed|open|unavailable|half` or `-fold half:120`: start in that posture and stay there.
/// - `-pet <mood>,<stage>[,<name>]`: a sample pet in memory, for example `-pet hungry,young`.
///   Nothing is read from or written to disk.
public struct DebugLaunchOptions: Equatable, Sendable {
    public var playsDemoScript = false
    public var fold: FoldPosture?
    public var pet: PetState?

    public init() {}

    public init(arguments: [String], now: Date) {
        var i = arguments.startIndex
        while i < arguments.endIndex {
            let arg = arguments[i]
            let next = arguments.index(after: i) < arguments.endIndex ? arguments[arguments.index(after: i)] : nil
            switch arg {
            case "-mockFold":
                playsDemoScript = true
            case "-fold":
                if let next { fold = Self.posture(next) }
            case "-pet":
                if let next { pet = Self.pet(next, now: now) }
            default:
                break
            }
            i = arguments.index(after: i)
        }
    }

    /// True when any option is set, so the app should use these instead of the live services.
    public var isActive: Bool { playsDemoScript || fold != nil || pet != nil }

    static func posture(_ text: String) -> FoldPosture? {
        let parts = text.lowercased().split(separator: ":", maxSplits: 1).map(String.init)
        switch parts.first {
        case "closed": return .closed
        case "open": return .open
        case "unavailable", "none": return .unavailable
        case "half":
            let angle = parts.count > 1 ? Double(parts[1]) : nil
            return .partiallyOpen(angleDegrees: min(180, max(0, angle ?? 100)))
        default: return nil
        }
    }

    static func pet(_ text: String, now: Date) -> PetState? {
        let parts = text.split(separator: ",", maxSplits: 2).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2, let mood = Mood(rawValue: parts[0]), let stage = LifeStage(rawValue: parts[1]) else { return nil }
        let name = parts.count > 2 && !parts[2].isEmpty ? parts[2] : "Bip"
        return .sample(mood: mood, stage: stage, name: name, at: now)
    }
}
