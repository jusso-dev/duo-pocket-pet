import PocketPetCore
import SwiftUI

// The only file in the app that touches Apple's hinge API.
//
// Verified names (iOS 27.1), from Apple's tech talk
// https://developer.apple.com/videos/play/tech-talks/111464/ and
// https://developer.apple.com/documentation/swiftui/devicehinge :
//   View.onHingeChange { oldContext, newContext in ... }
//   DeviceHingeContext.hinge: DeviceHinge?   (nil means no hinge)
//   DeviceHinge.angle: Angle
//   DeviceHinge.status: DeviceHinge.Status   (.partiallyOpen seen in Apple sample code)
//
// TODO(verify in Xcode): confirm the `.closed` and `.fullyOpen` case names on
// DeviceHinge.Status. They come from the docs, not from sample code.

/// Feeds hinge readings into a `FoldStateService` the rest of the app can observe.
@MainActor
final class HingeFoldStateService: FoldStateService {
    private(set) var current: FoldPosture = .unavailable
    private var filter = FoldPostureFilter(threshold: 2)
    private var continuations: [UUID: AsyncStream<FoldPosture>.Continuation] = [:]

    nonisolated init() {}

    var updates: AsyncStream<FoldPosture> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(current)
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.continuations.removeValue(forKey: id) }
            }
        }
    }

    /// Called by `HingeReader` with each new reading. Nil means no hinge.
    func ingest(_ reading: HingeReading?) {
        guard let posture = filter.accept(FoldPosture(reading: reading)) else { return }
        current = posture
        for continuation in continuations.values { continuation.yield(posture) }
    }
}

/// Attach once, near the root, to drive a `HingeFoldStateService`.
/// On iOS earlier than 27.1 it reports "no hinge" once and does nothing else.
struct HingeReader: ViewModifier {
    let service: HingeFoldStateService

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, context in
                service.ingest(HingeReading(context.hinge))
            }
        } else {
            content.onAppear { service.ingest(nil) }
        }
    }
}

extension View {
    func readsHinge(into service: HingeFoldStateService) -> some View {
        modifier(HingeReader(service: service))
    }
}

@available(iOS 27.1, *)
extension HingeReading {
    init?(_ hinge: DeviceHinge?) {
        guard let hinge else { return nil }
        let status: Status
        if hinge.status == .closed {
            status = .closed
        } else if hinge.status == .fullyOpen {
            status = .fullyOpen
        } else {
            status = .partiallyOpen
        }
        self.init(status: status, angleDegrees: hinge.angle.degrees)
    }
}
