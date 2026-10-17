import Foundation

/// Launch arguments for UI tests, screenshots and demos on the simulator.
/// The app only reads these in simulator builds.
///
/// - `-mockFold`: play `MockFoldStateService.demoScript`.
/// - `-fold closed|open|unavailable|half` or `-fold half:120`: start in that posture and stay there.
/// - `-fastRules`: needs change an hour's worth every 10 seconds, and reminders
///   can fire 10 seconds out, for checking notifications by hand.
/// - `-pet <mood>,<stage>[,<name>]`: a sample pet in memory, for example `-pet hungry,young`.
///   Nothing is read from or written to disk.
public struct DebugLaunchOptions: Equatable, Sendable {
    public var playsDemoScript = false
    public var fold: FoldPosture?
    public var pet: PetState?
    public var fastRules = false

    /// The rules to run with: standard, or 360 times faster with `-fastRules`.
    public var rules: PetRules { fastRules ? PetRules.standard.speeded(by: 360) : .standard }

    public init() {}

    public init(arguments: [String], now: Date) {
        var i = arguments.startIndex
        while i < arguments.endIndex {
            let arg = arguments[i]
            let next = arguments.index(after: i) < arguments.endIndex ? arguments[arguments.index(after: i)] : nil
            switch arg {
            case "-mockFold":
                playsDemoScript = true
            case "-fastRules":
                fastRules = true
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
    public var isActive: Bool { playsDemoScript || fold != nil || pet != nil || fastRules }

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

extension PetRules {
    /// The same rules with every per-hour rate multiplied by `factor`, for demos and manual tests.
    public func speeded(by factor: Double) -> PetRules {
        func scale(_ r: Rates) -> Rates {
            Rates(
                hungerGainPerHour: r.hungerGainPerHour * factor,
                happinessLossPerHour: r.happinessLossPerHour * factor,
                energyChangePerHour: r.energyChangePerHour * factor,
                hygieneLossPerHour: r.hygieneLossPerHour * factor
            )
        }
        var rules = self
        rules.awake = scale(awake)
        rules.asleep = scale(asleep)
        rules.neglectHappinessLossPerHour *= factor
        rules.integrationStep = max(1, integrationStep / factor)
        return rules
    }
}
