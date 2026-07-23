import SwiftUI

@main
@MainActor
struct CangJieApp: App {
    @StateObject private var model: AppViewModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        if let fixtureModel = CangJieUITestFixtureBootstrap.makeViewModelIfRequested() {
            _model = StateObject(wrappedValue: fixtureModel)
            return
        }
        #endif

        _model = StateObject(
            wrappedValue: AppViewModel(
                networkAvailabilityObserver: NetworkPathAvailabilityObserver(),
                bundleIdentityLoader: MainBundleBuildIdentityLoader()
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
        .onChange(of: scenePhase) { phase in
            model.handleScenePhase(phase)
        }
    }
}
