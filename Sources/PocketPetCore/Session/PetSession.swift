import Foundation

/// Ties the engine, the scene machine and the store together. The app's
/// view model owns one of these and forwards fold changes and button taps.
/// Every change is saved straight away.
public struct PetSession {
    public private(set) var engine: PetEngine
    public private(set) var machine = PetSceneMachine()
    public let store: any PetStore
    /// The last save error, if any. The app keeps running in memory.
    public private(set) var lastSaveError: String?
    /// Set when a saved pet could not be read and a new one was started.
    public let recoveredFromError: String?

    public var state: PetState { engine.state }
    public var scene: PetScene { machine.scene ?? .standard }

    /// Loads the saved pet or starts a new one, then catches it up to `now`.
    public init(store: any PetStore, rules: PetRules = .standard, now: Date, newPetName: String = "Bip") {
        self.store = store
        var recovered: String?
        let loaded: PetState?
        do {
            loaded = try store.load()
        } catch {
            loaded = nil
            recovered = String(describing: error)
        }
        recoveredFromError = recovered
        engine = PetEngine(state: loaded ?? .newborn(name: newPetName, at: now), rules: rules)
        engine.tick(to: now)
        save()
    }

    public mutating func apply(_ posture: FoldPosture, at now: Date) {
        for effect in machine.handle(posture) {
            switch effect {
            case .putToSleep: engine.sleep(at: now)
            case .wakeUp: engine.wake(at: now)
            }
        }
        engine.tick(to: now)
        save()
    }

    @discardableResult
    public mutating func perform(_ action: PetAction, at now: Date) -> ActionResult {
        let result = engine.perform(action, at: now)
        save()
        return result
    }

    public mutating func tick(to now: Date) {
        engine.tick(to: now)
        save()
    }

    private mutating func save() {
        do {
            try store.save(engine.state)
            lastSaveError = nil
        } catch {
            lastSaveError = String(describing: error)
        }
    }
}
