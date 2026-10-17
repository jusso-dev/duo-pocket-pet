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
