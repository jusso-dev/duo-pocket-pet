import Foundation
import Testing
@testable import PocketPetCore

@Suite("Redraw rate")
struct PetTickTests {
    let now = Date(timeIntervalSinceReferenceDate: 10_000)

    @Test func asleepTicksSlowerThanAwake() {
        let asleep = PetAnimator(stage: .young, mood: .asleep)
        let awake = PetAnimator(stage: .young, mood: .content)
        #expect(asleep.tickInterval(at: now) == PetAnimator.asleepFrameDuration)
        #expect(awake.tickInterval(at: now) == PetAnimator.loopFrameDuration)
        #expect(asleep.tickInterval(at: now) > awake.tickInterval(at: now))
    }

    @Test func asleepOnStageStillTicksSlowly() {
        // Asleep never shows the stage routine, so it keeps the slow rate.
        let animator = PetAnimator(stage: .grown, mood: .asleep, onStage: true)
        #expect(animator.tickInterval(at: now) == PetAnimator.asleepFrameDuration)
    }

    @Test func reactionTicksFastThenFallsBack() {
        var animator = PetAnimator(stage: .young, mood: .content)
        animator.play(.feed, at: now)
        #expect(animator.tickInterval(at: now) == PetAnimator.reactionFrameDuration)
        let after = now.addingTimeInterval(PetAnimator.duration(of: .feed, stage: .young) + 0.01)
        #expect(animator.tickInterval(at: after) == PetAnimator.loopFrameDuration)
    }

    @Test func reduceMotionBarelyTicks() {
        var animator = PetAnimator(stage: .young, mood: .asleep)
        animator.play(.play, at: now)
        #expect(animator.tickInterval(at: now, reduceMotion: true) == PetAnimator.stillTickInterval)
    }

    @Test func asleepFrameHoldsForItsWholeInterval() {
        let animator = PetAnimator(stage: .young, mood: .asleep)
        let start = Date(timeIntervalSinceReferenceDate: 20_000) // a multiple of 2 s
        let first = animator.frame(at: start)
        #expect(animator.frame(at: start.addingTimeInterval(1.9)) == first)
        #expect(animator.frame(at: start.addingTimeInterval(2.0)) != first)
    }
}
