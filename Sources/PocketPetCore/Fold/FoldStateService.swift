/// A source of fold postures. The app target provides the real one, which wraps
/// Apple's hinge API. Tests and previews use `MockFoldStateService`.
public protocol FoldStateService {
    /// The latest known posture.
    var current: FoldPosture { get }
    /// A new stream on each access. It yields `current` first, then every change.
    var updates: AsyncStream<FoldPosture> { get }
}

/// A service that never changes. Used for previews and for iOS versions
/// without the hinge API, where it reports `.unavailable`.
public struct StaticFoldStateService: FoldStateService, Sendable {
    public let current: FoldPosture

    public init(_ posture: FoldPosture = .unavailable) {
        current = posture
    }

    public var updates: AsyncStream<FoldPosture> {
        let posture = current
        return AsyncStream { continuation in
            continuation.yield(posture)
            continuation.finish()
        }
    }
}
