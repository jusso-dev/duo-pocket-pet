import Foundation

public enum PetCodecError: Error, Equatable {
    case corrupt(String)
    case unsupportedSchema(found: Int, supported: Int)
}

/// Versioned JSON encoding for `PetState`.
public enum PetCodec {
    public static func encode(_ state: PetState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(state)
    }

    public static func decode(_ data: Data) throws -> PetState {
        struct Header: Decodable { var schemaVersion: Int }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let header: Header
        do {
            header = try decoder.decode(Header.self, from: data)
        } catch {
            throw PetCodecError.corrupt(String(describing: error))
        }
        guard header.schemaVersion <= PetState.currentSchemaVersion, header.schemaVersion >= 1 else {
            throw PetCodecError.unsupportedSchema(found: header.schemaVersion, supported: PetState.currentSchemaVersion)
        }
        do {
            // Future migrations from older schema versions go here.
            return try decoder.decode(PetState.self, from: data)
        } catch {
            throw PetCodecError.corrupt(String(describing: error))
        }
    }
}
