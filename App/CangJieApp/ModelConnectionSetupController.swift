import CangJieCore
import Combine
import Foundation

enum ModelConnectionSetupConversationCopy {
    static let intentSaved =
        "这句话和原来的对话位置已经保存，仓颉正在检查当前模型连接。"
    static let connectionRequired =
        "要继续这件事，请先选一个模型服务。原消息已经保留，连接好之后会回到这里继续。"
    static let connectionReady =
        "连接已保存，正在回到原对话继续处理。"
}

enum ModelConnectionSetupStep: Equatable {
    case idle
    case chooseProvider
    case enterCredentials
    case discovering
    case chooseModel
    case nameConnection
    case saving
    case completed
}

enum ModelConnectionSetupFlowError: Error, Equatable {
    case databaseUnavailable
    case providerRequired
    case invalidCustomBaseURL
    case secretRequired
    case discoveryRequired
    case modelRequired
    case connectionNameRequired
    case credentialUnavailable
    case connectionRecoveryRequired
}

protocol ModelDiscoveryServing: Sendable {
    func discover(_ attempt: ModelDiscoveryAttempt) async throws -> ModelDiscoveryNetworkResult
}

extension ModelDiscoveryNetworkClient: ModelDiscoveryServing {}

@MainActor
final class ModelConnectionSetupController: ObservableObject {
    @Published private(set) var step: ModelConnectionSetupStep = .idle
    @Published private(set) var selectedProvider: ModelProvider?
    @Published var secretInput = "" {
        didSet { invalidateDiscoveryAfterInputChange(from: oldValue, to: secretInput) }
    }
    @Published var customBaseURLInput = "" {
        didSet { invalidateDiscoveryAfterInputChange(from: oldValue, to: customBaseURLInput) }
    }
    @Published var connectionNameInput = ""
    @Published private(set) var availableModelIDs: [String] = []
    @Published private(set) var selectedModelID: String?
    @Published private(set) var canEnterModelManually = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var pendingIntent: PendingModelIntent?
    @Published private(set) var currentConnection: ModelConnection?
    @Published private(set) var currentMetadata: StoredModelConnection?
    @Published private(set) var savedConnections: [StoredModelConnection] = []
    @Published private(set) var resumeDecision: ModelRequestAdmissionDecision?
    @Published private(set) var isExplicitManagement = false

    private let database: AppDatabase?
    private let credentials: any ModelCredentialRepository
    private let discoveryClient: any ModelDiscoveryServing
    private let allowsPendingResume: Bool
    private var attempt: ModelDiscoveryAttempt?
    private var networkResult: ModelDiscoveryNetworkResult?
    private var onResumeDecisionReady: ((ModelRequestAdmissionDecision) -> Void)?
    private var discoveryTask: Task<ModelDiscoveryNetworkResult, Error>?
    private var generation = UUID()
    private var isClearingTransientState = false

    init(
        database: AppDatabase?,
        credentials: any ModelCredentialRepository,
        discoveryClient: any ModelDiscoveryServing = ModelDiscoveryNetworkClient(),
        allowsPendingResume: Bool = true
    ) {
        self.database = database
        self.credentials = credentials
        self.discoveryClient = discoveryClient
        self.allowsPendingResume = allowsPendingResume
        refreshStoredState()
    }

    var isPresented: Bool { step != .idle }
    var blocksComposer: Bool { step != .idle || pendingIntent != nil }
    var hasSensitiveDiscoveryState: Bool {
        attempt != nil || networkResult != nil || !secretInput.isEmpty
    }

    func isPresented(for conversationID: UUID?) -> Bool {
        guard isPresented else { return false }
        if isExplicitManagement { return true }
        guard let pendingIntent else { return true }
        return pendingIntent.conversationID == conversationID
    }

    func blocksComposer(for conversationID: UUID?) -> Bool {
        if isExplicitManagement {
            return step != .idle
        }
        guard let pendingIntent else {
            return false
        }
        return pendingIntent.conversationID == conversationID
    }

    func conversationStatus(for conversationID: UUID?) -> String? {
        guard let pendingIntent,
              pendingIntent.conversationID == conversationID else {
            return nil
        }
        return resumeDecision == nil
            ? ModelConnectionSetupConversationCopy.connectionRequired
            : ModelConnectionSetupConversationCopy.connectionReady
    }

    var providerDisplayName: String {
        selectedProvider.map { ProviderConnectorRegistry.connector(for: $0).displayName } ?? ""
    }

    var baseURLText: String {
        guard let selectedProvider else { return "" }
        if selectedProvider == .custom {
            return customBaseURLInput
        }
        return ProviderConnectorRegistry.connector(for: selectedProvider)
            .defaultBaseURL?.absoluteString ?? ""
    }

    var currentConnectionLabel: String? {
        if let currentConnection {
            let provider = ProviderConnectorRegistry.connector(for: currentConnection.provider)
            return "\(currentConnection.name) · \(provider.displayName) · \(currentConnection.selectedModel)"
        }
        if let currentMetadata {
            return "已选择 \(currentMetadata.connection.name)，还需要重新验证凭证"
        }
        return nil
    }

    func begin(pendingIntent: PendingModelIntent?) {
        generation = UUID()
        discoveryTask?.cancel()
        discoveryTask = nil
        isExplicitManagement = false
        self.pendingIntent = pendingIntent
        resumeDecision = nil
        selectedProvider = nil
        secretInput = ""
        customBaseURLInput = ""
        connectionNameInput = ""
        availableModelIDs = []
        selectedModelID = nil
        canEnterModelManually = false
        errorMessage = nil
        attempt = nil
        networkResult = nil
        step = .chooseProvider
    }

    func setResumeDecisionHandler(
        _ handler: @escaping (ModelRequestAdmissionDecision) -> Void
    ) {
        onResumeDecisionReady = handler
    }

    private func publishResumeDecision(
        _ decision: ModelRequestAdmissionDecision
    ) {
        resumeDecision = decision
        onResumeDecisionReady?(decision)
    }

    func openManagement() {
        begin(pendingIntent: nil)
        isExplicitManagement = true
    }

    func closeManagement(returningTo conversationID: UUID?) {
        guard isExplicitManagement else { return }
        cancel()
        restorePendingIntent(for: conversationID)
    }

    func prepareForPendingIntent(_ pendingIntent: PendingModelIntent) {
        let preservesInProgressSetup = self.pendingIntent == pendingIntent
            && !isExplicitManagement
            && step != .idle
        isExplicitManagement = false
        self.pendingIntent = pendingIntent
        refreshStoredState()

        guard allowsPendingResume else {
            resumeDecision = nil
            currentConnection = nil
            if !preservesInProgressSetup || step == .completed {
                begin(pendingIntent: pendingIntent)
            }
            errorMessage = "模型连接仍在安全恢复中，暂时不能继续原请求"
            return
        }

        if let currentMetadata,
           let verified = try? credentials.verifiedConnection(for: currentMetadata.connection) {
            publishResumeDecision(
                ModelRequestAdmission.resume(pendingIntent, with: verified)
            )
            currentConnection = verified.connection
            clearSensitiveDiscoveryState()
            step = .completed
            return
        }

        if preservesInProgressSetup && step != .completed {
            return
        }
        begin(pendingIntent: pendingIntent)
    }

    func restorePendingIntent(for conversationID: UUID?) {
        guard !isExplicitManagement else { return }
        guard let database, let conversationID else { return }
        do {
            if let pendingIntent = try database.latestPendingModelIntent(
                conversationID: conversationID
            ) {
                prepareForPendingIntent(pendingIntent)
            } else if !isExplicitManagement,
                      let pendingIntent = self.pendingIntent,
                      pendingIntent.conversationID == conversationID {
                cancel()
                self.pendingIntent = nil
            }
        } catch {
            errorMessage = "还有一件未完成的事情，连接恢复需要你重新确认"
        }
    }

    func cancel() {
        let preservedPendingIntent = isExplicitManagement ? nil : pendingIntent
        cancelDiscoveryAndAdvanceGeneration()
        isExplicitManagement = false
        step = .idle
        selectedProvider = nil
        secretInput = ""
        customBaseURLInput = ""
        connectionNameInput = ""
        availableModelIDs = []
        selectedModelID = nil
        canEnterModelManually = false
        errorMessage = nil
        attempt = nil
        networkResult = nil
        resumeDecision = nil
        pendingIntent = preservedPendingIntent
    }

    func selectProvider(_ provider: ModelProvider) {
        generation = UUID()
        discoveryTask?.cancel()
        discoveryTask = nil
        selectedProvider = provider
        secretInput = ""
        customBaseURLInput = ""
        connectionNameInput = ""
        availableModelIDs = []
        selectedModelID = nil
        canEnterModelManually = false
        errorMessage = nil
        attempt = nil
        networkResult = nil
        resumeDecision = nil
        step = .enterCredentials
    }

    func discoverModels() async throws {
        guard let provider = selectedProvider else {
            return try fail(.providerRequired, message: "请先选一个模型服务")
        }
        guard !secretInput.isEmpty else {
            return try fail(.secretRequired, message: "请先输入 API Key")
        }
        let baseURL: URL
        if provider == .custom {
            guard let customURL = URL(string: customBaseURLInput.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return try fail(.invalidCustomBaseURL, message: "自定义服务地址无法使用，请检查后再试")
            }
            baseURL = customURL
        } else {
            guard let officialURL = ProviderConnectorRegistry.connector(for: provider).defaultBaseURL else {
                return try fail(.invalidCustomBaseURL, message: "模型服务地址暂时不可用")
            }
            baseURL = officialURL
        }

        cancelDiscoveryAndAdvanceGeneration()
        attempt = nil
        networkResult = nil
        availableModelIDs = []
        selectedModelID = nil
        canEnterModelManually = false
        let currentGeneration = generation
        step = .discovering
        errorMessage = nil
        let newAttempt: ModelDiscoveryAttempt
        do {
            newAttempt = try ModelDiscoveryAttempt(
                discoveryID: UUID(),
                connectionID: UUID(),
                credentialID: UUID(),
                provider: provider,
                baseURL: baseURL,
                secret: secretInput
            )
        } catch {
            step = .enterCredentials
            errorMessage = "这个 API Key 不能使用，请检查后再试"
            throw error
        }

        do {
            let client = discoveryClient
            let task = Task {
                try await client.discover(newAttempt)
            }
            discoveryTask = task
            defer {
                if generation == currentGeneration {
                    discoveryTask = nil
                }
            }
            let result = try await task.value
            guard generation == currentGeneration else { return }
            attempt = newAttempt
            networkResult = result
            switch result.discoveryResult {
            case let .complete(catalog):
                availableModelIDs = catalog.modelIDs
                canEnterModelManually = false
            case .manualEntryAllowed:
                availableModelIDs = []
                canEnterModelManually = true
            case .nextPage:
                throw ModelDiscoveryError.catalogIncomplete
            }
            step = .chooseModel
        } catch {
            guard generation == currentGeneration else { return }
            step = .enterCredentials
            errorMessage = Self.userMessage(for: error)
            throw error
        }
    }

    func selectModel(_ modelID: String) {
        guard let result = networkResult else {
            errorMessage = "模型列表还没有准备好，请重新测试连接"
            return
        }
        do {
            switch result.discoveryResult {
            case .complete:
                _ = try ModelDiscoveryFlow.selectModel(modelID, from: result.discoveryResult)
            case let .manualEntryAllowed(authorization):
                _ = try authorization.selectModel(modelID)
            case .nextPage:
                throw ModelDiscoveryError.catalogIncomplete
            }
            selectedModelID = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
            errorMessage = nil
            step = .nameConnection
        } catch {
            errorMessage = Self.userMessage(for: error)
        }
    }

    func saveCurrentConnection() throws {
        guard allowsPendingResume else {
            return try fail(
                .connectionRecoveryRequired,
                message: "模型连接仍在安全恢复中，请稍后再试"
            )
        }
        guard let database else {
            return try fail(.databaseUnavailable, message: "连接暂时无法保存，请稍后再试")
        }
        guard let attempt else {
            return try fail(.discoveryRequired, message: "请先测试连接并获取模型列表")
        }
        guard let result = networkResult else {
            return try fail(.discoveryRequired, message: "请先测试连接并获取模型列表")
        }
        guard let selectedModelID, !selectedModelID.isEmpty else {
            return try fail(.modelRequired, message: "请明确选择一个模型")
        }
        let name = connectionNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return try fail(.connectionNameRequired, message: "请给这个连接起个名字")
        }

        step = .saving
        errorMessage = nil
        do {
            let candidate: ModelConnectionSetupCandidate
            switch result.discoveryResult {
            case .complete:
                if attempt.credentialBinding.provider == .custom {
                    let proven = try result.credentialProvenCustomSelection(selectedModelID)
                    candidate = try attempt.prepareConnection(
                        name: name,
                        credentialProvenSelection: proven
                    )
                } else {
                    let selection = try ModelDiscoveryFlow.selectModel(
                        selectedModelID,
                        from: result.discoveryResult
                    )
                    candidate = try attempt.prepareConnection(name: name, selection: selection)
                }
            case .manualEntryAllowed:
                let proven = try result.credentialProvenCustomSelection(selectedModelID)
                candidate = try attempt.prepareConnection(
                    name: name,
                    credentialProvenSelection: proven
                )
            case .nextPage:
                throw ModelDiscoveryError.catalogIncomplete
            }

            let stored = try ModelConnectionSetupService(
                database: database,
                credentials: credentials
            ).persist(
                candidate,
                expectedCredentialBinding: attempt.credentialBinding,
                makeCurrent: true
            )
            guard let verified = try credentials.verifiedConnection(for: stored.connection) else {
                throw ModelConnectionSetupFlowError.credentialUnavailable
            }
            currentConnection = verified.connection
            currentMetadata = stored
            if let pendingIntent {
                publishResumeDecision(
                    ModelRequestAdmission.resume(pendingIntent, with: verified)
                )
            }
            refreshStoredState()
            clearSensitiveDiscoveryState()
            step = .completed
        } catch {
            step = .nameConnection
            errorMessage = Self.userMessage(for: error)
            throw error
        }
    }

    func selectCurrentConnection(_ id: UUID) throws {
        guard allowsPendingResume else {
            return try fail(
                .connectionRecoveryRequired,
                message: "模型连接仍在安全恢复中，请稍后再试"
            )
        }
        clearSensitiveDiscoveryState()
        guard let database,
              let stored = try database.listModelConnections().first(where: { $0.connection.id == id }),
              let verified = try credentials.verifiedConnection(for: stored.connection) else {
            errorMessage = "这个连接还没有通过凭证验证，暂时不能启用"
            throw ModelConnectionSetupFlowError.credentialUnavailable
        }
        try database.selectCurrentModelConnection(id: id)
        currentConnection = verified.connection
        currentMetadata = stored
        if let pendingIntent {
            publishResumeDecision(
                ModelRequestAdmission.resume(pendingIntent, with: verified)
            )
            step = .completed
        } else {
            resumeDecision = nil
            step = isExplicitManagement ? .chooseProvider : .idle
        }
        errorMessage = nil
        refreshStoredState()
    }

    func suspendDiscovery() {
        generation = UUID()
        discoveryTask?.cancel()
        discoveryTask = nil
        if step == .discovering {
            step = .enterCredentials
            errorMessage = "连接测试已暂停，可以稍后重试"
        }
    }

    private func refreshStoredState() {
        guard let database else { return }
        do {
            savedConnections = try database.listModelConnections()
            currentMetadata = try database.currentModelConnection()
        } catch {
            savedConnections = []
            currentMetadata = nil
            currentConnection = nil
            return
        }

        guard allowsPendingResume, let currentMetadata else {
            currentConnection = nil
            return
        }
        do {
            currentConnection = try credentials.verifiedConnection(
                for: currentMetadata.connection
            )?.connection
        } catch {
            currentConnection = nil
        }
    }

    private func cancelDiscoveryAndAdvanceGeneration() {
        generation = UUID()
        discoveryTask?.cancel()
        discoveryTask = nil
    }

    private func clearSensitiveDiscoveryState() {
        isClearingTransientState = true
        defer { isClearingTransientState = false }
        cancelDiscoveryAndAdvanceGeneration()
        attempt = nil
        networkResult = nil
        availableModelIDs = []
        selectedModelID = nil
        canEnterModelManually = false
        selectedProvider = nil
        secretInput = ""
        customBaseURLInput = ""
        connectionNameInput = ""
    }

    private func invalidateDiscoveryAfterInputChange(from oldValue: String, to newValue: String) {
        guard !isClearingTransientState,
              oldValue != newValue,
              step == .discovering || step == .chooseModel || step == .nameConnection else {
            return
        }
        generation = UUID()
        discoveryTask?.cancel()
        discoveryTask = nil
        attempt = nil
        networkResult = nil
        availableModelIDs = []
        selectedModelID = nil
        canEnterModelManually = false
        errorMessage = nil
        step = .enterCredentials
    }

    private func fail<T>(_ error: ModelConnectionSetupFlowError, message: String) throws -> T {
        errorMessage = message
        step = .enterCredentials
        throw error
    }

    private static func userMessage(for error: Error) -> String {
        switch error {
        case ModelDiscoveryNetworkError.customDestinationPinningUnavailable:
            return "当前版本还不能安全连接自定义服务，请先使用官方服务"
        case ModelDiscoveryNetworkError.destinationAddressNotPublic,
             ModelDiscoveryNetworkError.destinationResolutionFailed:
            return "这个服务地址无法安全验证，请检查地址后再试"
        case ModelDiscoveryNetworkError.invalidCredential,
             ModelDiscoveryError.connectionProbeFailed:
            return "连接没有通过，请检查 API Key 和服务选择"
        case ModelDiscoveryError.explicitSelectionRequired,
             ModelDiscoveryError.modelNotInCatalog:
            return "请从当前连接能使用的模型中明确选择一个"
        case ModelConnectionSetupFlowError.credentialUnavailable:
            return "凭证没有通过回读验证，连接没有启用"
        case ModelConnectionSetupError.credentialCompensationFailed:
            return "连接保存没有完成，凭证也没有被启用，请稍后重试"
        default:
            return "连接没有完成，请检查输入后再试"
        }
    }
}
