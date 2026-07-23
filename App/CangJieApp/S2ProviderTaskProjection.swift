import CangJieCore
import Foundation
import GRDB

/// One read-only S2 projection shared by Conversation, AI Tasks and Results.
/// Every field comes from the same SQLite read transaction.
struct S2ProviderTaskProjection: Equatable {
    let conversationID: UUID
    let run: AgentRunSnapshot
    let request: ProviderRequestSnapshot
    let usage: ProviderUsage?
    let receipt: ToolReceipt?
    let projectTitle: String?
    let artifactTitle: String?
    let lastSafeSaveAt: Date

    var conversationStatus: String {
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
        case .outcomeUnknown:
            return "本地安全对账已完成，这次请求的结果仍不能确认"
        case .failed:
            return "这次模型处理没有完成，原请求仍然保留"
        case .cancelled:
            return "这次处理已安全停止，原请求仍然保留"
        }
    }

    var doingText: String {
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
        case .outcomeUnknown:
            return "正在核对上次模型请求的真实结果"
        case .failed:
            return "这次处理没有完成"
        case .cancelled:
            return "这次处理已经停止"
        }
    }

    var nextText: String {
        switch request.phase {
        case .prepared, .sending, .streaming, .responseComplete:
            return "完成后把真实结果保存到当前对话"
        case .continuationCommitted:
            return "可以回到当前对话继续安排下一步"
        case .outcomeUnknown:
            return "先完成安全对账，再决定是否重试"
        case .failed, .cancelled:
            return "可以回到当前对话明确重试"
        }
    }

    var needsUserText: String {
        switch request.phase {
        case .outcomeUnknown:
            return "结果仍未确认，请不要重复发送"
        case .failed, .cancelled:
            return "如果要继续，请明确重试"
        case .prepared, .sending, .streaming, .responseComplete,
             .continuationCommitted:
            return "目前不需要你操作"
        }
    }

    var usageText: String? {
        guard let usage else { return nil }
        return "实际用量：输入 \(usage.inputTokens) · 输出 \(usage.outputTokens) · 合计 \(usage.totalTokens) tokens"
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
}

extension AppDatabase {
    func s2ProviderTaskProjection(
        conversationID: UUID
    ) throws -> S2ProviderTaskProjection? {
        try queue.read { db in
            guard let latestRequestRow = try Row.fetchOne(
                db,
                sql: """
                    SELECT * FROM providerRequest
                    WHERE conversationID = ?
                    ORDER BY attemptNumber DESC, turnSequence DESC,
                             updatedAt DESC, rowid DESC
                    LIMIT 1
                    """,
                arguments: [conversationID.uuidString]
            ) else {
                return nil
            }
            let request = try Self.decodeProviderRequest(latestRequestRow)
            guard request.identity.conversationID == conversationID else {
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
                run: run,
                request: request,
                usage: usage,
                receipt: receipt,
                projectTitle: projectTitle,
                artifactTitle: artifactTitle,
                lastSafeSaveAt: max(
                    max(request.updatedAt, run.updatedAt),
                    receipt?.createdAt ?? request.updatedAt
                )
            )
        }
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
