/// Which screen the app shows.
public enum PetScene: Equatable, Sendable {
    /// Closed: the outer-screen glance.
    case glance
    /// Fully open: the pet's home on the inner screen.
    case home
    /// Half folded: the small stage.
    case stage(angleDegrees: Double)
    /// No hinge: the standard iPhone layout with a bedtime button.
    case standard
}

extension PetScene {
    /// The scene without its angle. Two half-fold scenes at different angles
    /// are the same kind, so animations and saves key on this, not on every degree.
    public enum Kind: Equatable, Hashable, Sendable {
        case glance, home, stage, standard
    }

    public var kind: Kind {
        switch self {
        case .glance: .glance
        case .home: .home
        case .stage: .stage
        case .standard: .standard
        }
    }
}

/// Side effects a posture change asks for.
public enum SceneEffect: Equatable, Sendable {
    case putToSleep
    case wakeUp
}

/// Maps fold postures to scenes. Closing tucks the pet in, opening wakes it.
/// Pure and synchronous, so every transition is unit tested.
///
/// `.standard` means "no hinge reading", which is what the live hinge service
/// reports at launch until the first `onHingeChange` callback, and what a
/// standard iPhone reports for good. Arriving in `.standard` from launch or
/// from the glance counts as an open, and the first real open or half fold
/// after `.standard` counts as an open too, because it is the first fold
/// reading the machine has seen.
///
/// Once closed, a half-fold reading under `reopenThresholdDegrees` still counts
/// as closed. A hinge settling at 1 or 2 degrees after it shuts, or a phone
/// squeezed in a pocket, must not wake the pet or swap the glance for the stage.
public struct PetSceneMachine: Sendable {
    /// How far a closed phone has to open before it counts as opened.
    public static let reopenThresholdDegrees: Double = 20

    public private(set) var scene: PetScene?

    public init() {}

    /// Handles a new posture and returns the effects to apply, in order.
    /// The first call (launch) also returns effects, so launching closed starts
    /// asleep and launching open, half folded or with no hinge reading wakes.
    public mutating func handle(_ posture: FoldPosture) -> [SceneEffect] {
        let previous = scene
        if previous == .glance, case .partiallyOpen(let angle) = posture, angle < PetSceneMachine.reopenThresholdDegrees {
            // Still closed for our purposes: a settle or a squeeze, not a reopen.
            return []
        }
        let next = PetSceneMachine.scene(for: posture)
        scene = next

        switch (previous, next) {
        case (.glance?, .glance): return []
        case (_, .glance): return [.putToSleep]
        case (.standard?, .standard): return []
        // Launch, or leaving the glance, or the first fold reading after
        // "no hinge reading": all of these are an open.
        case (nil, _), (.glance?, _), (.standard?, _): return [.wakeUp]
        // Moving between home and the half fold keeps the pet as it is.
        default: return []
        }
    }

    public static func scene(for posture: FoldPosture) -> PetScene {
        switch posture {
        case .closed: .glance
        case .open: .home
        case .partiallyOpen(let angle): .stage(angleDegrees: angle)
        case .unavailable: .standard
        }
    }
}
