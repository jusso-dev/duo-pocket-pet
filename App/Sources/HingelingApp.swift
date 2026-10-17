import PocketPetCore
import SwiftUI

@main
struct HingelingApp: App {
    @State private var model = AppModel.live()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}
