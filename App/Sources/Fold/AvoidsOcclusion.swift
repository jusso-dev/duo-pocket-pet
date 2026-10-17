import PocketPetCore
import SwiftUI

/// Keeps content clear of the cameras on iPhone Duo.
///
/// The outer camera is always reserved. The inner camera is only reported
/// while it's in use, and Apple's guidance is for UI to move aside then, so
/// this asks for active regions only and pads the content away from them.
/// Earlier systems and phones without occlusion regions get no extra padding,
/// so nothing moves on a standard iPhone.
struct AvoidsOcclusion: ViewModifier {
    @State private var insets = ReservedInsets.zero

    func body(content: Content) -> some View {
        content
            .padding(.top, insets.top)
            .padding(.leading, insets.leading)
            .padding(.bottom, insets.bottom)
            .padding(.trailing, insets.trailing)
            // Measured outside the padding, so the padding can't feed back into it.
            .onGeometryChange(for: ReservedInsets.self) { proxy in
                Self.insets(in: proxy)
            } action: { insets = $0 }
    }

    // Nonisolated: the geometry transform runs off the main actor.
    nonisolated static func insets(in proxy: GeometryProxy) -> ReservedInsets {
        if #available(iOS 27.1, *) {
            let regions = proxy.reservedRegions(kind: .occlusion).map(\.frame)
            return ReservedInsets(bounds: CGRect(origin: .zero, size: proxy.size), occlusions: regions)
        }
        return .zero
    }
}

extension View {
    /// Pads the view clear of any camera that sits over it.
    func avoidsOcclusion() -> some View {
        modifier(AvoidsOcclusion())
    }
}
