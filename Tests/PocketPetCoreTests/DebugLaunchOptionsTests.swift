import Foundation
import Testing
@testable import PocketPetCore

@Suite("Debug launch options")
struct DebugLaunchOptionsTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func noArgumentsMeansLive() {
        let options = DebugLaunchOptions(arguments: ["Hingeling"], now: now)
        #expect(!options.isActive)
    }

    @Test func parsesFoldAndPet() throws {
        let options = DebugLaunchOptions(arguments: ["Hingeling", "-fold", "half:120", "-pet", "hungry,grown,Moss"], now: now)
        #expect(options.isActive)
        #expect(options.fold == .partiallyOpen(angleDegrees: 120))
        let pet = try #require(options.pet)
        #expect(pet.mood == .hungry)
        #expect(pet.lifeStage == .grown)
        #expect(pet.name == "Moss")
        #expect(pet.lastUpdated == now)
    }

    @Test(arguments: [("closed", FoldPosture.closed), ("open", .open), ("unavailable", .unavailable), ("half", .partiallyOpen(angleDegrees: 100))])
    func postures(text: String, posture: FoldPosture) {
        #expect(DebugLaunchOptions.posture(text) == posture)
    }

    @Test func badValuesAreIgnored() {
        let options = DebugLaunchOptions(arguments: ["-fold", "sideways", "-pet", "cranky,young", "-pet"], now: now)
        #expect(options.fold == nil)
        #expect(options.pet == nil)
        #expect(DebugLaunchOptions(arguments: ["-mockFold"], now: now).playsDemoScript)
    }
}
