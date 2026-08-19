import SwiftUI

@main
struct FoodMapApp: App {
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            MapScreen(dependencies: dependencies)
                .tint(Theme.lacquer)
                .preferredColorScheme(nil) // follow the device; both themes are designed
        }
    }
}
