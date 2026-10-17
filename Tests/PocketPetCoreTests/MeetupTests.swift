import Foundation
import Testing
@testable import PocketPetCore

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

/// Two machines wired together in memory. Messages go through the codec, as
/// they would over the network, and can be dropped to simulate a disconnect.
private struct Pair {
    var a: MeetupMachine
    var b: MeetupMachine
    var aOut: [MeetupMachine.Output] = []
    var bOut: [MeetupMachine.Output] = []
    var connected = true

    init(a: MeetupMachine, b: MeetupMachine) {
        self.a = a
        self.b = b
    }

    mutating func deliver(_ outputs: [MeetupMachine.Output], fromA: Bool, at now: Date) {
        if fromA { aOut += outputs } else { bOut += outputs }
        guard connected else { return }
        for case .send(let message) in outputs {
            let decoded = MeetupCodec.decode(try! MeetupCodec.encode(message))!
            if fromA {
                deliver(b.receive(decoded, at: now), fromA: false, at: now)
            } else {
                deliver(a.receive(decoded, at: now), fromA: true, at: now)
            }
        }
    }

    mutating func start(at now: Date) {
        deliver(a.start(at: now), fromA: true, at: now)
        deliver(b.start(at: now), fromA: false, at: now)
    }

    mutating func tick(at now: Date) {
        deliver(a.tick(at: now), fromA: true, at: now)
        deliver(b.tick(at: now), fromA: false, at: now)
    }

    static func played(_ outputs: [MeetupMachine.Output]) -> PetCard? {
        for case .playedTogether(let peer) in outputs { return peer }
        return nil
    }
}

private let bip = PetCard(name: "Bip", stage: .young, mood: .content)
private let moss = PetCard(name: "Moss", stage: .elder, mood: .joyful)

@Suite("Meetup")
struct MeetupTests {
    @Test func twoPetsGreetPlayAndPart() {
        var pair = Pair(a: MeetupMachine(me: bip), b: MeetupMachine(me: moss))
        pair.start(at: t0)
        #expect(pair.a.phase == .playing(peer: moss, since: t0))
        #expect(pair.b.phase == .playing(peer: bip, since: t0))
        pair.tick(at: t0.addingTimeInterval(3))
        #expect(Pair.played(pair.aOut) == nil)
        pair.tick(at: t0.addingTimeInterval(MeetupMachine.playDuration))
        #expect(Pair.played(pair.aOut) == moss)
        #expect(Pair.played(pair.bOut) == bip)
        #expect(pair.a.phase == .ended(.finished))
        #expect(pair.b.phase == .ended(.finished))
    }

    @Test func helloFromOneSideOnlyTimesOut() {
        var a = MeetupMachine(me: bip)
        _ = a.start(at: t0)
        #expect(a.tick(at: t0.addingTimeInterval(5)).isEmpty)
        let out = a.tick(at: t0.addingTimeInterval(MeetupMachine.handshakeTimeout))
        #expect(out == [.send(.goodbye(.timedOut)), .ended(.timedOut)])
    }

    @Test func versionMismatchEndsPolitely() {
        var pair = Pair(a: MeetupMachine(me: bip, version: 1), b: MeetupMachine(me: moss, version: 2))
        pair.start(at: t0)
        #expect(pair.a.phase == .ended(.versionMismatch))
        #expect(pair.b.phase == .ended(.versionMismatch))
        #expect(Pair.played(pair.aOut) == nil)
        #expect(Pair.played(pair.bOut) == nil)
    }

    @Test func droppedConnectionPartWayGivesNoBoost() {
        var pair = Pair(a: MeetupMachine(me: bip), b: MeetupMachine(me: moss))
        pair.start(at: t0)
        pair.connected = false
        let out = pair.a.disconnected()
        #expect(out == [.ended(.disconnected)])
        #expect(pair.a.tick(at: t0.addingTimeInterval(60)).isEmpty)
        // The other side never hears goodbye. Its own transport reports the drop.
        _ = pair.b.disconnected()
        #expect(pair.b.phase == .ended(.disconnected))
        #expect(Pair.played(pair.aOut) == nil)
        #expect(Pair.played(pair.bOut) == nil)
    }

    @Test func earlyFinishedGoodbyeDoesNotCount() {
        var a = MeetupMachine(me: bip)
        _ = a.start(at: t0)
        _ = a.receive(.hello(version: MeetupCodec.version, pet: moss), at: t0)
        _ = a.receive(.playInvite, at: t0)
        let out = a.receive(.goodbye(.finished), at: t0.addingTimeInterval(1))
        #expect(Pair.played(out) == nil)
        #expect(a.phase == .ended(.cancelled))
    }

    @Test func peerFinishingAMomentEarlierStillCounts() {
        var a = MeetupMachine(me: bip)
        _ = a.start(at: t0)
        _ = a.receive(.hello(version: MeetupCodec.version, pet: moss), at: t0)
        _ = a.receive(.playInvite, at: t0)
        let out = a.receive(.goodbye(.finished), at: t0.addingTimeInterval(MeetupMachine.playDuration - 0.5))
        #expect(Pair.played(out) == moss)
    }

    @Test func inviteBeforeHelloIsRemembered() {
        var a = MeetupMachine(me: bip)
        _ = a.start(at: t0)
        _ = a.receive(.playInvite, at: t0)
        _ = a.receive(.hello(version: MeetupCodec.version, pet: moss), at: t0)
        #expect(a.phase == .playing(peer: moss, since: t0))
    }

    @Test func posesUpdateThePeerAndMyMoodIsShared() {
        var a = MeetupMachine(me: bip)
        _ = a.start(at: t0)
        _ = a.receive(.hello(version: MeetupCodec.version, pet: moss), at: t0)
        _ = a.receive(.pose(.sleepy), at: t0)
        #expect(a.peer?.mood == .sleepy)
        let out = a.updateMe(PetCard(name: "Bip", stage: .young, mood: .joyful))
        #expect(out == [.send(.pose(.joyful))])
    }

    @Test func cancelSaysGoodbye() {
        var a = MeetupMachine(me: bip)
        _ = a.start(at: t0)
        #expect(a.cancel() == [.send(.goodbye(.cancelled)), .ended(.cancelled)])
        #expect(a.cancel().isEmpty)
    }
}

@Suite("Meetup codec")
struct MeetupCodecTests {
    @Test(arguments: [
        MeetupMessage.hello(version: 1, pet: bip),
        .pose(.hungry),
        .playInvite,
        .goodbye(.versionMismatch),
    ])
    func roundTrips(message: MeetupMessage) throws {
        #expect(MeetupCodec.decode(try MeetupCodec.encode(message)) == message)
    }

    @Test func onlyNameStageAndMoodAreSent() throws {
        let data = try MeetupCodec.encode(.hello(version: 1, pet: PetCard(state: PetState(name: "Bip", bornAt: t0))))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let pet = try #require(json["pet"] as? [String: Any])
        #expect(Set(pet.keys) == ["name", "stage", "mood"])
    }

    @Test func junkAndUnknownMessagesAreIgnored() {
        #expect(MeetupCodec.decode(Data("not json".utf8)) == nil)
        #expect(MeetupCodec.decode(Data(#"{"type":"dance"}"#.utf8)) == nil)
        #expect(MeetupCodec.decode(Data(repeating: 0x20, count: 5000)) == nil)
    }

    @Test func longNamesAreCapped() throws {
        let long = String(repeating: "a", count: 500)
        let data = Data(#"{"type":"hello","version":1,"pet":{"name":"\#(long)","stage":"young","mood":"content"}}"#.utf8)
        guard case .hello(_, let pet) = try #require(MeetupCodec.decode(data)) else { Issue.record("not a hello"); return }
        #expect(pet.name.count == PetCard.maxNameLength)
    }
}

@Suite("Meetup ledger")
struct MeetupLedgerTests {
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    @Test func oncePerPairPerDay() {
        var ledger = MeetupLedger()
        #expect(ledger.claim(pair: "a+b", at: t0, calendar: utc))
        #expect(!ledger.claim(pair: "a+b", at: t0.addingTimeInterval(3600), calendar: utc))
        #expect(ledger.claim(pair: "a+c", at: t0.addingTimeInterval(3600), calendar: utc))
        #expect(ledger.claim(pair: "a+b", at: t0.addingTimeInterval(26 * 3600), calendar: utc))
    }

    @Test func boostRaisesHappinessAndSaves() {
        let store = InMemoryPetStore(PetState(happiness: 0.5, bornAt: t0))
        var session = PetSession(store: store, now: t0)
        let before = store.saveCount
        #expect(session.playedWithFriend(at: t0) == .applied)
        #expect(session.state.happiness > 0.6)
        #expect(store.saveCount == before + 1)
    }
}
