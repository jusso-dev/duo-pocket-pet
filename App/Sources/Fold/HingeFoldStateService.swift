import Foundation
import PocketPetCore
import SwiftUI

// The only file in the app that touches Apple's hinge API.
//
// Verified names (iOS 27.1), from Apple's tech talk
// https://developer.apple.com/videos/play/tech-talks/111464/ and
// https://developer.apple.com/documentation/swiftui/devicehinge :
//   View.onHingeChange(isEnabled:_:) { oldContext, newContext in ... }
//   DeviceHingeContext.hinge: DeviceHinge?   (nil means no hinge)
//   DeviceHinge.angle: Angle                 (SwiftUI Angle; UIKit's UIHinge.angle is radians)
//   DeviceHinge.status: DeviceHinge.Status   (.closed, .partiallyOpen, .fullyOpen)
//
// TODO(verify in Xcode): confirm the DeviceHinge.Status case names against the
// iOS 27.1 SDK headers. `.partiallyOpen` appears in Apple's sample code; the
// other two come from the docs.

/// Feeds hinge readings into a `FoldStateService` the rest of the app can observe.
/// Starts as `.unavailable` until the first hinge callback arrives.
final class HingeFoldStateService: BroadcastFoldStateService, @unchecked Sendable {
    private let filterLock = NSLock()
    private var filter = FoldPostureFilter(threshold: 2)

    init() {
        super.init(initial: .unavailable)
    }

    /// Called by `HingeReader` with each new reading. Nil means no hinge.
    func ingest(_ reading: HingeReading?) {
        let posture = FoldPosture(reading: reading)
        let accepted = filterLock.withLock { filter.accept(posture) }
        if let accepted { send(accepted) }
    }
}

/// Attach once, near the root, to drive a `HingeFoldStateService`.
/// On iOS earlier than 27.1 it reports "no hinge" once and does nothing else.
struct HingeReader: ViewModifier {
    let service: HingeFoldStateService

    @ViewBuilder
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
            // .partiallyOpen, and any status Apple adds later, use the live angle.
            status = .partiallyOpen
        }
        self.init(status: status, angleDegrees: hinge.angle.degrees)
    }
}
