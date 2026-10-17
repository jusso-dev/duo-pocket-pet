import Foundation

/// Somewhere to keep the pet between launches.
public protocol PetStore: Sendable {
    /// Returns nil when nothing has been saved yet.
    func load() throws -> PetState?
    func save(_ state: PetState) throws
    /// Moves a save that `load()` could not decode out of the way, so a new
    /// pet can be saved without destroying it. Returns where the old save went,
    /// or nil when there was nothing to move. Throws when the save could not be
    /// preserved, in which case the caller must not save over it.
    func preserveUnreadableSave(at date: Date) throws -> URL?
}

public enum PetStoreError: Error, Equatable {
    /// This store has no way to keep an unreadable save, so it must not be overwritten.
    case cannotPreserveUnreadableSave
}

extension PetStore {
    /// Stores that can't move a save aside refuse, so the session won't overwrite it.
    public func preserveUnreadableSave(at date: Date) throws -> URL? {
        throw PetStoreError.cannotPreserveUnreadableSave
    }
}

/// For tests and previews, and the app's fallback when there's nowhere to save.
public final class InMemoryPetStore: PetStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: PetState?
    private var _saveCount = 0
    /// Set when the app is using this store only because the real one failed.
    /// Nothing survives a relaunch, so the app should say so.
    public let fallbackReason: String?

    public init(_ state: PetState? = nil, fallbackReason: String? = nil) {
        stored = state
        self.fallbackReason = fallbackReason
    }

    public var saveCount: Int { lock.withLock { _saveCount } }

    public func load() throws -> PetState? {
        lock.withLock { stored }
    }

    public func save(_ state: PetState) throws {
        lock.withLock {
            stored = state
            _saveCount += 1
        }
    }

    /// An in-memory save is always decodable, so there is never anything to move.
    public func preserveUnreadableSave(at date: Date) throws -> URL? { nil }
}

/// Saves the pet as a JSON file, written atomically.
public struct FilePetStore: PetStore {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `<Application Support>/Hingeling/pet.json`.
    public static func standard(fileManager: FileManager = .default) throws -> FilePetStore {
        let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return FilePetStore(url: base.appendingPathComponent("Hingeling", isDirectory: true).appendingPathComponent("pet.json"))
    }

    public func load() throws -> PetState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try PetCodec.decode(Data(contentsOf: url))
    }

    public func save(_ state: PetState) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try PetCodec.encode(state).write(to: url, options: .atomic)
    }

    /// Renames `pet.json` to `pet.corrupt-<UTC timestamp>.json` in the same
    /// folder, adding `-2`, `-3` and so on if that name is taken.
    public func preserveUnreadableSave(at date: Date) throws -> URL? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let folder = url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.isEmpty ? "json" : url.pathExtension
        let base = "\(stem).corrupt-\(FilePetStore.timestamp(date))"
        var target = folder.appendingPathComponent("\(base).\(ext)")
        var suffix = 2
        while fileManager.fileExists(atPath: target.path) {
            target = folder.appendingPathComponent("\(base)-\(suffix).\(ext)")
            suffix += 1
        }
        try fileManager.moveItem(at: url, to: target)
        return target
    }

    /// `20261017T060000Z`: sortable, and safe in file names on every platform.
    static func timestamp(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        func pad(_ value: Int?, _ width: Int) -> String {
            let text = String(value ?? 0)
            return String(repeating: "0", count: max(0, width - text.count)) + text
        }
        return "\(pad(c.year, 4))\(pad(c.month, 2))\(pad(c.day, 2))T\(pad(c.hour, 2))\(pad(c.minute, 2))\(pad(c.second, 2))Z"
    }
}
