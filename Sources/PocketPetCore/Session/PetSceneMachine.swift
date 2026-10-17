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

/// Side effects a posture change asks for.
public enum SceneEffect: Equatable, Sendable {
    case putToSleep
    case wakeUp
}

/// Maps fold postures to scenes. Closing tucks the pet in, opening wakes it.
/// Pure and synchronous, so every transition is unit tested.
public struct PetSceneMachine: Sendable {
    public private(set) var scene: PetScene?

    public init() {}

    /// Handles a new posture and returns the effects to apply, in order.
    /// The first call (launch) also returns effects, so launching closed starts asleep.
    public mutating func handle(_ posture: FoldPosture) -> [SceneEffect] {
        let previous = scene
        let next = PetSceneMachine.scene(for: posture)
        scene = next

        switch (previous, next) {
        case (.glance?, .glance): return []
        case (_, .glance): return [.putToSleep]
        case (_, .standard): return []
        case (.glance?, _), (nil, _): return [.wakeUp]
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
