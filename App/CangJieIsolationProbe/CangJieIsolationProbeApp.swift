import SwiftUI

@main
struct CangJieIsolationProbeApp: App {
    @StateObject private var model = IsolationProbeViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            IsolationProbeView(model: model)
        }
        .onChange(of: scenePhase) { phase in
            model.handleScenePhase(phase)
        }
    }
}
