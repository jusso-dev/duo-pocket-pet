import Foundation

/// What the pet performs on the half-fold stage.
public enum StageRoutine: String, CaseIterable, Sendable {
    /// Too tired (or asleep) for a show, so a slow bow and nothing more.
    case sleepyBow
    /// Hungry, grubby or glum: a half-hearted shuffle.
    case shuffle
    /// The usual routine.
    case dance
    /// Joyful: the routine, and then some.
    case encore

    /// True when the pet should play the stage frames rather than its mood loop.
    public var usesStageFrames: Bool { self != .sleepyBow }

    /// A short line for the stage caption and VoiceOver.
    public func caption(petName: String) -> String {
        switch self {
        case .sleepyBow: "\(petName) is too tired to dance, so takes a sleepy bow."
        case .shuffle: "\(petName) does a little shuffle."
        case .dance: "\(petName) is dancing."
        case .encore: "\(petName) is dancing an encore."
        }
    }
}

/// Whether a cheer landed.
public enum CheerResult: Equatable, Sendable {
    case applied
    /// Cheered too recently. `remaining` is how long until the next cheer counts.
    case coolingDown(remaining: TimeInterval)
    case asleep

    public var wasApplied: Bool { self == .applied }
}

/// Picks the stage routine and rate-limits cheering. Pure: the caller passes the time.
public struct StageShow: Equatable, Sendable {
    /// How long after one cheer the next one counts.
    public static let cheerCooldown: TimeInterval = 30

    /// When the last cheer landed, if any. Not saved: a relaunch resets it.
    public private(set) var lastCheer: Date?

    public init() {}

    /// The routine for the pet as it is now. A tired pet (energy at or below
    /// `Mood.sleepyAt`) bows instead of dancing, whatever else it feels.
    public static func routine(for state: PetState) -> StageRoutine {
        if state.isAsleep || state.energy <= Mood.sleepyAt { return .sleepyBow }
        switch state.mood {
        case .hungry, .grubby, .glum: return .shuffle
        case .joyful: return .encore
        case .asleep, .sleepy: return .sleepyBow
        case .content: return .dance
        }
    }

    /// Seconds until a cheer counts again, or 0 when it would count now.
    public func cooldownRemaining(at now: Date) -> TimeInterval {
        guard let lastCheer else { return 0 }
        let elapsed = now.timeIntervalSince(lastCheer)
        // A clock that went backwards doesn't lock cheering out for longer than one cooldown.
        if elapsed < 0 { return 0 }
        return max(0, Self.cheerCooldown - elapsed)
    }

    /// Cheers for the pet, raising its happiness, at most once per `cheerCooldown`.
    public mutating func cheer(_ engine: inout PetEngine, at now: Date) -> CheerResult {
        let remaining = cooldownRemaining(at: now)
        if remaining > 0 { return .coolingDown(remaining: remaining) }
        switch engine.cheer(at: now) {
        case .applied:
            lastCheer = now
            return .applied
        case .refused:
            return .asleep
        }
    }
}

/// The stage spotlight follows the hinge, as Apple advises: hinge data for live effects.
public enum StageLighting {
    /// Tilt of the spotlight in degrees, from -40 (phone nearly shut) through 0
    /// (90 degree hinge, like a laptop) to 40 (nearly flat).
    public static func spotlightTilt(hingeDegrees: Double) -> Double {
        let hinge = hingeDegrees.isFinite ? min(180, max(0, hingeDegrees)) : 90
        return (hinge - 90) / 90 * 40
    }

    /// How bright the spotlight is, from 0.4 to 1. Brightest at 90 degrees,
    /// when the stage stands up like a laptop screen.
    public static func spotlightIntensity(hingeDegrees: Double) -> Double {
        let hinge = hingeDegrees.isFinite ? min(180, max(0, hingeDegrees)) : 90
        return 1 - 0.6 * abs(hinge - 90) / 90
    }
}
