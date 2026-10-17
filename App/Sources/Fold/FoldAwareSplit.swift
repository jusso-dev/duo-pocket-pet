import PocketPetCore
import SwiftUI

/// Lays out two views either side of the fold, or falls back to a single
/// layout when there's no fold to avoid.
///
/// The fold comes from `GeometryProxy.reservedRegions(kind: .division)`, which
/// is iOS 27.1 and later. Earlier systems and phones without a hinge always get
/// the fallback. `includeInactive` also counts a division while the phone lies
/// flat (Apple reports it with zero width), which keeps controls off the crease
/// on a fully open phone too.
struct FoldAwareSplit<First: View, Second: View, Fallback: View>: View {
    var includeInactive = false
    @ViewBuilder let first: (FoldSplit.Axis) -> First
    @ViewBuilder let second: (FoldSplit.Axis) -> Second
    @ViewBuilder let fallback: () -> Fallback

    var body: some View {
        GeometryReader { proxy in
            let bounds = CGRect(origin: .zero, size: proxy.size)
            if let split = FoldSplit(bounds: bounds, division: Self.division(in: proxy, includeInactive: includeInactive)) {
                ZStack(alignment: .topLeading) {
                    place(first(split.axis), in: split.first)
                    place(second(split.axis), in: split.second)
                }
            } else {
                fallback()
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    private func place(_ view: some View, in rect: CGRect) -> some View {
        view
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    /// The first division region in this view's coordinate space, if any.
    static func division(in proxy: GeometryProxy, includeInactive: Bool) -> CGRect? {
        if #available(iOS 27.1, *) {
            let regions = proxy.reservedRegions(kind: .division, options: includeInactive ? .includeInactive : [])
            return regions.map(\.frame).first
        }
        return nil
    }
}
