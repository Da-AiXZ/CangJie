import Foundation
import UIKit
import UserNotifications

enum AgentTaskNotificationKind: String, CaseIterable, Equatable, Sendable {
    case completed
    case waitingUser
    case paused
    case failed
    case costLimit
    case majorStoryGate
}

enum AgentTaskNotificationConsentDecision: String, Equatable, Sendable {
    case undecided
    case allowed
    case declined
}

@MainActor
protocol AgentTaskBackgroundExecutionProtecting: AnyObject {
    func protect(
        name: String,
        operation: @escaping @MainActor @Sendable () async -> Void
    )
}

@MainActor
final class UIApplicationAgentTaskBackgroundExecutionProtector:
    AgentTaskBackgroundExecutionProtecting
{
    func protect(
        name: String,
        operation: @escaping @MainActor @Sendable () async -> Void
    ) {
        let lease = UIApplicationBackgroundTaskLease()
        let identifier = UIApplication.shared.beginBackgroundTask(
            withName: name
        ) { [weak lease] in
            Task { @MainActor in
                lease?.end()
            }
        }
        lease.activate(identifier)
        Task { @MainActor in
            await operation()
            lease.end()
        }
    }
}

@MainActor
private final class UIApplicationBackgroundTaskLease {
    private var identifier = UIBackgroundTaskIdentifier.invalid
    private var didEnd = false

    func activate(_ identifier: UIBackgroundTaskIdentifier) {
        guard !didEnd else {
            if identifier != .invalid {
                UIApplication.shared.endBackgroundTask(identifier)
            }
            return
        }
        self.identifier = identifier
    }

    func end() {
        guard !didEnd else { return }
        didEnd = true
        let activeIdentifier = identifier
        identifier = .invalid
        if activeIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(activeIdentifier)
        }
    }
}

struct AgentTaskNotificationRequest: Equatable, Sendable {
    let id: String
    let notificationID: String
    let taskID: UUID
    let taskRevision: Int
    let kind: AgentTaskNotificationKind
    let title: String
    let body: String

    init(
        task: AgentTaskSnapshot,
        kind: AgentTaskNotificationKind
    ) {
        id = [
            "cangjie.task",
            task.id.uuidString.lowercased(),
            String(task.revision),
            kind.rawValue
        ].joined(separator: ".")
        notificationID = Self.notificationID(for: task.id)
        taskID = task.id
        taskRevision = task.revision
        self.kind = kind
        title = "仓颉"
        switch kind {
        case .completed:
            body = "这件事已经处理完成，结果已安全保存。"
        case .waitingUser:
            body = "这件事需要你查看并确认下一步。"
        case .paused:
            body = "这件事已经安全暂停。"
        case .failed:
            body = "这件事没有完成，原请求仍然保留。"
        case .costLimit:
            body = "这件事已在预算或用量边界前暂停，等待你确认。"
        case .majorStoryGate:
            body = "故事推进到了需要你决定的位置。"
        }
    }

    static func notificationID(for taskID: UUID) -> String {
        [
            "cangjie.task",
            taskID.uuidString.lowercased()
        ].joined(separator: ".")
    }
}

@MainActor
protocol AgentTaskNotificationScheduling: AnyObject {
    func requestAuthorization() async throws -> Bool
    func schedule(_ request: AgentTaskNotificationRequest) async throws
    func cancelPendingNotification(for taskID: UUID, throughRevision: Int)
}

@MainActor
protocol AgentTaskNotificationConsentStoring: AnyObject {
    var decision: AgentTaskNotificationConsentDecision { get }
    func setDecision(_ decision: AgentTaskNotificationConsentDecision)
}

@MainActor
protocol AgentTaskNotificationDeliveryStoring: AnyObject {
    func claim(_ identifier: String) -> Bool
    func release(_ identifier: String)
}

@MainActor
protocol AgentTaskUserNotificationCenter: AnyObject {
    func requestAuthorization() async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

@MainActor
private final class SystemAgentTaskUserNotificationCenter:
    AgentTaskUserNotificationCenter
{
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter) {
        self.center = center
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

@MainActor
final class UserDefaultsAgentTaskNotificationConsentStore:
    AgentTaskNotificationConsentStoring
{
    private static let key = "agentTaskNotificationConsentDecision.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var decision: AgentTaskNotificationConsentDecision {
        guard let rawValue = defaults.string(forKey: Self.key) else {
            return .undecided
        }
        return AgentTaskNotificationConsentDecision(rawValue: rawValue)
            ?? .undecided
    }

    func setDecision(_ decision: AgentTaskNotificationConsentDecision) {
        defaults.set(decision.rawValue, forKey: Self.key)
    }
}

@MainActor
final class UserDefaultsAgentTaskNotificationDeliveryStore:
    AgentTaskNotificationDeliveryStoring
{
    private static let key = "agentTaskNotificationDeliveredIDs.v1"
    private static let maximumRememberedIDs = 512
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func claim(_ identifier: String) -> Bool {
        let remembered = defaults.stringArray(forKey: Self.key) ?? []
        guard !remembered.contains(identifier) else { return false }
        let updated = Array(
            (remembered + [identifier]).suffix(Self.maximumRememberedIDs)
        )
        defaults.set(updated, forKey: Self.key)
        return true
    }

    func release(_ identifier: String) {
        let remembered = defaults.stringArray(forKey: Self.key) ?? []
        defaults.set(
            remembered.filter { $0 != identifier },
            forKey: Self.key
        )
    }
}

@MainActor
final class UserNotificationAgentTaskScheduler:
    AgentTaskNotificationScheduling
{
    private let center: any AgentTaskUserNotificationCenter
    private let deliveryStore: any AgentTaskNotificationDeliveryStoring
    private var latestGenerationByTaskID: [UUID: UUID] = [:]
    private var highestRevisionByTaskID: [UUID: Int] = [:]
    private var cancelledThroughRevisionByTaskID: [UUID: Int] = [:]
    private var schedulingOperations: [UUID: Task<Void, Error>] = [:]
    private var schedulingOperationGenerations: [UUID: UUID] = [:]

    init(
        center: UNUserNotificationCenter? = nil,
        deliveryStore: (any AgentTaskNotificationDeliveryStoring)? = nil
    ) {
        self.center = SystemAgentTaskUserNotificationCenter(
            center: center ?? .current()
        )
        self.deliveryStore = deliveryStore
            ?? UserDefaultsAgentTaskNotificationDeliveryStore()
    }

    init(
        centerAdapter: any AgentTaskUserNotificationCenter,
        deliveryStore: any AgentTaskNotificationDeliveryStoring
    ) {
        center = centerAdapter
        self.deliveryStore = deliveryStore
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization()
    }

    func schedule(_ request: AgentTaskNotificationRequest) async throws {
        let cancelledThrough = cancelledThroughRevisionByTaskID[request.taskID]
            ?? Int.min
        let highestRevision = highestRevisionByTaskID[request.taskID]
            ?? Int.min
        guard request.taskRevision > cancelledThrough,
              request.taskRevision >= highestRevision else {
            return
        }
        highestRevisionByTaskID[request.taskID] = request.taskRevision
        let generation = UUID()
        let previous = schedulingOperations[request.taskID]
        latestGenerationByTaskID[request.taskID] = generation
        previous?.cancel()
        let operation = Task { @MainActor [weak self] in
            if let previous {
                _ = try? await previous.value
            }
            guard let self,
                  self.latestGenerationByTaskID[request.taskID] == generation else {
                return
            }
            try Task.checkCancellation()
            try await self.performSchedule(request, generation: generation)
        }
        schedulingOperations[request.taskID] = operation
        schedulingOperationGenerations[request.taskID] = generation
        defer {
            if schedulingOperationGenerations[request.taskID] == generation {
                schedulingOperations[request.taskID] = nil
                schedulingOperationGenerations[request.taskID] = nil
            }
        }
        try await operation.value
    }

    private func performSchedule(
        _ request: AgentTaskNotificationRequest,
        generation: UUID
    ) async throws {
        let authorizationStatus = await center.authorizationStatus()
        try Task.checkCancellation()
        guard latestGenerationByTaskID[request.taskID] == generation else {
            return
        }
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        case .notDetermined, .denied:
            return
        @unknown default:
            return
        }
        guard deliveryStore.claim(request.id) else { return }
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        do {
            center.removePendingNotificationRequests(
                withIdentifiers: [request.notificationID]
            )
            try Task.checkCancellation()
            guard latestGenerationByTaskID[request.taskID] == generation else {
                deliveryStore.release(request.id)
                return
            }
            try await center.add(
                UNNotificationRequest(
                    identifier: request.notificationID,
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(
                        timeInterval: 1,
                        repeats: false
                    )
                )
            )
            guard !Task.isCancelled,
                  latestGenerationByTaskID[request.taskID] == generation else {
                center.removePendingNotificationRequests(
                    withIdentifiers: [request.notificationID]
                )
                deliveryStore.release(request.id)
                return
            }
        } catch {
            center.removePendingNotificationRequests(
                withIdentifiers: [request.notificationID]
            )
            deliveryStore.release(request.id)
            throw error
        }
    }

    func cancelPendingNotification(for taskID: UUID, throughRevision: Int) {
        let highestRevision = highestRevisionByTaskID[taskID] ?? Int.min
        guard throughRevision >= highestRevision else { return }
        highestRevisionByTaskID[taskID] = max(highestRevision, throughRevision)
        let cancelledThrough = cancelledThroughRevisionByTaskID[taskID]
            ?? Int.min
        cancelledThroughRevisionByTaskID[taskID] = max(
            cancelledThrough,
            throughRevision
        )
        latestGenerationByTaskID[taskID] = UUID()
        schedulingOperations[taskID]?.cancel()
        center.removePendingNotificationRequests(
            withIdentifiers: [
                AgentTaskNotificationRequest.notificationID(for: taskID)
            ]
        )
    }
}
