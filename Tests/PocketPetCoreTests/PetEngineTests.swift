import Foundation
import Testing
@testable import PocketPetCore

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
private func hours(_ h: Double) -> Date { t0.addingTimeInterval(h * 3600) }

@Suite("PetEngine")
struct PetEngineTests {
    @Test func newbornStartsContentAndAwake() {
        let state = PetState.newborn(at: t0)
        #expect(state.mood == .content)
        #expect(state.lifeStage == .newborn)
        #expect(!state.isAsleep)
        #expect(state.lastUpdated == t0)
    }

    @Test func tickDecaysNeedsWhileAwake() {
        var engine = PetEngine(state: .newborn(at: t0))
        engine.tick(to: hours(5))
        let s = engine.state
        #expect(abs(s.hunger - (0.2 + 0.3)) < 0.0001)
        #expect(abs(s.energy - (0.8 - 0.25)) < 0.0001)
        #expect(abs(s.hygiene - (1.0 - 0.15)) < 0.0001)
        #expect(abs(s.happiness - (0.7 - 0.2)) < 0.0001)
        #expect(s.ageSeconds == 5 * 3600)
        #expect(s.lastUpdated == hours(5))
    }

    @Test func sleepingRestoresEnergyAndSlowsDecay() {
        var engine = PetEngine(state: .newborn(at: t0))
        engine.sleep(at: t0)
        engine.tick(to: hours(2))
        #expect(abs(engine.state.energy - 1.0) < 0.0001)
        #expect(abs(engine.state.hunger - 0.26) < 0.0001)
        #expect(engine.state.mood == .asleep)
    }

    @Test func neglectSpeedsUpHappinessLossOncePastThreshold() {
        var engine = PetEngine(state: PetState(hunger: 0.7, happiness: 0.8, bornAt: t0))
        engine.tick(to: hours(1))
        #expect(abs(engine.state.happiness - (0.8 - 0.07)) < 0.0001)
    }

    @Test func clockGoingBackwardsAppliesNoDecay() {
        var engine = PetEngine(state: .newborn(at: t0))
        let before = engine.state
        engine.tick(to: hours(-3))
        #expect(engine.state.hunger == before.hunger)
        #expect(engine.state.ageSeconds == 0)
        #expect(engine.state.lastUpdated == hours(-3))
    }

    @Test func longGapsCapDecayButStillAge() {
        var engine = PetEngine(state: .newborn(at: t0))
        engine.tick(to: hours(24 * 30))
        #expect(engine.state.ageSeconds == 30 * 24 * 3600)
        #expect(engine.state.lifeStage == .elder)
        #expect(engine.state.hunger == 1)
        #expect(engine.state.mood == .hungry)
    }

    @Test func tickIsSplitInvariant() {
        var once = PetEngine(state: .newborn(at: t0))
        once.tick(to: hours(10))
        var many = PetEngine(state: .newborn(at: t0))
        for minute in stride(from: 7.0, through: 600, by: 7) { many.tick(to: t0.addingTimeInterval(minute * 60)) }
        many.tick(to: hours(10))
        #expect(abs(once.state.hunger - many.state.hunger) < 0.01)
        #expect(abs(once.state.happiness - many.state.happiness) < 0.02)
    }

    @Test func feedLowersHunger() {
        var engine = PetEngine(state: PetState(hunger: 0.8, bornAt: t0))
        #expect(engine.feed(at: t0) == .applied)
        #expect(abs(engine.state.hunger - 0.45) < 0.0001)
    }

    @Test func feedRefusedWhenFullOrAsleep() {
        var full = PetEngine(state: PetState(hunger: 0.05, bornAt: t0))
        #expect(full.feed(at: t0) == .refused(.notHungry))
        var sleepy = PetEngine(state: PetState(hunger: 0.8, isAsleep: true, bornAt: t0))
        #expect(sleepy.feed(at: t0) == .refused(.asleep))
    }

    @Test func cleanRestoresHygiene() {
        var engine = PetEngine(state: PetState(hygiene: 0.2, bornAt: t0))
        #expect(engine.state.mood == .grubby)
        #expect(engine.clean(at: t0) == .applied)
        #expect(engine.state.hygiene == 1)
        #expect(engine.clean(at: t0) == .refused(.alreadyClean))
    }

    @Test func playTradesEnergyForHappiness() {
        var engine = PetEngine(state: PetState(happiness: 0.5, energy: 0.5, bornAt: t0))
        #expect(engine.play(at: t0) == .applied)
        #expect(abs(engine.state.happiness - 0.7) < 0.0001)
        #expect(abs(engine.state.energy - 0.35) < 0.0001)
        var tired = PetEngine(state: PetState(energy: 0.1, bornAt: t0))
        #expect(tired.play(at: t0) == .refused(.tooTired))
    }

    @Test func sleepAndWakeAreIdempotentlyRefused() {
        var engine = PetEngine(state: .newborn(at: t0))
        #expect(engine.wake(at: t0) == .refused(.alreadyAwake))
        #expect(engine.sleep(at: t0) == .applied)
        #expect(engine.sleep(at: t0) == .refused(.alreadyAsleep))
        #expect(engine.perform(.wake, at: t0) == .applied)
    }

    @Test func meterValuesStayInRange() {
        let s = PetState(hunger: 4, happiness: -2, energy: .nan, hygiene: 1.5, bornAt: t0)
        #expect(s.hunger == 1 && s.happiness == 0 && s.energy == 0 && s.hygiene == 1)
    }
}

@Suite("Mood and life stage")
struct MoodTests {
    @Test(arguments: [
        (PetState(isAsleep: true, bornAt: t0), Mood.asleep),
        (PetState(hunger: 0.9, hygiene: 0.1, bornAt: t0), Mood.hungry),
        (PetState(hygiene: 0.1, bornAt: t0), Mood.grubby),
        (PetState(energy: 0.1, bornAt: t0), Mood.sleepy),
        (PetState(happiness: 0.2, bornAt: t0), Mood.glum),
        (PetState(hunger: 0.1, happiness: 0.9, energy: 0.9, bornAt: t0), Mood.joyful),
        (PetState(bornAt: t0), Mood.content),
    ])
    func moodPriority(state: PetState, expected: Mood) {
        #expect(state.mood == expected)
    }

    @Test func everyMoodHasAccessibilityText() {
        for mood in Mood.allCases { #expect(!mood.accessibilityDescription.isEmpty) }
    }

    @Test func lifeStageBoundaries() {
        #expect(LifeStage(ageSeconds: 0) == .newborn)
        #expect(LifeStage(ageSeconds: LifeStage.youngAfter) == .young)
        #expect(LifeStage(ageSeconds: LifeStage.grownAfter) == .grown)
        #expect(LifeStage(ageSeconds: LifeStage.elderAfter) == .elder)
        #expect(LifeStage.newborn < LifeStage.elder)
    }
}
