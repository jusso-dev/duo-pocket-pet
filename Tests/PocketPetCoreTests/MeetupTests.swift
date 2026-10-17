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

    static func met(_ outputs: [MeetupMachine.Output]) -> [PetCard] {
        outputs.compactMap { if case .met(let peer) = $0 { peer } else { nil } }
    }
}

private let bip = PetCard(name: "Bip", stage: .young, mood: .content)
private let moss = PetCard(name: "Moss", stage: .elder, mood: .joyful)

@Suite("Meetup")
struct MeetupTests {
    @Test func twoPetsGreetDanceAndStayTogether() {
        var pair = Pair(a: MeetupMachine(me: bip), b: MeetupMachine(me: moss))
        pair.start(at: t0)
        #expect(pair.a.peer == moss)
        #expect(pair.b.peer == bip)
        #expect(Pair.met(pair.aOut) == [moss])
        #expect(Pair.met(pair.bOut) == [bip])
        #expect(pair.a.isDancing && pair.b.isDancing)
        pair.tick(at: t0.addingTimeInterval(3))
        #expect(Pair.played(pair.aOut) == nil)
        pair.tick(at: t0.addingTimeInterval(MeetupMachine.playDuration))
        #expect(Pair.played(pair.aOut) == moss)
        #expect(Pair.played(pair.bOut) == bip)
        // Still together after the dance, for gifts and games.
        #expect(pair.a.isTogether && pair.b.isTogether)
        #expect(pair.a.dance == .done)
        // The dance doesn't pay out twice.
        let before = pair.aOut.count
        pair.tick(at: t0.addingTimeInterval(60))
        #expect(pair.aOut.count == before)
    }

    @Test func giftsAndGameMessagesFlowWhileTogether() {
        var pair = Pair(a: MeetupMachine(me: bip), b: MeetupMachine(me: moss))
        pair.start(at: t0)
        pair.deliver(pair.a.send(.snack), fromA: true, at: t0)
        #expect(pair.bOut.contains(.receivedGift(.snack, from: bip)))
        pair.deliver(pair.b.sendGame(.gameInvite), fromA: false, at: t0)
        #expect(pair.aOut.contains(.game(.gameInvite)))
    }

    @Test func nothingIsSentBeforeGreeting() {
        var a = MeetupMachine(me: bip)
        #expect(a.send(.toy).isEmpty)
        _ = a.start(at: t0)
        #expect(a.sendGame(.gameInvite).isEmpty)
        #expect(a.receive(.gift(.toy), at: t0).isEmpty)
    }

    @Test func leavingSaysGoodbyeAndEndsBoth() {
        var pair = Pair(a: MeetupMachine(me: bip), b: MeetupMachine(me: moss))
        pair.start(at: t0)
        pair.deliver(pair.a.leave(), fromA: true, at: t0)
        #expect(pair.a.phase == .ended(.finished))
        #expect(pair.b.phase == .ended(.finished))
        #expect(pair.a.leave().isEmpty)
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
        #expect(Pair.met(pair.aOut).isEmpty)
    }

    @Test func droppedConnectionMidDanceGivesNoBoost() {
        var pair = Pair(a: MeetupMachine(me: bip), b: MeetupMachine(me: moss))
        pair.start(at: t0)
        pair.connected = false
        #expect(pair.a.disconnected() == [.ended(.disconnected)])
        #expect(pair.a.tick(at: t0.addingTimeInterval(60)).isEmpty)
        _ = pair.b.disconnected()
        #expect(pair.b.phase == .ended(.disconnected))
        #expect(Pair.played(pair.aOut) == nil)
        #expect(Pair.played(pair.bOut) == nil)
    }

    @Test func inviteBeforeHelloIsRemembered() {
        var a = MeetupMachine(me: bip)
        _ = a.start(at: t0)
        _ = a.receive(.playInvite, at: t0)
        _ = a.receive(.hello(version: MeetupCodec.version, pet: moss), at: t0)
        #expect(a.isDancing)
    }

    @Test func posesUpdateThePeerAndMyMoodIsShared() {
        var a = MeetupMachine(me: bip)
        _ = a.start(at: t0)
        _ = a.receive(.hello(version: MeetupCodec.version, pet: moss), at: t0)
        _ = a.receive(.pose(.sleepy), at: t0)
        #expect(a.peer?.mood == .sleepy)
        #expect(a.updateMe(PetCard(name: "Bip", stage: .young, mood: .joyful)) == [.send(.pose(.joyful))])
    }

    @Test func leavingBeforeGreetingIsACancel() {
        var a = MeetupMachine(me: bip)
        _ = a.start(at: t0)
        #expect(a.leave() == [.send(.goodbye(.cancelled)), .ended(.cancelled)])
    }
}

@Suite("Meetup codec")
struct MeetupCodecTests {
    @Test(arguments: [
        MeetupMessage.hello(version: 1, pet: bip),
        .pose(.hungry),
        .playInvite,
        .gift(.bath),
        .gameInvite,
        .gameAccept,
        .gameMove(round: 3, move: .twig),
        .gameQuit,
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
        #expect(MeetupCodec.decode(Data(#"{"type":"gift","gift":"pony"}"#.utf8)) == nil)
        #expect(MeetupCodec.decode(Data(#"{"type":"gameMove","round":0,"move":"leaf"}"#.utf8)) == nil)
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

    @Test func danceBoostOncePerPairPerDay() {
        var ledger = MeetupLedger()
        #expect(ledger.claim(pair: "a+b", at: t0, calendar: utc))
        #expect(!ledger.claim(pair: "a+b", at: t0.addingTimeInterval(3600), calendar: utc))
        #expect(ledger.claim(pair: "a+c", at: t0.addingTimeInterval(3600), calendar: utc))
        #expect(ledger.claim(pair: "a+b", at: t0.addingTimeInterval(26 * 3600), calendar: utc))
    }

    @Test func threeGiftsAndThreeGamesPerPairPerDay() {
        var ledger = MeetupLedger()
        for _ in 0..<MeetupLedger.giftsPerPairPerDay { #expect(ledger.claimGift(pair: "a+b", at: t0, calendar: utc)) }
        #expect(!ledger.claimGift(pair: "a+b", at: t0, calendar: utc))
        #expect(ledger.claimGift(pair: "a+c", at: t0, calendar: utc))
        for _ in 0..<MeetupLedger.gamesPerPairPerDay { #expect(ledger.claimGame(pair: "a+b", at: t0, calendar: utc)) }
        #expect(!ledger.claimGame(pair: "a+b", at: t0, calendar: utc))
        #expect(ledger.claimGift(pair: "a+b", at: t0.addingTimeInterval(26 * 3600), calendar: utc))
        // Old days are dropped.
        #expect(ledger.usage.count == 1)
    }

    @Test func oldLedgersStillDecode() throws {
        let old = Data(#"{"lastBoost":{"a+b":"2026-10-17"}}"#.utf8)
        let ledger = try JSONDecoder().decode(MeetupLedger.self, from: old)
        #expect(ledger.lastBoost == ["a+b": "2026-10-17"])
        #expect(ledger.usage.isEmpty)
    }

    @Test func boostAndGiftsSave() {
        let store = InMemoryPetStore(PetState(hunger: 0.5, happiness: 0.5, hygiene: 0.5, bornAt: t0))
        var session = PetSession(store: store, now: t0)
        let before = store.saveCount
        #expect(session.playedWithFriend(at: t0) == .applied)
        #expect(session.state.happiness > 0.6)
        #expect(session.received(.snack, at: t0) == .applied)
        #expect(session.state.hunger < 0.4)
        #expect(session.received(.bath, at: t0) == .applied)
        #expect(session.state.hygiene > 0.6)
        #expect(store.saveCount == before + 3)
    }

    @Test func asleepPetsDontTakeGifts() {
        var engine = PetEngine(state: PetState(isAsleep: true, bornAt: t0))
        #expect(engine.receive(.toy, at: t0) == .refused(.asleep))
    }
}

@Suite("Leaf, Pebble, Twig")
struct PebbleGameTests {
    /// Two games passing messages straight to each other.
    private func play(_ a: inout PebbleGame, _ b: inout PebbleGame, aMoves: [GameMove], bMoves: [GameMove]) {
        for m in a.invite() { b.receive(m) }
        for m in b.accept() { a.receive(m) }
        for (ma, mb) in zip(aMoves, bMoves) {
            for m in a.choose(ma) { b.receive(m) }
            for m in b.choose(mb) { a.receive(m) }
        }
    }

    @Test func rules() {
        #expect(GameMove.leaf.beats(.pebble))
        #expect(GameMove.pebble.beats(.twig))
        #expect(GameMove.twig.beats(.leaf))
        #expect(!GameMove.leaf.beats(.leaf))
        #expect(!GameMove.pebble.beats(.leaf))
    }

    @Test func firstToTwoWins() {
        var a = PebbleGame(), b = PebbleGame()
        play(&a, &b, aMoves: [.leaf, .twig, .leaf], bMoves: [.pebble, .twig, .pebble])
        // Round 1 a wins, round 2 tie, round 3 a wins.
        #expect(a.phase == .finished(won: true))
        #expect(b.phase == .finished(won: false))
        #expect(a.myWins == 2 && a.theirWins == 0)
        #expect(b.lastRound?.iWon == false)
    }

    @Test func theirMoveIsHiddenUntilIChoose() {
        var a = PebbleGame(), b = PebbleGame()
        play(&a, &b, aMoves: [], bMoves: [])
        for m in b.choose(.twig) { a.receive(m) }
        #expect(a.lastRound == nil)
        _ = a.choose(.leaf)
        #expect(a.lastRound == PebbleGame.RoundResult(round: 1, mine: .leaf, theirs: .twig, iWon: false))
    }

    @Test func movesArrivingEarlyAreKept() {
        var a = PebbleGame()
        a.receive(.gameInvite)
        a.receive(.gameMove(round: 1, move: .leaf))
        _ = a.accept()
        _ = a.choose(.pebble)
        #expect(a.lastRound?.iWon == false)
        // The peer's round-2 move lands before ours.
        a.receive(.gameMove(round: 2, move: .twig))
        _ = a.choose(.pebble)
        #expect(a.lastRound == PebbleGame.RoundResult(round: 2, mine: .pebble, theirs: .twig, iWon: true))
    }

    @Test func bothInvitingAtOnceStartsTheGame() {
        var a = PebbleGame()
        _ = a.invite()
        a.receive(.gameInvite)
        #expect(a.phase == .playing(round: 1, mine: nil, theirs: nil))
    }

    @Test func quitStopsEitherSide() {
        var a = PebbleGame(), b = PebbleGame()
        play(&a, &b, aMoves: [.leaf], bMoves: [.twig])
        for m in a.quit() { b.receive(m) }
        #expect(a.phase == .idle && b.phase == .idle)
        #expect(!a.isRunning)
        #expect(a.quit().isEmpty)
    }

    @Test func cantChooseTwiceInARound() {
        var a = PebbleGame()
        a.receive(.gameInvite)
        _ = a.accept()
        #expect(!a.choose(.leaf).isEmpty)
        #expect(a.choose(.twig).isEmpty)
    }
}

@Suite("Pal book")
struct PalBookTests {
    @Test func meetingAgainMovesToTheTop() {
        var book = PalBook()
        book.met(bip, key: "a+b", at: t0)
        book.met(moss, key: "a+c", at: t0.addingTimeInterval(60))
        book.met(PetCard(name: "Bip", stage: .grown, mood: .joyful), key: "a+b", at: t0.addingTimeInterval(120))
        #expect(book.pals.map(\.id) == ["a+b", "a+c"])
        #expect(book.pal("a+b")?.timesMet == 2)
        #expect(book.pal("a+b")?.card.stage == .grown)
        #expect(book.pal("a+b")?.firstMet == t0)
    }

    @Test func gamesAreCountedAndTheBookIsCapped() throws {
        var book = PalBook()
        for i in 0..<(PalBook.capacity + 5) {
            book.met(PetCard(name: "P\(i)", stage: .young, mood: .content), key: "k\(i)", at: t0.addingTimeInterval(Double(i)))
        }
        #expect(book.pals.count == PalBook.capacity)
        #expect(book.pals.first?.id == "k\(PalBook.capacity + 4)")
        book.recordGame(with: "k\(PalBook.capacity + 4)", won: true)
        book.recordGame(with: "k\(PalBook.capacity + 4)", won: false)
        #expect(book.pals.first?.gamesWon == 1 && book.pals.first?.gamesLost == 1)
        let data = try JSONEncoder().encode(book)
        #expect(try JSONDecoder().decode(PalBook.self, from: data) == book)
    }
}

@Suite("Share card")
struct ShareCardTests {
    @Test func cardIsScaledWithHardEdges() {
        let card = ShareCard.render(.sample(mood: .joyful, stage: .young), scale: 4)
        #expect(card.width == ShareCard.width * 4)
        #expect(card.height == ShareCard.height * 4)
        #expect(card.bytes.count == card.width * card.height * 4)
        // Each card pixel is a 4 by 4 block of one colour.
        #expect(card.pixel(x: 200, y: 200) == card.pixel(x: 201, y: 202) || 200 % 4 == 3)
    }

    @Test func petAndNameAreDrawn() {
        let p = RetroPalette.daylight
        let card = ShareCard.render(.sample(mood: .content, stage: .grown), palette: p, scale: 1)
        let lcd = RGBAImage.tuple(p.lcd)
        let ink = RGBAImage.tuple(p.backdropInk)
        var spritePixels = 0, namePixels = 0
        for y in 14..<86 { for x in 24..<96 where card.pixel(x: x, y: y) != lcd && card.pixel(x: x, y: y) != RGBAImage.tuple(p.lcdGhost) { spritePixels += 1 } }
        for y in 112..<126 { for x in 0..<ShareCard.width where card.pixel(x: x, y: y) == ink { namePixels += 1 } }
        #expect(spritePixels > 300)
        #expect(namePixels > 40)
        #expect(card.pixel(x: 0, y: 0) == RGBAImage.tuple(p.backdropTop))
    }

    @Test func longNamesAreShortened() {
        #expect(ShareCard.fitting("Bip", scale: 2) == "BIP")
        let long = ShareCard.fitting("Professor Wattlebottom", scale: 2)
        #expect(long.hasSuffix("."))
        #expect(long.count <= 9)
    }

    @Test func captionIsKindAndPrivate() {
        let text = ShareCard.caption(for: .sample(mood: .hungry, stage: .young))
        #expect(text.contains("Bip"))
        #expect(text.contains("day 2"))
        #expect(!text.contains("@"))
    }
}
