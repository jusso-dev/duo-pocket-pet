import PocketPetCore
import SwiftUI

/// Every iPhone without a hinge: the home screen plus a bedtime button that
/// stands in for closing the phone.
struct StandardHomeView: View {
    let model: AppModel

    var body: some View {
        HomeView(model: model, showsBedtime: true)
    }
}
