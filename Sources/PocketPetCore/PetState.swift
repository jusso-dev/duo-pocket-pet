import Foundation

// Public interface for the pet model.
//
// This file is the contract other work builds against (glance view, art and
// animation set). Keep changes additive. If a breaking change is needed, bump
// `PetState.currentSchemaVersion` and add a migration in the persistence layer.

/// A need meter, always kept in `0...1`.
public typealias Meter = Double

/// Everything that is saved about the pet.
///
/// Meters run from 0 to 1. For `hunger`, higher is worse (1 is starving).
/// For `happiness`, `energy` and `hygiene`, higher is better.
public struct PetState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var name: String
    public var hunger: Meter
    public var happiness: Meter
    public var energy: Meter
    public var hygiene: Meter
    /// Total age in seconds. Ageing continues while asleep.
    public var ageSeconds: TimeInterval
    public var isAsleep: Bool
    public var bornAt: Date
    /// The last time decay was applied. `PetEngine.tick(to:)` advances it.
    public var lastUpdated: Date

    public init(
        name: String = "Bip",
        hunger: Meter = 0.2,
        happiness: Meter = 0.7,
        energy: Meter = 0.8,
        hygiene: Meter = 1.0,
        ageSeconds: TimeInterval = 0,
        isAsleep: Bool = false,
        bornAt: Date,
        lastUpdated: Date? = nil,
        schemaVersion: Int = PetState.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.hunger = hunger.clampedMeter
        self.happiness = happiness.clampedMeter
        self.energy = energy.clampedMeter
        self.hygiene = hygiene.clampedMeter
        self.ageSeconds = max(0, ageSeconds)
        self.isAsleep = isAsleep
        self.bornAt = bornAt
        self.lastUpdated = lastUpdated ?? bornAt
    }

    /// A brand new pet.
    public static func newborn(name: String = "Bip", at date: Date) -> PetState {
        PetState(name: name, bornAt: date)
    }

    public var lifeStage: LifeStage { LifeStage(ageSeconds: ageSeconds) }
    public var mood: Mood { Mood(for: self) }
}

/// How the pet feels right now. Derived from `PetState`, never stored.
///
/// Cases are listed from most to least urgent. Art and glance views should
/// have a pose for every case.
public enum Mood: String, CaseIterable, Codable, Sendable {
    case asleep
    case hungry
    case grubby
    case sleepy
    case glum
    case content
    case joyful

    public init(for state: PetState) {
        if state.isAsleep { self = .asleep; return }
        if state.hunger >= Mood.hungryAt { self = .hungry; return }
        if state.hygiene <= Mood.grubbyAt { self = .grubby; return }
        if state.energy <= Mood.sleepyAt { self = .sleepy; return }
        if state.happiness <= Mood.glumAt { self = .glum; return }
        if state.happiness >= Mood.joyfulAt, state.hunger < 0.4, state.energy > 0.4 {
            self = .joyful
            return
        }
        self = .content
    }

    public static let hungryAt: Meter = 0.7
    public static let grubbyAt: Meter = 0.3
    public static let sleepyAt: Meter = 0.2
    public static let glumAt: Meter = 0.3
    public static let joyfulAt: Meter = 0.8

    /// Short text for VoiceOver and the glance view.
    public var accessibilityDescription: String {
        switch self {
        case .asleep: "asleep"
        case .hungry: "hungry"
        case .grubby: "in need of a clean"
        case .sleepy: "sleepy"
        case .glum: "a bit glum"
        case .content: "content"
        case .joyful: "joyful"
        }
    }

    /// True when the pet needs the player to do something.
    public var needsAttention: Bool {
        switch self {
        case .hungry, .grubby, .sleepy, .glum: true
        case .asleep, .content, .joyful: false
        }
    }
}

/// Life stages, driven by age only. The pet never dies; neglect only makes it glum.
public enum LifeStage: String, CaseIterable, Codable, Sendable, Comparable {
    case newborn
    case young
    case grown
    case elder

    public static let youngAfter: TimeInterval = 24 * 3600
    public static let grownAfter: TimeInterval = 4 * 24 * 3600
    public static let elderAfter: TimeInterval = 21 * 24 * 3600

    public init(ageSeconds: TimeInterval) {
        switch ageSeconds {
        case ..<LifeStage.youngAfter: self = .newborn
        case ..<LifeStage.grownAfter: self = .young
        case ..<LifeStage.elderAfter: self = .grown
        default: self = .elder
        }
    }

    private var order: Int { LifeStage.allCases.firstIndex(of: self)! }
    public static func < (lhs: LifeStage, rhs: LifeStage) -> Bool { lhs.order < rhs.order }
}

/// Things the player can do.
public enum PetAction: String, CaseIterable, Codable, Sendable {
    case feed
    case clean
    case play
    case sleep
    case wake
}

/// The result of asking the pet to do something.
public enum ActionResult: Equatable, Sendable {
    case applied
    case refused(Refusal)

    public enum Refusal: String, Equatable, Sendable {
        case asleep
        case alreadyAsleep
        case alreadyAwake
        case notHungry
        case alreadyClean
        case tooTired
    }

    public var wasApplied: Bool { self == .applied }
}

/// Pure, deterministic rules for the pet. No clocks, timers or I/O: every call
/// takes the current time, so tests can drive it with fixed dates.
///
/// Every action first calls `tick(to:)`, so needs are up to date before the
/// action applies.
public struct PetEngine: Sendable {
    public private(set) var state: PetState
    public let rules: PetRules

    public init(state: PetState, rules: PetRules = .standard) {
        self.state = state
        self.rules = rules
    }

    /// Applies decay and ageing for the time since `state.lastUpdated`.
    ///
    /// If `now` is earlier than `lastUpdated` (the clock went backwards), no decay
    /// is applied and `lastUpdated` moves to `now`. Long gaps are capped at
    /// `rules.maxCatchUp` for decay, but age always advances by the full gap.
    public mutating func tick(to now: Date) {
        let elapsed = now.timeIntervalSince(state.lastUpdated)
        guard elapsed > 0 else {
            state.lastUpdated = now
            return
        }
        state.ageSeconds += elapsed
        var remaining = min(elapsed, rules.maxCatchUp)
        while remaining > 0 {
            let step = min(remaining, rules.integrationStep)
            applyDecay(seconds: step)
            remaining -= step
        }
        state.lastUpdated = now
    }

    @discardableResult
    public mutating func feed(at now: Date) -> ActionResult {
        tick(to: now)
        if state.isAsleep { return .refused(.asleep) }
        if state.hunger < rules.feedMinimumHunger { return .refused(.notHungry) }
        state.hunger = (state.hunger - rules.feedAmount).clampedMeter
        state.happiness = (state.happiness + rules.feedJoy).clampedMeter
        state.hygiene = (state.hygiene - rules.feedMess).clampedMeter
        return .applied
    }

    @discardableResult
    public mutating func clean(at now: Date) -> ActionResult {
        tick(to: now)
        if state.isAsleep { return .refused(.asleep) }
        if state.hygiene >= 0.99 { return .refused(.alreadyClean) }
        state.hygiene = 1
        state.happiness = (state.happiness + rules.cleanJoy).clampedMeter
        return .applied
    }

    @discardableResult
    public mutating func play(at now: Date) -> ActionResult {
        tick(to: now)
        if state.isAsleep { return .refused(.asleep) }
        if state.energy < rules.playEnergyCost { return .refused(.tooTired) }
        state.energy = (state.energy - rules.playEnergyCost).clampedMeter
        state.happiness = (state.happiness + rules.playJoy).clampedMeter
        state.hunger = (state.hunger + rules.playHungerCost).clampedMeter
        return .applied
    }

    @discardableResult
    public mutating func sleep(at now: Date) -> ActionResult {
        tick(to: now)
        if state.isAsleep { return .refused(.alreadyAsleep) }
        state.isAsleep = true
        return .applied
    }

    @discardableResult
    public mutating func wake(at now: Date) -> ActionResult {
        tick(to: now)
        if !state.isAsleep { return .refused(.alreadyAwake) }
        state.isAsleep = false
        return .applied
    }

    @discardableResult
    public mutating func perform(_ action: PetAction, at now: Date) -> ActionResult {
        switch action {
        case .feed: feed(at: now)
        case .clean: clean(at: now)
        case .play: play(at: now)
        case .sleep: sleep(at: now)
        case .wake: wake(at: now)
        }
    }

    private mutating func applyDecay(seconds: TimeInterval) {
        let hours = seconds / 3600
        let r = state.isAsleep ? rules.asleep : rules.awake
        var happinessDelta = -r.happinessLossPerHour
        if state.hunger >= Mood.hungryAt || state.hygiene <= Mood.grubbyAt {
            happinessDelta -= rules.neglectHappinessLossPerHour
        }
        state.hunger = (state.hunger + r.hungerGainPerHour * hours).clampedMeter
        state.hygiene = (state.hygiene - r.hygieneLossPerHour * hours).clampedMeter
        state.energy = (state.energy + r.energyChangePerHour * hours).clampedMeter
        state.happiness = (state.happiness + happinessDelta * hours).clampedMeter
    }
}

/// Tunable numbers for `PetEngine`. Rates are per hour of real time.
public struct PetRules: Equatable, Sendable {
    public struct Rates: Equatable, Sendable {
        public var hungerGainPerHour: Double
        public var happinessLossPerHour: Double
        /// Negative while awake (tiring), positive while asleep (resting).
        public var energyChangePerHour: Double
        public var hygieneLossPerHour: Double

        public init(hungerGainPerHour: Double, happinessLossPerHour: Double, energyChangePerHour: Double, hygieneLossPerHour: Double) {
            self.hungerGainPerHour = hungerGainPerHour
            self.happinessLossPerHour = happinessLossPerHour
            self.energyChangePerHour = energyChangePerHour
            self.hygieneLossPerHour = hygieneLossPerHour
        }
    }

    public var awake: Rates
    public var asleep: Rates
    /// Extra happiness loss per hour while hungry or grubby.
    public var neglectHappinessLossPerHour: Double
    public var feedAmount: Meter
    public var feedMinimumHunger: Meter
    public var feedJoy: Meter
    public var feedMess: Meter
    public var cleanJoy: Meter
    public var playEnergyCost: Meter
    public var playJoy: Meter
    public var playHungerCost: Meter
    /// Longest gap that decay is applied for, so a pet left for a month is not wrecked.
    public var maxCatchUp: TimeInterval
    /// Decay is integrated in steps of this size so mood thresholds apply part way through a gap.
    public var integrationStep: TimeInterval

    public init(
        awake: Rates, asleep: Rates, neglectHappinessLossPerHour: Double,
        feedAmount: Meter, feedMinimumHunger: Meter, feedJoy: Meter, feedMess: Meter,
        cleanJoy: Meter, playEnergyCost: Meter, playJoy: Meter, playHungerCost: Meter,
        maxCatchUp: TimeInterval, integrationStep: TimeInterval
    ) {
        self.awake = awake
        self.asleep = asleep
        self.neglectHappinessLossPerHour = neglectHappinessLossPerHour
        self.feedAmount = feedAmount
        self.feedMinimumHunger = feedMinimumHunger
        self.feedJoy = feedJoy
        self.feedMess = feedMess
        self.cleanJoy = cleanJoy
        self.playEnergyCost = playEnergyCost
        self.playJoy = playJoy
        self.playHungerCost = playHungerCost
        self.maxCatchUp = maxCatchUp
        self.integrationStep = max(1, integrationStep)
    }

    public static let standard = PetRules(
        awake: Rates(hungerGainPerHour: 0.06, happinessLossPerHour: 0.04, energyChangePerHour: -0.05, hygieneLossPerHour: 0.03),
        asleep: Rates(hungerGainPerHour: 0.03, happinessLossPerHour: 0.01, energyChangePerHour: 0.15, hygieneLossPerHour: 0.015),
        neglectHappinessLossPerHour: 0.03,
        feedAmount: 0.35, feedMinimumHunger: 0.1, feedJoy: 0.05, feedMess: 0.05,
        cleanJoy: 0.05,
        playEnergyCost: 0.15, playJoy: 0.2, playHungerCost: 0.05,
        maxCatchUp: 3 * 24 * 3600,
        integrationStep: 300
    )
}

extension Double {
    var clampedMeter: Double {
        guard isFinite else { return 0 }
        return Swift.min(1, Swift.max(0, self))
    }
}
