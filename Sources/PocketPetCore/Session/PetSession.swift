import Foundation

/// Ties the engine, the scene machine and the store together. The app's
/// view model owns one of these and forwards fold changes and button taps.
///
/// Button taps, ticks, sleeping, waking and changes of scene kind are saved
/// straight away. A hinge that only moves within the half fold is not: those
/// changes are kept in memory until the next save, the next tick, or
/// `saveIfNeeded()` when the app goes to the background.
public struct PetSession {
    public private(set) var engine: PetEngine
    public private(set) var machine = PetSceneMachine()
    /// The half-fold stage: which routine to show and the cheer cooldown.
    public private(set) var stageShow = StageShow()
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

    /// True when the in-memory pet has changes that are not on disk yet.
    public private(set) var hasUnsavedChanges = false

    public var state: PetState { engine.state }
    public var scene: PetScene { machine.scene ?? .standard }
    /// What the pet performs on the stage right now.
    public var stageRoutine: StageRoutine { StageShow.routine(for: engine.state) }

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
        let previous = machine.scene
        let effects = machine.handle(posture)
        for effect in effects {
            switch effect {
            case .putToSleep: engine.sleep(at: now)
            case .wakeUp: engine.wake(at: now)
            }
        }
        engine.tick(to: now)
        if !effects.isEmpty || !PetSession.isSameKind(previous, machine.scene) {
            save()
        } else {
            // Only the angle moved, or nothing changed. The 30 second tick or
            // the background save picks this up.
            hasUnsavedChanges = true
        }
    }

    /// Saves if anything is waiting. Call when the app goes to the background.
    public mutating func saveIfNeeded() {
        if hasUnsavedChanges { save() }
    }

    private static func isSameKind(_ a: PetScene?, _ b: PetScene?) -> Bool {
        a?.kind == b?.kind
    }

    @discardableResult
    public mutating func perform(_ action: PetAction, at now: Date) -> ActionResult {
        let result = engine.perform(action, at: now)
        save()
        return result
    }

    /// Cheers for the pet on the stage. Saved when it lands.
    @discardableResult
    public mutating func cheer(at now: Date) -> CheerResult {
        let result = stageShow.cheer(&engine, at: now)
        if result.wasApplied { save() }
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
            hasUnsavedChanges = false
        } catch {
            lastSaveError = String(describing: error)
        }
    }
}
