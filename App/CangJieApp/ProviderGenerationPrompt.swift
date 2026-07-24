import CangJieCore
import Foundation

enum ProviderAgentRunError: Error, Equatable {
    case queued
    case cancelled
    case connectionInvalid
    case unsupportedProvider
    case invalidStream
    case requiresReconciliation
    case terminalRequest
    case toolTurnLimitReached
    case budgetApprovalRequired
    case budgetBlocked(Set<BudgetBlockReason>)
    case outcomeUnknown(ProviderRequestInterruption)
    case persistenceFailed
}

enum ProviderGenerationCapability {
    static func supports(_ provider: ModelProvider) -> Bool {
        provider == .deepSeek || provider == .openAI || provider == .openRouter
    }

    static let unavailableMessage =
        "当前版本暂不支持用这个服务执行真实模型任务"
}

struct ProviderRunProjection: Equatable {
    let requestID: UUID
    let phase: ProviderRequestPhase
    let text: String
    let usage: ProviderUsage?
}

struct ProviderRunCompletion: Equatable {
    let request: ProviderRequestSnapshot
    let response: ProviderResponsePayload
}

struct ProviderAgentLoopCompletion: Equatable {
    let request: ProviderRequestSnapshot
    let message: AgentMessage
    let receipts: [ToolReceipt]
    let projects: [NovelProject]
}

struct ProviderGenerationToolResult: Equatable {
    let callID: String
    let callIndex: Int
    let contentJSON: String
}

struct ProviderGenerationPrompt: Equatable {
    let systemPrompt: String
    let userPrompt: String
    let assistantResponse: ProviderResponsePayload?
    let toolResults: [ProviderGenerationToolResult]
    let allowsToolCalls: Bool

    static func initial(
        systemPrompt: String,
        userPrompt: String
    ) -> ProviderGenerationPrompt {
        ProviderGenerationPrompt(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            assistantResponse: nil,
            toolResults: [],
            allowsToolCalls: true
        )
    }

    static func continuation(
        systemPrompt: String,
        userPrompt: String,
        assistantResponse: ProviderResponsePayload,
        toolResults: [ProviderGenerationToolResult],
        allowsToolCalls: Bool = true
    ) throws -> ProviderGenerationPrompt {
        let prompt = ProviderGenerationPrompt(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            assistantResponse: assistantResponse,
            toolResults: toolResults,
            allowsToolCalls: allowsToolCalls
        )
        try prompt.validate()
        return prompt
    }

    var isInitial: Bool {
        assistantResponse == nil && toolResults.isEmpty
    }

    func validate() throws {
        guard !systemPrompt.isEmpty, !userPrompt.isEmpty else {
            throw ProviderGenerationError.invalidPreparedRequest
        }
        if isInitial {
            guard allowsToolCalls else {
                throw ProviderGenerationError.invalidPreparedRequest
            }
            return
        }
        guard let assistantResponse,
              !assistantResponse.toolCalls.isEmpty,
              assistantResponse.finishReason == "tool_calls",
              assistantResponse.toolCalls.count == toolResults.count else {
            throw ProviderGenerationError.invalidPreparedRequest
        }
        try assistantResponse.validate(allowIncompleteToolCalls: false)
        for (call, result) in zip(
            assistantResponse.toolCalls,
            toolResults
        ) {
            guard let callID = call.id,
                  call.index == result.callIndex,
                  callID == result.callID,
                  !result.contentJSON.isEmpty,
                  result.contentJSON.utf8.count <= 64 * 1_024,
                  let data = result.contentJSON.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: data)) != nil else {
                throw ProviderGenerationError.invalidPreparedRequest
            }
        }
    }
}
