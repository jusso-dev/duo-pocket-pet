import Foundation

/// Somewhere to keep the pet between launches.
public protocol PetStore: Sendable {
    /// Returns nil when nothing has been saved yet.
    func load() throws -> PetState?
    func save(_ state: PetState) throws
}

/// For tests and previews.
public final class InMemoryPetStore: PetStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: PetState?
    private var _saveCount = 0

    public init(_ state: PetState? = nil) {
        stored = state
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
}
