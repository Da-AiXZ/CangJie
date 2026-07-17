import Foundation
import SwiftUI

@MainActor
final class IsolationProbeViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case running
        case completed(KeychainIsolationReport)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var buildIdentity: ProbeBuildIdentity
    private let probe: KeychainIsolationProbe
    private let buildIdentityLoader: () -> ProbeBuildIdentity

    init(
        probe: KeychainIsolationProbe = KeychainIsolationProbe(),
        buildIdentityLoader: @escaping () -> ProbeBuildIdentity = ProbeBuildIdentity.current
    ) {
        self.probe = probe
        self.buildIdentityLoader = buildIdentityLoader
        buildIdentity = buildIdentityLoader()
    }

    var isRunning: Bool {
        state == .running
    }

    func runVerification() {
        refreshBuildIdentity()
        guard !isRunning, buildIdentity.isActive else { return }
        state = .running
        state = .completed(probe.run())
    }

    func handleScenePhase(_ phase: ScenePhase) {
        refreshBuildIdentity()
    }

    private func refreshBuildIdentity() {
        buildIdentity = buildIdentityLoader()
        if !buildIdentity.isActive {
            state = .idle
        }
    }
}
