/// A platform-free copy of the data Apple's hinge API gives us.
///
/// Verified against Apple's tech talk "Leverage multiple displays and scenes on
/// iPhone Duo" (https://developer.apple.com/videos/play/tech-talks/111464/):
/// SwiftUI's `onHingeChange` passes a `DeviceHingeContext` whose `hinge` is a
/// `DeviceHinge?` (nil on devices without a hinge), with `angle: Angle` and a
/// status of closed, partially open or fully open.
///
/// The app target converts `DeviceHinge` into this type, so all the mapping
/// logic below can be tested on Linux.
public struct HingeReading: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case closed
        case partiallyOpen
        case fullyOpen
    }

    public var status: Status
    public var angleDegrees: Double

    public init(status: Status, angleDegrees: Double) {
        self.status = status
        self.angleDegrees = angleDegrees
    }
}

extension FoldPosture {
    /// Maps a hinge reading to a posture. `nil` (no hinge) gives `.unavailable`.
    public init(reading: HingeReading?) {
        guard let reading else {
            self = .unavailable
            return
        }
        switch reading.status {
        case .closed: self = .closed
        case .fullyOpen: self = .open
        case .partiallyOpen:
            let angle = reading.angleDegrees.isFinite ? reading.angleDegrees : 90
            self = .partiallyOpen(angleDegrees: min(180, max(0, angle)))
        }
    }
}

/// Drops partially-open updates whose angle moved less than `threshold`
/// degrees since the last emitted one, so a wobbly hand does not flood the UI.
/// Changes of kind (closed, open, half fold, no hinge) always pass.
public struct FoldPostureFilter: Sendable {
    public let threshold: Double
    public private(set) var last: FoldPosture?

    public init(threshold: Double = 2) {
        self.threshold = threshold
    }

    /// Returns the posture to emit, or nil to drop it.
    public mutating func accept(_ posture: FoldPosture) -> FoldPosture? {
        defer { if emit(posture) { last = posture } }
        return emit(posture) ? posture : nil
    }

    private func emit(_ posture: FoldPosture) -> Bool {
        guard let last else { return true }
        guard last.isSameKind(as: posture) else { return true }
        if case .partiallyOpen(let old) = last, case .partiallyOpen(let new) = posture {
            return abs(new - old) >= threshold
        }
        return false
    }
}
