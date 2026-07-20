import Foundation

public enum S1ActivityDestination: String, CaseIterable, Hashable, Sendable {
    case conversation
    case novels
    case tasks
    case settings
}

public enum S1ActivityIconRole: String, CaseIterable, Hashable, Sendable {
    case conversation
    case library
    case taskQueue
    case settings
}

public struct S1ActivityItem: Equatable, Hashable, Sendable {
    public let destination: S1ActivityDestination
    public let iconRole: S1ActivityIconRole
    public let title: String
    public let purpose: String

    public init(
        destination: S1ActivityDestination,
        iconRole: S1ActivityIconRole,
        title: String,
        purpose: String
    ) {
        self.destination = destination
        self.iconRole = iconRole
        self.title = title
        self.purpose = purpose
    }
}

public enum S1ActivityBarContract {
    public static let visibleItems: [S1ActivityItem] = [
        S1ActivityItem(
            destination: .conversation,
            iconRole: .conversation,
            title: "仓颉",
            purpose: "和仓颉对话，查看和切换已保存的对话"
        ),
        S1ActivityItem(
            destination: .novels,
            iconRole: .library,
            title: "我的小说",
            purpose: "浏览已经真实保存的小说和当前信息"
        ),
        S1ActivityItem(
            destination: .tasks,
            iconRole: .taskQueue,
            title: "AI 任务",
            purpose: "查看真实任务状态；没有任务时显示诚实空状态"
        ),
        S1ActivityItem(
            destination: .settings,
            iconRole: .settings,
            title: "设置",
            purpose: "管理当前阶段已经真正生效的界面设置"
        )
    ]
}
