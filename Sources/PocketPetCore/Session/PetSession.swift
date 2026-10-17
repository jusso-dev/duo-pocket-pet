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
    /// Where the unreadable save was moved before the new pet was saved.
    public let preservedUnreadableSave: URL?
    /// False when an unreadable save could not be moved aside. The session then
    /// runs in memory only and never writes over the old file.
    public let isSavingEnabled: Bool

    public var state: PetState { engine.state }
    public var scene: PetScene { machine.scene ?? .standard }

    /// Loads the saved pet or starts a new one, then catches it up to `now`.
    ///
    /// If the save can't be decoded (corrupt, or written by a newer version),
    /// it is moved aside with `PetStore.preserveUnreadableSave(at:)` before the
    /// new pet is saved. If it can't be moved, or the file couldn't be read at
    /// all, nothing is saved this session, so the old data is never lost.
    public init(store: any PetStore, rules: PetRules = .standard, now: Date, newPetName: String = "Bip") {
        self.store = store
        var recovered: String?
        var preserved: URL?
        var canSave = true
        var blockedReason: String?
        let loaded: PetState?
        do {
            loaded = try store.load()
        } catch let error as PetCodecError {
            loaded = nil
            recovered = String(describing: error)
            do {
                preserved = try store.preserveUnreadableSave(at: now)
            } catch {
                canSave = false
                blockedReason = "Not saving: the unreadable save could not be moved aside (\(error))."
            }
        } catch {
            // Not a decoding problem (for example the file is locked or unreadable
            // right now). The data may be fine, so leave it alone.
            loaded = nil
            recovered = String(describing: error)
            canSave = false
            blockedReason = "Not saving: the saved pet could not be read (\(error))."
        }
        recoveredFromError = recovered
        preservedUnreadableSave = preserved
        isSavingEnabled = canSave
        lastSaveError = blockedReason
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
        guard isSavingEnabled else { return }
        do {
            try store.save(engine.state)
            lastSaveError = nil
        } catch {
            lastSaveError = String(describing: error)
        }
    }
}
