import SwiftUI

@main
struct CangJieApp: App {
    @StateObject private var model = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
        .onChange(of: scenePhase) { phase in
            model.handleScenePhase(phase)
        }
    }
}
