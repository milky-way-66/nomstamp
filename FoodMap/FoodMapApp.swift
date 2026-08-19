import SwiftUI

@main
struct FoodMapApp: App {
    @State private var dependencies = AppDependencies()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            let appearance = dependencies.appearanceStore.appearance

            MapScreen(dependencies: dependencies)
                .tint(Theme.visitedInk)
                // Light and dark follow the sun where the reader is standing, not the system
                // setting: someone at a night market at nine has the lights down (ADR-006).
                .preferredColorScheme(appearance.colorScheme)
                // `Theme`'s accents are read as stored values by every view that draws chrome, so
                // a new skin has to rebuild the tree rather than invalidate a binding. Re-inking
                // the press is a once-a-day event, which is what makes that affordable.
                .id(appearance.skin)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.4), value: appearance.skin)
                .environment(\.skyEffect, appearance.effect)
                .task { await dependencies.appearanceStore.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    // Between two sessions it can have started raining, or got dark.
                    guard phase == .active else { return }
                    Task { await dependencies.appearanceStore.refresh() }
                }
        }
    }
}
