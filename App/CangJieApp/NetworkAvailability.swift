import Dispatch
import Foundation
import Network

enum NetworkAvailabilityState: Equatable, Sendable {
    case checking
    case available
    case unavailable
}

private final class NetworkAvailabilitySnapshot: @unchecked Sendable {
    private let lock = NSLock()
    private var storedState = NetworkAvailabilityState.checking

    var state: NetworkAvailabilityState {
        lock.withLock { storedState }
    }

    func store(_ state: NetworkAvailabilityState) {
        lock.withLock {
            storedState = state
        }
    }
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
    private let snapshot = NetworkAvailabilitySnapshot()
    private let queue = DispatchQueue(
        label: "com.juyang.CangJie.network-availability"
    )
    private var handler: ((NetworkAvailabilityState) -> Void)?
    private var deliveredState = NetworkAvailabilityState.checking
    var state: NetworkAvailabilityState { snapshot.state }
    private var isStarted = false

    func start(
        _ handler: @escaping (NetworkAvailabilityState) -> Void
    ) {
        self.handler = handler
        guard !isStarted else { return }
        isStarted = true
        let snapshot = snapshot
        monitor.pathUpdateHandler = { [weak self, snapshot] path in
            let updated: NetworkAvailabilityState = path.status == .satisfied
                ? .available
                : .unavailable
            snapshot.store(updated)
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
        guard deliveredState != updated else { return }
        deliveredState = updated
        handler?(updated)
    }
}
