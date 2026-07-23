import Dispatch
import Foundation
import Network

enum NetworkAvailabilityState: Equatable, Sendable {
    case checking
    case available
    case unavailable
}

@MainActor
protocol NetworkAvailabilityObserving: AnyObject {
    var state: NetworkAvailabilityState { get }

    func start(
        _ handler: @escaping (NetworkAvailabilityState) -> Void
    )
    func stop()
}

@MainActor
final class AssumedAvailableNetworkAvailabilityObserver:
    NetworkAvailabilityObserving
{
    let state = NetworkAvailabilityState.available

    func start(
        _ handler: @escaping (NetworkAvailabilityState) -> Void
    ) {}

    func stop() {}
}

@MainActor
final class NetworkPathAvailabilityObserver: NetworkAvailabilityObserving {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(
        label: "com.juyang.CangJie.network-availability"
    )
    private var handler: ((NetworkAvailabilityState) -> Void)?
    private(set) var state = NetworkAvailabilityState.checking
    private var isStarted = false

    func start(
        _ handler: @escaping (NetworkAvailabilityState) -> Void
    ) {
        self.handler = handler
        guard !isStarted else { return }
        isStarted = true
        monitor.pathUpdateHandler = { [weak self] path in
            let updated: NetworkAvailabilityState = path.status == .satisfied
                ? .available
                : .unavailable
            Task { @MainActor [weak self] in
                self?.receive(updated)
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        monitor.pathUpdateHandler = nil
        monitor.cancel()
        handler = nil
    }

    private func receive(_ updated: NetworkAvailabilityState) {
        guard state != updated else { return }
        state = updated
        handler?(updated)
    }
}
