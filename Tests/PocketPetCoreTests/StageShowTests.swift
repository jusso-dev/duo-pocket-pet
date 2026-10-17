import Foundation
import Testing
@testable import PocketPetCore

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

@Suite("StageShow")
struct StageShowTests {
    @Test func tiredPetBowsWhateverElseItFeels() {
        #expect(StageShow.routine(for: PetState(energy: Mood.sleepyAt, bornAt: t0)) == .sleepyBow)
        #expect(StageShow.routine(for: PetState(happiness: 0.95, energy: 0.1, bornAt: t0)) == .sleepyBow)
        // Hungry outranks sleepy for the mood, but a tired pet still only bows.
        #expect(StageShow.routine(for: PetState(hunger: 0.9, energy: 0.1, bornAt: t0)) == .sleepyBow)
        #expect(StageShow.routine(for: PetState(isAsleep: true, bornAt: t0)) == .sleepyBow)
        #expect(!StageRoutine.sleepyBow.usesStageFrames)
    }

    @Test func routineFollowsMood() {
        #expect(StageShow.routine(for: PetState(hunger: 0.8, energy: 0.8, bornAt: t0)) == .shuffle)
        #expect(StageShow.routine(for: PetState(energy: 0.8, hygiene: 0.2, bornAt: t0)) == .shuffle)
        #expect(StageShow.routine(for: PetState(happiness: 0.2, energy: 0.8, bornAt: t0)) == .shuffle)
        #expect(StageShow.routine(for: PetState(happiness: 0.6, energy: 0.8, bornAt: t0)) == .dance)
        #expect(StageShow.routine(for: PetState(hunger: 0.1, happiness: 0.9, energy: 0.8, bornAt: t0)) == .encore)
        #expect(StageRoutine.dance.usesStageFrames)
    }

    @Test func cheerRaisesHappinessOncePerThirtySeconds() {
        var engine = PetEngine(state: PetState(happiness: 0.5, bornAt: t0))
        var show = StageShow()
        #expect(show.cheer(&engine, at: t0) == .applied)
        let after = engine.state.happiness
        #expect(after > 0.5)
        #expect(show.cheer(&engine, at: t0.addingTimeInterval(10)) == .coolingDown(remaining: 20))
        #expect(show.cheer(&engine, at: t0.addingTimeInterval(29.9)).wasApplied == false)
        #expect(show.cooldownRemaining(at: t0.addingTimeInterval(30)) == 0)
        #expect(show.cheer(&engine, at: t0.addingTimeInterval(30)) == .applied)
        #expect(engine.state.happiness > after)
    }

    @Test func refusedCheerDoesNotStartTheCooldown() {
        var engine = PetEngine(state: PetState(isAsleep: true, bornAt: t0))
        var show = StageShow()
        #expect(show.cheer(&engine, at: t0) == .asleep)
        #expect(show.lastCheer == nil)
        _ = engine.wake(at: t0)
        #expect(show.cheer(&engine, at: t0.addingTimeInterval(1)) == .applied)
    }

    @Test func clockGoingBackwardsDoesNotLockCheeringOut() {
        var engine = PetEngine(state: PetState(bornAt: t0))
        var show = StageShow()
        _ = show.cheer(&engine, at: t0)
        #expect(show.cooldownRemaining(at: t0.addingTimeInterval(-3600)) == 0)
    }

    @Test func sessionSavesALandedCheerOnly() {
        let store = InMemoryPetStore(PetState(happiness: 0.5, bornAt: t0))
        var session = PetSession(store: store, now: t0)
        session.apply(.partiallyOpen(angleDegrees: 100), at: t0)
        let before = store.saveCount
        #expect(session.cheer(at: t0) == .applied)
        #expect(store.saveCount == before + 1)
        #expect(session.cheer(at: t0.addingTimeInterval(5)) == .coolingDown(remaining: 25))
        #expect(store.saveCount == before + 1)
    }
}

@Suite("Stage lighting")
struct StageLightingTests {
    @Test func spotlightFollowsTheHinge() {
        #expect(StageLighting.spotlightTilt(hingeDegrees: 90) == 0)
        #expect(StageLighting.spotlightTilt(hingeDegrees: 0) == -40)
        #expect(StageLighting.spotlightTilt(hingeDegrees: 180) == 40)
        #expect(StageLighting.spotlightTilt(hingeDegrees: 300) == 40)
        #expect(StageLighting.spotlightTilt(hingeDegrees: .nan) == 0)
        #expect(StageLighting.spotlightIntensity(hingeDegrees: 90) == 1)
        #expect(StageLighting.spotlightIntensity(hingeDegrees: 120) < 1)
    }

    /// The test plan: script open, then 90, then 120 degrees, and check the
    /// scene and the light angle.
    @Test func mockScriptDrivesSceneAndLight() async {
        let mock = MockFoldStateService(initial: .open)
        var session = PetSession(store: InMemoryPetStore(), now: t0)
        let stream = mock.updates
        mock.send(.partiallyOpen(angleDegrees: 90))
        mock.send(.partiallyOpen(angleDegrees: 120))
        mock.finish()
        var seen: [PetScene] = []
        var tilts: [Double] = []
        for await posture in stream {
            session.apply(posture, at: t0)
            seen.append(session.scene)
            if case .stage(let angle) = session.scene { tilts.append(StageLighting.spotlightTilt(hingeDegrees: angle)) }
        }
        #expect(seen == [.home, .stage(angleDegrees: 90), .stage(angleDegrees: 120)])
        #expect(tilts.count == 2)
        #expect(tilts[0] == 0)
        #expect(abs(tilts[1] - 40.0 / 3) < 0.0001)
    }
}

@Suite("FoldSplit")
struct FoldSplitTests {
    let bounds = CGRect(x: 0, y: 0, width: 400, height: 800)

    @Test func noDivisionMeansNoSplit() {
        #expect(FoldSplit(bounds: bounds, division: nil) == nil)
    }

    @Test func horizontalFoldSplitsTopAndBottom() throws {
        let split = try #require(FoldSplit(bounds: bounds, division: CGRect(x: 0, y: 380, width: 400, height: 40)))
        #expect(split.axis == .horizontal)
        #expect(split.first == CGRect(x: 0, y: 0, width: 400, height: 380))
        #expect(split.second == CGRect(x: 0, y: 420, width: 400, height: 380))
    }

    @Test func zeroWidthDivisionStillGetsAGutter() throws {
        let split = try #require(FoldSplit(bounds: bounds, division: CGRect(x: 200, y: 0, width: 0, height: 800), gutter: 12))
        #expect(split.axis == .vertical)
        #expect(split.first.maxX == 188)
        #expect(split.second.minX == 212)
        #expect(!split.first.intersects(split.second))
    }

    @Test func divisionOutsideTheBoundsIsIgnored() {
        #expect(FoldSplit(bounds: bounds, division: CGRect(x: 0, y: 900, width: 400, height: 20)) == nil)
    }
}
