import Foundation
import Testing
@testable import PocketPetCore

@Suite("Pixel art")
struct PetArtTests {
    @Test func paletteHasEightToSixteenColours() {
        let count = PixelPalette.visibleColourCount
        #expect(count >= 8 && count <= 16)
    }

    @Test func everyMoodAndStageHasALoop() {
        for stage in LifeStage.allCases {
            for mood in Mood.allCases {
                let frames = PetSprites.frames(for: .mood(mood), stage: stage)
                #expect(frames.count >= 2, "\(mood) at \(stage) should loop")
                for frame in frames {
                    #expect(frame.width == PixelFrame.size && frame.height == PixelFrame.size)
                    #expect(frame.filledCount > 40, "\(mood) at \(stage) looks empty")
                }
            }
        }
    }

    @Test func reactionsAndStageRoutineExistForEveryLifeStage() {
        for stage in LifeStage.allCases {
            for reaction in PetReaction.allCases {
                #expect(PetSprites.frames(for: .reaction(reaction), stage: stage).count >= 3)
            }
            #expect(PetSprites.frames(for: .stage, stage: stage).count >= 3)
        }
    }

    @Test func moodsLookDifferentFromEachOther() {
        for stage in LifeStage.allCases {
            let firsts = Mood.allCases.map { PetSprites.frames(for: .mood($0), stage: stage)[0].ascii }
            #expect(Set(firsts).count == Mood.allCases.count, "two moods share a first frame at \(stage)")
        }
    }

    @Test func creatureGrowsWithLifeStage() {
        let sizes = [LifeStage.newborn, .young, .grown].map { PetSprites.body(stage: $0).filledCount }
        #expect(sizes == sizes.sorted() && Set(sizes).count == 3)
    }

    @Test func elderHasSilverTuft() {
        #expect(PetSprites.body(stage: .elder).pixels.contains(.elderTuft))
        #expect(!PetSprites.body(stage: .grown).pixels.contains(.elderTuft))
    }

    @Test func reactionPlaysOnceThenLoopResumes() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        var animator = PetAnimator(stage: .young, mood: .content)
        animator.play(.feed, at: start)
        #expect(animator.pose(at: start.addingTimeInterval(0.1)) == .reaction(.feed))
        let done = PetAnimator.duration(of: .feed, stage: .young)
        #expect(animator.pose(at: start.addingTimeInterval(done + 0.01)) == .mood(.content))
    }

    @Test func reduceMotionHoldsOneStillFrame() {
        var animator = PetAnimator(stage: .grown, mood: .joyful)
        animator.play(.play, at: Date(timeIntervalSinceReferenceDate: 0))
        let frames = (0..<20).map {
            animator.frame(at: Date(timeIntervalSinceReferenceDate: Double($0) * 0.13), reduceMotion: true)
        }
        #expect(Set(frames.map(\.ascii)).count == 1)
        #expect(frames[0] == PetSprites.frames(for: .mood(.joyful), stage: .grown)[0])
    }

    @Test func loopAnimates() {
        let animator = PetAnimator(stage: .grown, mood: .joyful)
        let a = animator.frame(at: Date(timeIntervalSinceReferenceDate: 0))
        let b = animator.frame(at: Date(timeIntervalSinceReferenceDate: PetAnimator.loopFrameDuration))
        #expect(a != b)
    }

    @Test func stageSceneUsesStageRoutineUnlessAsleep() {
        let now = Date()
        #expect(PetAnimator(stage: .young, mood: .content, onStage: true).pose(at: now) == .stage)
        #expect(PetAnimator(stage: .young, mood: .asleep, onStage: true).pose(at: now) == .mood(.asleep))
    }
}

@Suite("Sample pets")
struct SamplePetTests {
    @Test func sampleMatchesRequestedMoodAndStage() {
        for stage in LifeStage.allCases {
            for mood in Mood.allCases {
                let pet = PetState.sample(mood: mood, stage: stage)
                #expect(pet.mood == mood)
                #expect(pet.lifeStage == stage)
            }
        }
    }
}
