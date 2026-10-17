import CoreGraphics
import PocketPetCore
import SwiftUI

/// Shares a pixel-art card of the pet through the share sheet: Messages,
/// AirDrop, social apps. Only the pet's name, life stage, day and mood.
///
/// Takes only what the card shows, so it isn't redrawn on every meter tick.
struct ShareCardButton: View {
    let name: String
    let stage: LifeStage
    let mood: Mood
    let day: Int
    let state: PetState

    init(state: PetState) {
        name = state.name
        stage = state.lifeStage
        mood = state.mood
        day = Int(state.ageSeconds / 86_400) + 1
        self.state = state
    }

    nonisolated static func == (lhs: ShareCardButton, rhs: ShareCardButton) -> Bool {
        lhs.name == rhs.name && lhs.stage == rhs.stage && lhs.mood == rhs.mood && lhs.day == rhs.day
    }

    var body: some View {
        if let image = Self.image(for: state) {
            ShareLink(
                item: image,
                subject: Text("Meet \(name)"),
                message: Text(ShareCard.caption(for: state)),
                preview: SharePreview("\(name) the Hingeling", image: image)
            ) {
                KeycapLabel(title: "Share", icon: .share)
            }
            .buttonStyle(KeycapButtonStyle())
            .accessibilityLabel("Share \(name)")
            .accessibilityHint("Shares a picture card of your pet")
        }
    }

    /// The card as a SwiftUI image, four screen pixels to a card pixel.
    static func image(for state: PetState) -> Image? {
        let card = ShareCard.render(state, scale: 4)
        guard
            let provider = CGDataProvider(data: Data(card.bytes) as CFData),
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let cg = CGImage(
                width: card.width,
                height: card.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: card.width * 4,
                space: space,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else { return nil }
        return Image(decorative: cg, scale: 1)
    }
}

extension ShareCardButton: Equatable {}
