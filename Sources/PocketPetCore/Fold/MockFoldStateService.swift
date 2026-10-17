import Foundation

/// A thread-safe fold service that pushes each `send(_:)` to every open
/// stream. The app's hinge adapter and `MockFoldStateService` build on it.
open class BroadcastFoldStateService: FoldStateService, @unchecked Sendable {
    private let lock = NSLock()
    private var _current: FoldPosture
    private var continuations: [UUID: AsyncStream<FoldPosture>.Continuation] = [:]

    public init(initial: FoldPosture) {
        _current = initial
    }

    public var current: FoldPosture {
        lock.withLock { _current }
    }

    public var subscriberCount: Int {
        lock.withLock { continuations.count }
    }

    public var updates: AsyncStream<FoldPosture> {
        AsyncStream { continuation in
            let id = UUID()
            let first: FoldPosture = lock.withLock {
                continuations[id] = continuation
                return _current
            }
            continuation.yield(first)
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                _ = self.lock.withLock { self.continuations.removeValue(forKey: id) }
            }
        }
    }

    /// Updates `current` and pushes the posture to every open stream. Keeps
    /// nothing else, so the live hinge service doesn't grow for the whole process.
    open func send(_ posture: FoldPosture) {
        let targets: [AsyncStream<FoldPosture>.Continuation] = lock.withLock {
            _current = posture
            return Array(continuations.values)
        }
        for continuation in targets { continuation.yield(posture) }
    }

    /// Ends every open stream.
    public func finish() {
        let targets: [AsyncStream<FoldPosture>.Continuation] = lock.withLock {
            defer { continuations.removeAll() }
            return Array(continuations.values)
        }
        for continuation in targets { continuation.finish() }
    }
}

/// A scriptable fold service for tests, previews and the simulator.
///
/// `send(_:)` pushes a posture to every open stream. `play(_:)` runs a script
/// of postures with delays, for demos and UI tests.
public final class MockFoldStateService: BroadcastFoldStateService, @unchecked Sendable {
    public struct Step: Sendable, Equatable {
        public var posture: FoldPosture
        public var delay: Duration

        public init(_ posture: FoldPosture, after delay: Duration = .zero) {
            self.posture = posture
            self.delay = delay
        }
    }

    private let historyLock = NSLock()
    private var _history: [FoldPosture] = []

    public override init(initial: FoldPosture = .open) {
        super.init(initial: initial)
    }

    /// Every posture sent so far, in order. Only the mock keeps this, for tests.
    public var history: [FoldPosture] {
        historyLock.withLock { _history }
    }

    public override func send(_ posture: FoldPosture) {
        historyLock.withLock { _history.append(posture) }
        super.send(posture)
    }

    /// Plays a script in order, waiting each step's delay before sending it.
    public func play(_ steps: [Step]) async {
        for step in steps {
            if step.delay > .zero { try? await Task.sleep(for: step.delay) }
            if Task.isCancelled { return }
            send(step.posture)
        }
    }

    /// A short loop used by previews and demos: closed, open, half fold, closed.
    public static let demoScript: [Step] = [
        Step(.closed),
        Step(.open, after: .seconds(3)),
        Step(.partiallyOpen(angleDegrees: 100), after: .seconds(4)),
        Step(.closed, after: .seconds(4)),
    ]
}
