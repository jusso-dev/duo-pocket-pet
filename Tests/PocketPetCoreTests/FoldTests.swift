import Testing
@testable import PocketPetCore

@Suite("Fold posture mapping")
struct FoldMappingTests {
    @Test func noHingeIsUnavailable() {
        #expect(FoldPosture(reading: nil) == .unavailable)
        #expect(!FoldPosture.unavailable.hasHinge)
        #expect(FoldPosture.unavailable.angleDegrees == nil)
    }

    @Test(arguments: [
        (HingeReading(status: .closed, angleDegrees: 3), FoldPosture.closed),
        (HingeReading(status: .fullyOpen, angleDegrees: 178), FoldPosture.open),
        (HingeReading(status: .partiallyOpen, angleDegrees: 95), FoldPosture.partiallyOpen(angleDegrees: 95)),
        (HingeReading(status: .partiallyOpen, angleDegrees: -10), FoldPosture.partiallyOpen(angleDegrees: 0)),
        (HingeReading(status: .partiallyOpen, angleDegrees: 400), FoldPosture.partiallyOpen(angleDegrees: 180)),
        (HingeReading(status: .partiallyOpen, angleDegrees: .nan), FoldPosture.partiallyOpen(angleDegrees: 90)),
    ])
    func statusMapping(reading: HingeReading, expected: FoldPosture) {
        #expect(FoldPosture(reading: reading) == expected)
    }

    @Test func sameKindIgnoresAngle() {
        #expect(FoldPosture.partiallyOpen(angleDegrees: 10).isSameKind(as: .partiallyOpen(angleDegrees: 170)))
        #expect(!FoldPosture.open.isSameKind(as: .closed))
    }
}

@Suite("Fold posture filter")
struct FoldFilterTests {
    @Test func dropsSmallAngleChangesButKeepsKindChanges() {
        var filter = FoldPostureFilter(threshold: 2)
        #expect(filter.accept(.partiallyOpen(angleDegrees: 90)) != nil)
        #expect(filter.accept(.partiallyOpen(angleDegrees: 91)) == nil)
        #expect(filter.accept(.partiallyOpen(angleDegrees: 91.9)) == nil)
        #expect(filter.accept(.partiallyOpen(angleDegrees: 92.5)) == .partiallyOpen(angleDegrees: 92.5))
        #expect(filter.accept(.open) == .open)
        #expect(filter.accept(.open) == nil)
        #expect(filter.accept(.closed) == .closed)
        #expect(filter.accept(.unavailable) == .unavailable)
    }
}

@Suite("Fold services")
struct FoldServiceTests {
    @Test func staticServiceYieldsOnceAndFinishes() async {
        let service = StaticFoldStateService()
        var seen: [FoldPosture] = []
        for await posture in service.updates { seen.append(posture) }
        #expect(seen == [.unavailable])
    }

    @Test func mockFansOutToEverySubscriber() async {
        let mock = MockFoldStateService(initial: .closed)
        let a = mock.updates
        let b = mock.updates
        mock.send(.open)
        mock.send(.partiallyOpen(angleDegrees: 120))
        mock.finish()
        var seenA: [FoldPosture] = []
        for await p in a { seenA.append(p) }
        var seenB: [FoldPosture] = []
        for await p in b { seenB.append(p) }
        let expected: [FoldPosture] = [.closed, .open, .partiallyOpen(angleDegrees: 120)]
        #expect(seenA == expected)
        #expect(seenB == expected)
        #expect(mock.current == .partiallyOpen(angleDegrees: 120))
    }

    @Test func mockPlaysAScript() async {
        let mock = MockFoldStateService(initial: .open)
        await mock.play([.init(.closed), .init(.open, after: .milliseconds(5)), .init(.unavailable)])
        #expect(mock.history == [.closed, .open, .unavailable])
        #expect(mock.current == .unavailable)
    }

    @Test func cancelledStreamUnsubscribes() async {
        let mock = MockFoldStateService()
        let task = Task {
            for await _ in mock.updates {}
        }
        try? await Task.sleep(for: .milliseconds(20))
        #expect(mock.subscriberCount == 1)
        task.cancel()
        await task.value
        #expect(mock.subscriberCount == 0)
    }

    /// The live hinge service is a `BroadcastFoldStateService`. It must not keep
    /// a copy of every posture it has sent (about 90 per open and close).
    @Test func broadcastServiceKeepsNoPostureHistory() {
        let service = BroadcastFoldStateService(initial: .closed)
        for angle in 0..<1000 {
            service.send(.partiallyOpen(angleDegrees: Double(angle % 180)))
        }
        #expect(service.current == .partiallyOpen(angleDegrees: Double(999 % 180)))
        let stored = Mirror(reflecting: service).children.compactMap { $0.value as? [FoldPosture] }
        let held = stored.reduce(0) { $0 + $1.count }
        #expect(held == 0)
    }
}
