import Foundation
import UserNotifications

enum AgentTaskNotificationKind: String, CaseIterable, Equatable {
    case completed
    case waitingUser
    case paused
    case failed
    case costLimit
    case majorStoryGate
}

enum AgentTaskNotificationConsentDecision: String, Equatable {
    case undecided
    case allowed
    case declined
}

struct AgentTaskNotificationRequest: Equatable {
    let id: String
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
            body = "这件事已在费用上限前暂停，等待你确认。"
        case .majorStoryGate:
            body = "故事推进到了需要你决定的位置。"
        }
    }
}

@MainActor
protocol AgentTaskNotificationScheduling: AnyObject {
    func requestAuthorization() async throws -> Bool
    func schedule(_ request: AgentTaskNotificationRequest) async throws
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
    private let center: UNUserNotificationCenter
    private let deliveryStore: any AgentTaskNotificationDeliveryStoring

    init(
        center: UNUserNotificationCenter? = nil,
        deliveryStore: (any AgentTaskNotificationDeliveryStoring)? = nil
    ) {
        self.center = center ?? .current()
        self.deliveryStore = deliveryStore
            ?? UserDefaultsAgentTaskNotificationDeliveryStore()
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func schedule(_ request: AgentTaskNotificationRequest) async throws {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
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
            try await center.add(
                UNNotificationRequest(
                    identifier: request.id,
                    content: content,
                    trigger: nil
                )
            )
        } catch {
            deliveryStore.release(request.id)
            throw error
        }
    }
}
