/// How the phone is folded, as the app cares about it.
///
/// This is our own type, not an Apple API. The app target maps Apple's
/// `DeviceHinge` (via `onHingeChange`) into it. See `HingeReading`.
/// The same shape is used across the Duo toy apps.
public enum FoldPosture: Equatable, Sendable {
    /// Folded shut. The app is on the outer display.
    case closed
    /// Partly open, like a book or a tent. 0 is shut and 180 is flat.
    case partiallyOpen(angleDegrees: Double)
    /// Fully open. The app is on the inner display.
    case open
    /// No hinge on this device (any standard iPhone), or hinge data is unavailable.
    case unavailable

    public var hasHinge: Bool { self != .unavailable }

    public var angleDegrees: Double? {
        switch self {
        case .closed: 0
        case .partiallyOpen(let angle): angle
        case .open: 180
        case .unavailable: nil
        }
    }

    /// True when both postures are the same kind, ignoring the angle.
    public func isSameKind(as other: FoldPosture) -> Bool {
        switch (self, other) {
        case (.closed, .closed), (.open, .open), (.unavailable, .unavailable), (.partiallyOpen, .partiallyOpen): true
        default: false
        }
    }
}
