import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Splits a view's bounds into the two areas either side of the fold, so
/// nothing interactive sits on it.
///
/// The app reads the fold from SwiftUI's
/// `GeometryProxy.reservedRegions(kind: .division)`, whose frames are in the
/// view's own coordinate space and already include Apple's margins. This type
/// only does the arithmetic, so it is tested on Linux.
public struct FoldSplit: Equatable, Sendable {
    public enum Axis: Equatable, Sendable {
        /// The fold runs across the view: `first` is above it, `second` below.
        case horizontal
        /// The fold runs down the view: `first` is to its left, `second` to its right.
        case vertical
    }

    public let axis: Axis
    /// Above or left of the fold.
    public let first: CGRect
    /// Below or right of the fold.
    public let second: CGRect

    /// Nil when there is no division, or it doesn't cross the bounds, in which
    /// case the view uses its normal single layout.
    ///
    /// `gutter` is the least space kept clear either side of the fold's centre
    /// line. An inactive division (phone flat) is reported with zero width, so
    /// without a gutter the two halves would touch.
    public init?(bounds: CGRect, division: CGRect?, gutter: CGFloat = 12) {
        guard let division, bounds.width > 0, bounds.height > 0 else { return nil }
        let axis: Axis = division.width >= division.height ? .horizontal : .vertical
        switch axis {
        case .horizontal:
            let mid = division.midY
            let top = min(division.minY, mid - gutter)
            let bottom = max(division.maxY, mid + gutter)
            guard top > bounds.minY, bottom < bounds.maxY else { return nil }
            first = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: top - bounds.minY)
            second = CGRect(x: bounds.minX, y: bottom, width: bounds.width, height: bounds.maxY - bottom)
        case .vertical:
            let mid = division.midX
            let left = min(division.minX, mid - gutter)
            let right = max(division.maxX, mid + gutter)
            guard left > bounds.minX, right < bounds.maxX else { return nil }
            first = CGRect(x: bounds.minX, y: bounds.minY, width: left - bounds.minX, height: bounds.height)
            second = CGRect(x: right, y: bounds.minY, width: bounds.maxX - right, height: bounds.height)
        }
        self.axis = axis
    }
}
