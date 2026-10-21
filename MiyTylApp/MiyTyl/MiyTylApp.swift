import SwiftUI

@main
struct MiyTylApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .tint(AppColor.blue)
        }
    }
}
