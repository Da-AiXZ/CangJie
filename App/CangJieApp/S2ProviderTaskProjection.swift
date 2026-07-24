import CangJieCore
import Foundation
import GRDB

/// One read-only S2 projection shared by Conversation, AI Tasks and Results.
/// Every field comes from the same SQLite read transaction.
struct S2ProviderTaskProjection: Equatable {
    let conversationID: UUID
    let task: AgentTaskSnapshot
    let run: AgentRunSnapshot
    let request: ProviderRequestSnapshot
    let userRequest: String
    let usage: ProviderUsage?
    let budget: ProviderBudgetTaskSnapshot?
    let receipt: ToolReceipt?
    let projectTitle: String?
    let artifactTitle: String?
    let lastSafeSaveAt: Date

    var commandIdentity: AgentTaskCommandIdentity {
        AgentTaskCommandIdentity(
            taskID: task.id,
            intentID: task.intentID,
            taskRevision: task.revision,
            providerRequestID: request.identity.requestID
        )
    }

    var conversationStatus: String {
        if requiresBudgetApproval {
            return "费用或用量需要你确认，原请求尚未发送"
        }
        if let taskStatusText {
            return taskStatusText
        }
        switch request.phase {
        case .prepared:
            return "正在准备这件事"
        case .sending:
            return "正在通过当前模型连接处理这件事"
        case .streaming:
            return "仓颉正在回复"
        case .responseComplete:
            return "模型回复已经收到，正在安全保存"
        case .continuationCommitted:
            return "这件事已经处理完成"
        case .terminated:
            return "这次处理已达到安全轮次上限"
        case .outcomeUnknown:
            return "本地安全对账已完成，这次请求的结果仍不能确认"
        case .failed:
            return "这次模型处理没有完成，原请求仍然保留"
        case .cancelled:
            return "这次处理已安全停止，原请求仍然保留"
        }
    }

    var doingText: String {
        if requiresBudgetApproval {
            return "原请求已安全保存，正在等待这一次预算确认"
        }
        switch task.status {
        case .queued:
            return "这件事正在排队，前一件主要任务结束后再继续"
        case .pauseRequested:
            return "正在到安全位置暂停"
        case .reconciling:
            return reconcilingText
        case .paused:
            return "这件事已经安全暂停"
        case .stopRequested:
            return "正在结束并保留已有内容"
        case .waitingUser:
            return waitingDoingText
        case .completed where task.outcome == .kept:
            return request.phase == .outcomeUnknown
                ? "这件事已经结束，已收到内容已保留；原模型最终结果仍未知"
                : "这件事已经结束，已有内容已保留"
        case .discarded:
            return "未采用的内容已经放弃"
        case .failed:
            return "这件事没有完成"
        case .running, .completed:
            break
        }
        switch request.phase {
        case .prepared:
            return "正在准备当前模型请求"
        case .sending:
            return "正在发送到当前模型连接"
        case .streaming:
            return "仓颉正在处理并返回结果"
        case .responseComplete:
            return "正在把已收到的回复安全保存"
        case .continuationCommitted:
            return completedResultText
        case .terminated:
            return "这次处理已达到安全轮次上限"
        case .outcomeUnknown:
            return "正在核对上次模型请求的真实结果"
        case .failed:
            return "这次处理没有完成"
        case .cancelled:
            return "这次处理已经停止"
        }
    }

    var nextText: String {
        if requiresBudgetApproval {
            return "你确认后才会发送同一个请求；拒绝不会产生新的模型费用"
        }
        switch task.status {
        case .queued:
            return "等待当前主要任务释放后开始"
        case .pauseRequested, .stopRequested:
            return "先完成安全保存和结果核对"
        case .reconciling:
            return "结果仍不确定；可以结束并保留已收到内容，但不能直接重发"
        case .paused:
            return "你可以恢复、结束并保留，或放弃未采用内容"
        case .waitingUser:
            return task.waitingReason == .networkConfirmation
                ? "网络恢复后由你确认发送"
                : "重新建立连接或选择其他已保存连接后再继续"
        case .completed where task.outcome == .kept
            && request.phase == .outcomeUnknown:
            return "原请求不会重发，可以回到对话安排下一件事"
        case .discarded:
            return "可以回到对话安排下一件事"
        case .failed:
            return "可以回到当前对话明确重试"
        case .running, .completed:
            break
        }
        switch request.phase {
        case .prepared, .sending, .streaming, .responseComplete:
            return "完成后把真实结果保存到当前对话"
        case .continuationCommitted:
            return "可以回到当前对话继续安排下一步"
        case .terminated:
            return "已有结果已保留，没有结果的请求已释放"
        case .outcomeUnknown:
            return "先完成安全对账，再决定是否重试"
        case .failed, .cancelled:
            return "可以回到当前对话明确重试"
        }
    }

    var needsUserText: String {
        if requiresBudgetApproval {
            return budgetApprovalReasonText
        }
        switch task.status {
        case .queued:
            return "目前不需要你操作"
        case .pauseRequested, .stopRequested:
            return "请等待安全核对完成，不要重复发送"
        case .reconciling:
            return "如不再等待，可以结束并保留已收到内容"
        case .paused:
            return "请选择恢复、保留结束或放弃未采用内容"
        case .waitingUser:
            return task.waitingReason == .networkConfirmation
                ? "需要你确认是否发送"
                : "需要你重新建立连接或选择其他已保存连接"
        case .completed, .discarded:
            return "目前不需要你操作"
        case .failed:
            return "如要继续，请明确重试"
        case .running:
            break
        }
        switch request.phase {
        case .outcomeUnknown:
            return "结果仍未确认，请不要重复发送"
        case .failed, .cancelled:
            return "如果要继续，请明确重试"
        case .terminated:
            return "目前不需要你操作"
        case .prepared, .sending, .streaming, .responseComplete,
             .continuationCommitted:
            return "目前不需要你操作"
        }
    }

    var usageText: String? {
        guard let usage else { return nil }
        let value = "实际用量：输入 \(usage.inputTokens) · 输出 \(usage.outputTokens) · 合计 \(usage.totalTokens) tokens"
        if request.phase == .outcomeUnknown {
            return value + "；最终账单待服务商确认"
        }
        return value
    }

    var budgetApproval: ProviderBudgetApprovalSnapshot? {
        budget?.approval
    }

    var requiresBudgetApproval: Bool {
        budgetApproval?.status == .pending
    }

    var hasActiveBudgetApproval: Bool {
        guard let status = budgetApproval?.status else { return false }
        return status == .pending || status == .approved
    }

    var budgetUsageText: String? {
        guard let usage = budget?.usage else { return nil }
        let elapsedSeconds = usage.cumulativeElapsedMilliseconds / 1_000
        let costText: String
        switch usage.cumulativeCost {
        case let .known(microUnits, basis, _, currencyCode, scale):
            let amount = Double(microUnits) / Double(scale)
            let basisText = basis == .actual ? "实际" : "估算"
            costText = "\(basisText)费用 \(amount.formatted(.number.precision(.fractionLength(0...6)))) \(currencyCode)"
        case let .unknown(reason, _, currencyCode, _):
            let reasonText: String
            switch reason {
            case .pricingUnavailable:
                reasonText = "价格未知"
            case .providerChargeUnavailable:
                reasonText = "最终账单未知"
            case .outcomeUnknown:
                reasonText = "请求结果与账单待核对"
            }
            costText = "\(reasonText)（\(currencyCode)）"
        }
        return "预算 v\(budget?.policy.version ?? usage.budgetVersion)：输入 \(usage.cumulativeInputTokens) · 输出 \(usage.cumulativeOutputTokens) tokens · 用时 \(elapsedSeconds) 秒 · \(costText)"
    }

    var budgetApprovalReasonText: String {
        guard let reasons = budgetApproval?.reasons else {
            return "需要你确认是否允许发送这一次请求"
        }
        var values: [String] = []
        if reasons.contains(.pricingUnavailable) {
            values.append("服务商价格无法可靠核实")
        }
        if reasons.contains(.cumulativeCostUnavailable) {
            values.append("之前请求的最终费用仍未知")
        }
        if reasons.contains(.inputTokens) {
            values.append("累计输入将超过上限")
        }
        if reasons.contains(.outputTokens) {
            values.append("累计输出将超过上限")
        }
        if reasons.contains(.cost) {
            values.append("预计费用将超过上限")
        }
        if reasons.contains(.elapsedTime) {
            values.append("累计用时将超过上限")
        }
        return values.isEmpty
            ? "需要你确认是否允许发送这一次请求"
            : values.joined(separator: "；")
    }

    var budgetApprovalCardTitle: String {
        budgetApproval?.status == .approved
            ? "预算已同意，尚未发送"
            : "发送前预算确认"
    }

    var budgetApprovalStateText: String {
        guard budgetApproval?.status == .approved else {
            return budgetApprovalReasonText
        }
        switch task.waitingReason {
        case .networkConfirmation:
            return "预算已同意；网络恢复后仍需你确认发送"
        case .connectionInvalid:
            return "预算已同意；请先恢复原模型连接或拒绝这次请求"
        case nil:
            return "预算已同意，系统将只发送绑定的同一个请求"
        }
    }

    var budgetApprovalDetailText: String? {
        guard let approval = budgetApproval,
              let policy = budget?.policy else {
            return nil
        }
        let estimate = approval.estimate
        let identity = estimate.requestIdentity.identity
        let requestSeconds = estimate.reservedElapsedMilliseconds / 1_000
        let limitSeconds = policy.maximumElapsedMilliseconds / 1_000
        let requestCost: String
        switch estimate.reservedCost {
        case let .known(microUnits, _, _, currencyCode, scale):
            let amount = Double(microUnits) / Double(scale)
            requestCost = "预计 \(amount.formatted(.number.precision(.fractionLength(0...6)))) \(currencyCode)"
        case .unknown:
            requestCost = "费用未知（不会按 0 计算）"
        }
        let ceiling = Double(policy.maximumCostMicroUnits)
            / Double(policy.costScale)
        return "服务：\(identity.provider.rawValue) · 模型：\(identity.modelID)\n"
            + "本次上界：输入 \(estimate.reservedInputTokens) · 输出 \(estimate.reservedOutputTokens) tokens · \(requestSeconds) 秒 · \(requestCost)\n"
            + "任务上限：输入 \(policy.maximumInputTokens) · 输出 \(policy.maximumOutputTokens) tokens · \(limitSeconds) 秒 · \(ceiling.formatted(.number.precision(.fractionLength(0...6)))) \(policy.currencyCode)\n"
            + "请求：\(approval.providerRequestID.uuidString) · 绑定：\(approval.bindingHash) · 有效至 \(approval.expiresAt.formatted(date: .abbreviated, time: .shortened))"
    }

    var resultTitle: String? {
        guard let receipt else { return nil }
        switch receipt.toolID {
        case "project.create":
            return "小说已经建立"
        case "project.list":
            return "小说清单已经更新"
        case "project.status":
            return "小说状态已经核对"
        case "project.switch":
            return "已经切换当前小说"
        case "conversation.save_discussion":
            return "这次讨论已经保存"
        default:
            return "真实工具结果"
        }
    }

    var resultSummary: String? {
        guard let receipt else { return nil }
        switch receipt.toolID {
        case "project.create":
            return projectTitle.map { "已经建立《\($0)》，并保存了这次真实执行回执。" }
                ?? "小说已经建立，并保存了这次真实执行回执。"
        case "project.status":
            return projectTitle.map { "已经核对《\($0)》的当前状态。" }
                ?? "当前对话还没有绑定小说，状态查询已经完成。"
        case "project.switch":
            return projectTitle.map { "已经切换到《\($0)》，后续讨论会绑定这里。" }
                ?? "已经切换当前小说，并保存了这次真实执行回执。"
        case "conversation.save_discussion":
            return artifactTitle.map { "已经保存讨论《\($0)》，并保留了真实执行回执。" }
                ?? "已经保存这次讨论，并保留了真实执行回执。"
        default:
            return "这次工具执行已经完成，并保存了可核验回执。"
        }
    }

    var receiptToolName: String? {
        guard let receipt else { return nil }
        switch receipt.toolID {
        case "project.create":
            return "创建小说"
        case "project.status":
            return "查看小说状态"
        case "project.list":
            return "查看小说清单"
        case "project.switch":
            return "切换当前小说"
        case "conversation.save_discussion":
            return "保存讨论"
        default:
            return "受治理工具"
        }
    }

    var recoveryState: AgentTaskRecoveryState? {
        if task.status == .completed,
           task.outcome == .kept,
           request.phase == .outcomeUnknown {
            return .outcomeUnknown
        }
        if request.phase == .failed,
           request.failure == .authentication {
            return .connectionInvalid
        }
        guard let state = try? AgentTaskControlState(
            status: task.status,
            outcome: task.outcome,
            waitingReason: task.waitingReason
        ) else {
            return nil
        }
        return state.recoveryState
    }

    var recoveryText: String? {
        if task.status == .completed,
           task.outcome == .kept,
           request.phase == .outcomeUnknown {
            return "已结束：已收到内容已保留；原模型最终结果仍未知且不会重发"
        }
        switch recoveryState {
        case .completed:
            return "已完成：结果和真实记录已经安全保存"
        case .paused:
            return "已安全暂停：可以从上次保存位置恢复"
        case .failed:
            return "明确失败：原请求已保留，不会自动重试"
        case .outcomeUnknown:
            return "结果未知：正在按原请求身份安全对账"
        case .connectionInvalid:
            return "连接失效：原请求已保留，等待你重新建立或选择连接"
        case nil:
            return nil
        }
    }

    private var completedResultText: String {
        guard let receipt else { return "这件事已经处理完成" }
        switch receipt.toolID {
        case "project.create":
            return projectTitle.map { "已建立小说《\($0)》" }
                ?? "小说已经建立"
        case "project.status":
            return projectTitle.map { "已核对小说《\($0)》的当前状态" }
                ?? "已核对当前小说状态"
        case "project.list":
            return "已查看小说清单"
        case "project.switch":
            return projectTitle.map { "已切换到小说《\($0)》" }
                ?? "已切换当前小说"
        case "conversation.save_discussion":
            return artifactTitle.map { "已保存讨论《\($0)》" }
                ?? "已保存这次讨论"
        default:
            return "这件事已经处理完成"
        }
    }

    private var taskStatusText: String? {
        switch task.status {
        case .queued:
            return "这件事已经排队，尚未发送新的模型请求"
        case .pauseRequested:
            return "正在到安全位置暂停"
        case .reconciling:
            return reconcilingText
        case .paused:
            return "这件事已经安全暂停"
        case .stopRequested:
            return "正在结束并保留已有内容"
        case .waitingUser:
            return task.waitingReason == .networkConfirmation
                ? "这条请求已经保存，尚未发送"
                : "原模型连接已经失效，这条请求仍然保留"
        case .completed where task.outcome == .kept:
            return request.phase == .outcomeUnknown
                ? "这件事已经结束，已收到内容已保留；原模型最终结果仍未知"
                : "这件事已经结束，已有内容已保留"
        case .discarded:
            return "未采用的内容已经放弃"
        case .failed:
            return "这件事没有完成，原请求仍然保留"
        case .running, .completed:
            return nil
        }
    }

    private var reconcilingText: String {
        switch task.requestedControl {
        case .pauseNow:
            return "正在确认刚才的请求是否已经停止"
        case .stopKeepingResults:
            return "正在确认已有内容能否安全保留后结束"
        case nil:
            return "正在核对上次请求的真实结果"
        }
    }

    private var waitingDoingText: String {
        task.waitingReason == .networkConfirmation
            ? "这条请求已经保存，尚未发送"
            : "这件事在等待原模型连接恢复"
    }
}

extension AppDatabase {
    func s2ProviderTaskProjection(
        conversationID: UUID
    ) throws -> S2ProviderTaskProjection? {
        try queue.read { db in
            guard let taskRow = try Row.fetchOne(
                db,
                sql: """
                    SELECT * FROM agentTask
                    WHERE conversationID = ?
                    ORDER BY queueOrdinal DESC, updatedAt DESC, rowid DESC
                    LIMIT 1
                    """,
                arguments: [conversationID.uuidString]
            ) else {
                return nil
            }
            let task = try Self.decodeAgentTask(taskRow)
            guard task.conversationID == conversationID else {
                throw AppDatabaseError.invalidAgentTask
            }
            return try Self.s2ProviderTaskProjection(task: task, in: db)
        }
    }

    func s2ProviderTaskProjection(
        taskID: UUID
    ) throws -> S2ProviderTaskProjection? {
        try queue.read { db in
            guard let taskRow = try Row.fetchOne(
                db,
                sql: "SELECT * FROM agentTask WHERE id = ? LIMIT 1",
                arguments: [taskID.uuidString]
            ) else {
                return nil
            }
            return try Self.s2ProviderTaskProjection(
                task: Self.decodeAgentTask(taskRow),
                in: db
            )
        }
    }

    func queuedS2ProviderTaskProjections() throws -> [S2ProviderTaskProjection] {
        try queue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM agentTask
                    WHERE status = 'queued'
                    ORDER BY queueOrdinal ASC, rowid ASC
                    """
            )
            return try rows.map { row in
                try Self.s2ProviderTaskProjection(
                    task: Self.decodeAgentTask(row),
                    in: db
                )
            }
        }
    }

    private static func s2ProviderTaskProjection(
        task: AgentTaskSnapshot,
        in db: Database
    ) throws -> S2ProviderTaskProjection {
        guard let intentRow = try Row.fetchOne(
            db,
            sql: "SELECT * FROM pendingModelIntent WHERE id = ? LIMIT 1",
            arguments: [task.intentID.uuidString]
        ) else {
            throw AppDatabaseError.invalidPendingModelIntent
        }
        let intent = try Self.decodePendingModelIntent(intentRow)
        guard intent.id == task.intentID,
              intent.conversationID == task.conversationID,
              intent.projectID == task.projectID,
              intent.branchID == task.branchID else {
            throw AppDatabaseError.invalidPendingModelIntent
        }
        guard let latestRequestRow = try Row.fetchOne(
                db,
                sql: """
                    SELECT * FROM providerRequest
                    WHERE intentID = ?
                    ORDER BY attemptNumber DESC, turnSequence DESC,
                             updatedAt DESC, rowid DESC
                    LIMIT 1
                    """,
                arguments: [task.intentID.uuidString]
            ) else {
                throw AppDatabaseError.invalidProviderRequest
            }
            let request = try Self.decodeProviderRequest(latestRequestRow)
            let conversationID = task.conversationID
            guard request.identity.intentID == task.intentID,
                  request.identity.conversationID == conversationID else {
                throw AppDatabaseError.invalidProviderRequest
            }

            guard let runRow = try Row.fetchOne(
                db,
                sql: """
                    SELECT * FROM agentRun
                    WHERE id = ? AND conversationID = ?
                    LIMIT 1
                    """,
                arguments: [
                    request.identity.runID.uuidString,
                    conversationID.uuidString
                ]
            ) else {
                throw AppDatabaseError.invalidAgentRun
            }
            let run = try Self.decodeAgentRun(runRow)
            guard run.id == request.identity.runID else {
                throw AppDatabaseError.invalidAgentRun
            }
            guard task.activeRunID == run.id,
                  task.conversationID == conversationID,
                  task.projectID == request.identity.projectID,
                  task.branchID == request.identity.branchID else {
                throw AppDatabaseError.invalidAgentTask
            }

            let requestRows = try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM providerRequest
                    WHERE conversationID = ? AND runID = ?
                    ORDER BY attemptNumber ASC, turnSequence ASC, rowid ASC
                    """,
                arguments: [
                    conversationID.uuidString,
                    run.id.uuidString
                ]
            )
            let requests = try requestRows.map(Self.decodeProviderRequest)
            guard !requests.isEmpty,
                  requests.contains(where: {
                      $0.identity.requestID == request.identity.requestID
                  }),
                  requests.allSatisfy({
                      $0.identity.conversationID == conversationID
                          && $0.identity.runID == run.id
                  }) else {
                throw AppDatabaseError.invalidProviderRequest
            }
            let usage = try Self.aggregateProviderUsage(requests)
            let budget = try Self.providerBudgetTaskSnapshot(
                taskID: task.id,
                in: db
            )

            let receiptRow = try Row.fetchOne(
                db,
                sql: """
                    SELECT receipt.*
                    FROM toolReceipt AS receipt
                    JOIN providerRequest AS request
                      ON request.id = receipt.providerRequestID
                    WHERE receipt.conversationID = ?
                      AND receipt.originRunID = ?
                      AND request.conversationID = ?
                      AND request.runID = ?
                    ORDER BY receipt.createdAt DESC, receipt.rowid DESC
                    LIMIT 1
                    """,
                arguments: [
                    conversationID.uuidString,
                    run.id.uuidString,
                    conversationID.uuidString,
                    run.id.uuidString
                ]
            )
            let receipt = receiptRow.flatMap(Self.decodeToolReceipt)
            if receiptRow != nil, receipt == nil {
                throw AppDatabaseError.invalidToolReceiptReference
            }
            guard receipt.map({
                $0.conversationID == conversationID
                    && $0.originRunID == run.id
                    && $0.providerRequestID != nil
            }) ?? true else {
                throw AppDatabaseError.invalidToolReceiptReference
            }

            let projectTitle: String?
            let artifactTitle: String?
            if let receipt, receipt.toolID == "project.list" {
                guard let outputReference = receipt.outputReference else {
                    throw AppDatabaseError.invalidToolReceiptReference
                }
                _ = try Self.providerProjectListSnapshot(
                    id: outputReference,
                    conversationID: conversationID,
                    projectID: receipt.projectID,
                    in: db
                )
                projectTitle = nil
                artifactTitle = nil
            } else if receipt?.toolID == "conversation.save_discussion" {
                guard let outputReference = receipt?.outputReference,
                      let artifact = try Self.artifact(
                          id: outputReference,
                          in: db
                      ),
                      artifact.kind == "discussion",
                      artifact.contentHash == ApprovalFingerprint.artifactHash(
                          conversationID: conversationID,
                          projectID: receipt?.projectID,
                          kind: "discussion",
                          title: artifact.title,
                          body: artifact.body
                      ),
                      artifact.conversationID == conversationID,
                      artifact.projectID == receipt?.projectID,
                      artifact.status == "saved" else {
                    throw AppDatabaseError.invalidToolReceiptReference
                }
                projectTitle = nil
                artifactTitle = artifact.title
            } else if let projectID = receipt?.projectID {
                guard receipt?.outputReference == projectID.uuidString,
                      let project = try Self.project(
                          id: projectID.uuidString,
                          in: db
                      ) else {
                    throw AppDatabaseError.invalidToolReceiptReference
                }
                projectTitle = project.title
                artifactTitle = nil
            } else {
                guard receipt?.outputReference == nil else {
                    throw AppDatabaseError.invalidToolReceiptReference
                }
                projectTitle = nil
                artifactTitle = nil
            }

        return S2ProviderTaskProjection(
                conversationID: conversationID,
                task: task,
                run: run,
                request: request,
                userRequest: intent.userRequest,
                usage: usage,
                budget: budget,
                receipt: receipt,
                projectTitle: projectTitle,
                artifactTitle: artifactTitle,
                lastSafeSaveAt: max(
                    max(max(request.updatedAt, run.updatedAt), task.updatedAt),
                    receipt?.createdAt ?? request.updatedAt
                )
        )
    }

    private static func aggregateProviderUsage(
        _ requests: [ProviderRequestSnapshot]
    ) throws -> ProviderUsage? {
        var input = 0
        var output = 0
        var total = 0
        var hasUsage = false
        for request in requests {
            guard let usage = request.usage else { continue }
            hasUsage = true
            let inputResult = input.addingReportingOverflow(usage.inputTokens)
            let outputResult = output.addingReportingOverflow(usage.outputTokens)
            let totalResult = total.addingReportingOverflow(usage.totalTokens)
            guard !inputResult.overflow,
                  !outputResult.overflow,
                  !totalResult.overflow else {
                throw AppDatabaseError.invalidProviderRequest
            }
            input = inputResult.partialValue
            output = outputResult.partialValue
            total = totalResult.partialValue
        }
        guard hasUsage else { return nil }
        let sum = input.addingReportingOverflow(output)
        guard !sum.overflow, sum.partialValue == total else {
            throw AppDatabaseError.invalidProviderRequest
        }
        return ProviderUsage(
            inputTokens: input,
            outputTokens: output,
            totalTokens: total
        )
    }
}
