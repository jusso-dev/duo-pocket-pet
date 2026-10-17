import Foundation

/// Picks which frame to show. Pure and clock-free: the caller passes the time,
/// so previews, tests and the SwiftUI timeline all agree.
public struct PetAnimator: Equatable, Sendable {
    /// Seconds per frame for looping poses.
    public static let loopFrameDuration: TimeInterval = 0.5
    /// Seconds per frame for one-shot reactions.
    public static let reactionFrameDuration: TimeInterval = 0.18
    /// Seconds per frame while asleep. The sleeping pet sits on the closed
    /// outer screen for hours, so its two-frame snore turns over slowly.
    public static let asleepFrameDuration: TimeInterval = 2.0
    /// Redraw interval when nothing can change, such as under Reduce Motion.
    public static let stillTickInterval: TimeInterval = 3600

    public var stage: LifeStage
    public var mood: Mood
    /// True while the half-fold stage scene is showing.
    public var onStage: Bool
    /// The reaction playing and when it started, if any.
    public private(set) var reaction: (kind: PetReaction, startedAt: Date)?

    public init(stage: LifeStage, mood: Mood, onStage: Bool = false) {
        self.stage = stage
        self.mood = mood
        self.onStage = onStage
    }

    public init(state: PetState, onStage: Bool = false) {
        self.init(stage: state.lifeStage, mood: state.mood, onStage: onStage)
    }

    public static func == (lhs: PetAnimator, rhs: PetAnimator) -> Bool {
        lhs.stage == rhs.stage && lhs.mood == rhs.mood && lhs.onStage == rhs.onStage
            && lhs.reaction?.kind == rhs.reaction?.kind && lhs.reaction?.startedAt == rhs.reaction?.startedAt
    }

    /// Starts a one-shot reaction, replacing any that is playing.
    public mutating func play(_ reaction: PetReaction, at now: Date) {
        self.reaction = (reaction, now)
    }

    /// How long a reaction runs before the loop resumes.
    public static func duration(of reaction: PetReaction, stage: LifeStage) -> TimeInterval {
        Double(PetSprites.frames(for: .reaction(reaction), stage: stage).count) * reactionFrameDuration
    }

    /// The pose to show at `now`. A finished reaction falls back to the loop.
    public func pose(at now: Date) -> PetPose {
        if let reaction, now.timeIntervalSince(reaction.startedAt) < Self.duration(of: reaction.kind, stage: stage) {
            return .reaction(reaction.kind)
        }
        if onStage, mood != .asleep { return .stage }
        return .mood(mood)
    }

    /// The frame to draw at `now`. With `reduceMotion`, holds the first frame of
    /// the current pose and skips reactions.
    public func frame(at now: Date, reduceMotion: Bool = false) -> PixelFrame {
        if reduceMotion {
            let still: PetPose = (onStage && mood != .asleep) ? .stage : .mood(mood)
            return PetSprites.frames(for: still, stage: stage)[0]
        }
        let pose = pose(at: now)
        let frames = PetSprites.frames(for: pose, stage: stage)
        switch pose {
        case .reaction:
            let elapsed = max(0, now.timeIntervalSince(reaction?.startedAt ?? now))
            let index = min(frames.count - 1, Int(elapsed / Self.reactionFrameDuration))
            return frames[index]
        case .mood, .stage:
            let ticks = Int(floor(now.timeIntervalSinceReferenceDate / Self.loopDuration(for: pose)))
            let index = ((ticks % frames.count) + frames.count) % frames.count
            return frames[index]
        }
    }

    /// Seconds per frame for a looping pose.
    public static func loopDuration(for pose: PetPose) -> TimeInterval {
        pose == .mood(.asleep) ? asleepFrameDuration : loopFrameDuration
    }

    /// How often a view should redraw at `now`: only as often as the frame can
    /// change. Reactions tick fast, a sleeping pet slowly, and Reduce Motion
    /// barely at all.
    public func tickInterval(at now: Date, reduceMotion: Bool = false) -> TimeInterval {
        if reduceMotion { return Self.stillTickInterval }
        let pose = pose(at: now)
        if case .reaction = pose { return Self.reactionFrameDuration }
        return Self.loopDuration(for: pose)
    }
}
