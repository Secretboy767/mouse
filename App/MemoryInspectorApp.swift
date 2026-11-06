import SwiftUI

@main
struct MemoryInspectorApp: App {
    @StateObject private var inspector = InspectorStore()

    var body: some Scene {
        WindowGroup {
            MainInterface()
                .environmentObject(inspector)
                .preferredColorScheme(.dark)
        }
    }
}
