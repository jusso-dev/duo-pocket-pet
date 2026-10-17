import Foundation
import Testing
@testable import PocketPetCore

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

@Suite("Persistence")
struct PersistenceTests {
    @Test func roundTrips() throws {
        let state = PetState(name: "Moss", hunger: 0.42, happiness: 0.33, energy: 0.9, hygiene: 0.5, ageSeconds: 12345, isAsleep: true, bornAt: t0, lastUpdated: t0.addingTimeInterval(60))
        #expect(try PetCodec.decode(PetCodec.encode(state)) == state)
    }

    @Test func rejectsFutureSchema() throws {
        var state = PetState(bornAt: t0)
        state.schemaVersion = 99
        let data = try PetCodec.encode(state)
        #expect(throws: PetCodecError.unsupportedSchema(found: 99, supported: PetState.currentSchemaVersion)) {
            try PetCodec.decode(data)
        }
    }

    @Test func rejectsCorruptData() {
        #expect(throws: PetCodecError.self) { try PetCodec.decode(Data("not json".utf8)) }
        #expect(throws: PetCodecError.self) { try PetCodec.decode(Data(#"{"schemaVersion":1}"#.utf8)) }
    }

    private func tempFolder() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("hingeling-\(UUID().uuidString)", isDirectory: true)
    }

    private func files(in folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
    }

    /// The bug: a corrupt pet.json was replaced by a newborn and the old bytes were gone.
    @Test func corruptSaveIsMovedAsideBeforeANewPetIsSaved() throws {
        let dir = tempFolder()
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("pet.json")
        let corrupt = Data(#"{"schemaVersion":1,"name":"Moss","hung"#.utf8)
        try corrupt.write(to: url)

        let session = PetSession(store: FilePetStore(url: url), now: t0)
        #expect(session.recoveredFromError != nil)

        // t0 is 2027-01-15 08:00:00 UTC.
        #expect(try files(in: dir) == ["pet.corrupt-20270115T080000Z.json", "pet.json"])
        #expect(try Data(contentsOf: dir.appendingPathComponent("pet.corrupt-20270115T080000Z.json")) == corrupt)
        // The new pet is saved and loads cleanly.
        #expect(try FilePetStore(url: url).load() == session.state)
    }

    @Test func sessionReportsWhereTheCorruptSaveWent() throws {
        let dir = tempFolder()
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("pet.json")
        try Data("not json".utf8).write(to: url)
        let session = PetSession(store: FilePetStore(url: url), now: t0)
        #expect(session.isSavingEnabled)
        #expect(session.lastSaveError == nil)
        #expect(session.preservedUnreadableSave?.lastPathComponent == "pet.corrupt-20270115T080000Z.json")
    }

    @Test func newerSchemaSaveIsKept() throws {
        let dir = tempFolder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("pet.json")
        var future = PetState(name: "Moss", bornAt: t0)
        future.schemaVersion = 99
        try FilePetStore(url: url).save(future)
        let original = try Data(contentsOf: url)

        _ = PetSession(store: FilePetStore(url: url), now: t0)
        let moved = try files(in: dir).filter { $0.hasPrefix("pet.corrupt-") }
        try #require(moved.count == 1)
        #expect(try Data(contentsOf: dir.appendingPathComponent(moved[0])) == original)
    }

    @Test func repeatedCorruptionNeverClobbersAnEarlierCopy() throws {
        let dir = tempFolder()
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("pet.json")
        let store = FilePetStore(url: url)
        try Data("first".utf8).write(to: url)
        let first = try store.preserveUnreadableSave(at: t0)
        try Data("second".utf8).write(to: url)
        let second = try store.preserveUnreadableSave(at: t0)
        #expect(first?.lastPathComponent == "pet.corrupt-20270115T080000Z.json")
        #expect(second?.lastPathComponent == "pet.corrupt-20270115T080000Z-2.json")
        #expect(try Data(contentsOf: first!) == Data("first".utf8))
        #expect(try Data(contentsOf: second!) == Data("second".utf8))
        #expect(try store.preserveUnreadableSave(at: t0) == nil)
    }

    /// A hand-edited or buggy save must get the same clamps as `PetState.init`.
    @Test func decodingClampsOutOfRangeValues() throws {
        let json = #"""
        {"ageSeconds":-500,"bornAt":"2027-01-15T08:00:00Z","energy":-0.5,"happiness":1.7,
         "hunger":5,"hygiene":0.4,"isAsleep":false,"lastUpdated":"2027-01-15T08:00:00Z",
         "name":"Moss","schemaVersion":1}
        """#
        let state = try PetCodec.decode(Data(json.utf8))
        #expect(state.hunger == 1)
        #expect(state.happiness == 1)
        #expect(state.energy == 0)
        #expect(state.hygiene == 0.4)
        #expect(state.ageSeconds == 0)
        #expect(state.name == "Moss")
        #expect(state.bornAt == t0)
        // A tick with no elapsed time used to leave the bad values in place.
        var engine = PetEngine(state: state)
        engine.tick(to: t0)
        #expect(engine.state.ageSeconds == 0)
        #expect(engine.state.hunger == 1)
    }

    @Test(arguments: ["", "   ", "\n"])
    func decodingAnEmptyNameFallsBackToTheDefault(name: String) throws {
        var state = PetState(name: "Moss", bornAt: t0)
        state.name = name
        let decoded = try PetCodec.decode(PetCodec.encode(state))
        #expect(decoded.name == "Bip")
    }

    @Test func fileStoreSavesAndLoads() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("hingeling-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FilePetStore(url: dir.appendingPathComponent("nested/pet.json"))
        #expect(try store.load() == nil)
        let state = PetState(name: "Tuft", bornAt: t0)
        try store.save(state)
        #expect(try store.load() == state)
    }
}
