import CryptoKit
import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var draft = ""
    @Published var status = "正在初始化…"
    @Published var apiKeyInput = ""
    @Published var hasStoredKey = false
    @Published var streamURL = ""
    @Published var streamOutput = ""
    @Published var isStreaming = false

    private static let maximumStreamOutputBytes = 256 * 1_024
    private let database: AppDatabase?
    private let keychain: any SecretRepository
    private let taskID: UUID
    private var streamTask: Task<Void, Never>?
    private var streamGeneration: UUID?

    init(
        database: AppDatabase? = nil,
        databaseFactory: () throws -> AppDatabase = { try AppDatabase.makeDefault() },
        keychain: any SecretRepository = KeychainSecretRepository()
    ) {
        self.keychain = keychain
        let defaultsKey = "m0TaskID"
        if let stored = UserDefaults.standard.string(forKey: defaultsKey),
           let id = UUID(uuidString: stored) {
            taskID = id
        } else {
            let id = UUID()
            taskID = id
            UserDefaults.standard.set(id.uuidString, forKey: defaultsKey)
        }

        let databaseState: (database: AppDatabase?, draft: String, status: String)
        do {
            let resolved = try database ?? databaseFactory()
            let restoredDraft = try resolved.loadDraft()?.content ?? ""
            let restoredStatus: String
            if let checkpoint = try resolved.latestCheckpoint(taskID: taskID) {
                if Self.payloadHash(for: restoredDraft) == checkpoint.payloadHash {
                    restoredStatus = "已恢复 checkpoint #\(checkpoint.sequence)"
                } else {
                    restoredStatus = "草稿比 checkpoint 更新，请手动建立新检查点"
                }
            } else {
                restoredStatus = "SQLite 已就绪，尚无 checkpoint"
            }
            databaseState = (resolved, restoredDraft, restoredStatus)
        } catch {
            databaseState = (nil, "", "SQLite 初始化失败（DB-INIT）")
        }
        self.database = databaseState.database
        draft = databaseState.draft
        status = databaseState.status

        do {
            hasStoredKey = try keychain.contains(account: "m0-probe")
        } catch {
            status = "\(status)；Keychain 状态不可用（KEY-READ）"
        }
    }

    func saveDraft() {
        guard let database else { return }
        do {
            try database.saveDraft(draft)
            status = "草稿已保存：\(Date().formatted(date: .omitted, time: .standard))"
        } catch {
            status = "草稿保存失败（DB-WRITE）"
        }
    }

    func createCheckpoint(reason: String) {
        guard let database else { return }
        do {
            let checkpoint = try database.checkpointDraft(
                content: draft,
                taskID: taskID,
                reason: reason,
                payloadHash: Self.payloadHash(for: draft)
            )
            status = "已写入 checkpoint #\(checkpoint.sequence)（\(reason)）"
        } catch {
            status = "checkpoint 写入失败（DB-CHECKPOINT）"
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .inactive:
            createCheckpoint(reason: "sceneInactive")
        case .background:
            createCheckpoint(reason: "sceneBackground")
        case .active:
            break
        @unknown default:
            createCheckpoint(reason: "sceneUnknown")
        }
    }

    func saveProbeKey() {
        guard !apiKeyInput.isEmpty else {
            status = "Keychain 测试值不能为空"
            return
        }
        do {
            try keychain.save(apiKeyInput, account: "m0-probe")
            apiKeyInput = ""
            hasStoredKey = true
            status = "测试值已保存到 ThisDeviceOnly Keychain"
        } catch {
            status = "Keychain 写入失败（KEY-WRITE）"
        }
    }

    func deleteProbeKey() {
        do {
            try keychain.delete(account: "m0-probe")
            apiKeyInput = ""
            hasStoredKey = false
            status = "Keychain 测试值已删除"
        } catch {
            status = "Keychain 删除失败（KEY-DELETE）"
        }
    }

    func startStreamingProbe() {
        streamTask?.cancel()
        let generation = UUID()
        streamGeneration = generation
        streamOutput = ""
        isStreaming = true
        status = "正在连接 HTTPS SSE…"

        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await event in StreamingHTTPClient().stream(urlText: self.streamURL) {
                    try Task.checkCancellation()
                    guard self.streamGeneration == generation else { return }
                    let appended = self.streamOutput + event.data + "\n"
                    guard appended.utf8.count <= Self.maximumStreamOutputBytes else {
                        throw StreamingHTTPError.outputLimitExceeded
                    }
                    self.streamOutput = appended
                }
                try Task.checkCancellation()
                guard self.streamGeneration == generation else { return }
                self.status = "流式探针已完成"
            } catch is CancellationError {
                guard self.streamGeneration == generation else { return }
                self.status = "流式探针已取消"
            } catch let error as StreamingHTTPError {
                guard self.streamGeneration == generation else { return }
                self.status = error.errorDescription ?? "流式探针失败（NET-SSE）"
            } catch {
                guard self.streamGeneration == generation else { return }
                self.status = "流式探针失败（NET-SSE）"
            }

            guard self.streamGeneration == generation else { return }
            self.streamGeneration = nil
            self.streamTask = nil
            self.isStreaming = false
        }
    }

    private static func payloadHash(for text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map {
            String(format: "%02x", $0)
        }.joined()
    }

    func cancelStreamingProbe() {
        streamGeneration = nil
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        status = "流式探针已取消"
    }
}