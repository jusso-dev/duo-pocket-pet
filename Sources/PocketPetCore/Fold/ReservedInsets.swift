import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// How far to inset content so nothing sits under an occlusion region, such
/// as iPhone Duo's front-facing cameras.
///
/// Apple's guidance: the outer camera is always there; the inner camera only
/// counts while it's on, and when it turns on "the UI moves aside". The app
/// reads the regions from `GeometryProxy.reservedRegions(kind: .occlusion)`;
/// this type only does the arithmetic, so it is tested on Linux.
///
/// Each region pushes content away from whichever edge of the bounds it is
/// closest to, by just enough to clear it. Regions outside the bounds (for
/// example already inside the safe area) change nothing.
public struct ReservedInsets: Equatable, Sendable {
    public var top: CGFloat
    public var leading: CGFloat
    public var bottom: CGFloat
    public var trailing: CGFloat

    public static let zero = ReservedInsets()

    public init(top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    /// Insets that keep content inside `bounds` clear of every rect in `occlusions`.
    /// `x` runs from the leading edge, as SwiftUI lays it out.
    public init(bounds: CGRect, occlusions: [CGRect]) {
        self.init()
        for region in occlusions {
            let r = region.intersection(bounds)
            guard !r.isNull, r.width > 0, r.height > 0 else { continue }
            // Distance from each edge of the bounds to the near side of the region.
            let toTop = r.minY - bounds.minY
            let toBottom = bounds.maxY - r.maxY
            let toLeading = r.minX - bounds.minX
            let toTrailing = bounds.maxX - r.maxX
            switch min(toTop, toBottom, toLeading, toTrailing) {
            case toTop: top = max(top, r.maxY - bounds.minY)
            case toBottom: bottom = max(bottom, bounds.maxY - r.minY)
            case toLeading: leading = max(leading, r.maxX - bounds.minX)
            default: trailing = max(trailing, bounds.maxX - r.minX)
            }
        }
    }

    public var isZero: Bool { self == .zero }
}
