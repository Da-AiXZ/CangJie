//
//  OnboardingStore.swift
//  Cangjie
//
//  新书向导：三步（Bible 流式生成 SSE / 角色创建 / 宏观规划）。
//

import SwiftUI
import Foundation

/// 新书向导步骤
enum OnboardingStep: Int, CaseIterable {
    case novelInfo = 0
    case bibleGeneration = 1
    case characterSetup = 2
    case macroPlanning = 3
    case completed = 4

    var title: String {
        switch self {
        case .novelInfo: return "基本信息"
        case .bibleGeneration: return "设定生成"
        case .characterSetup: return "角色确认"
        case .macroPlanning: return "宏观规划"
        case .completed: return "完成"
        }
    }
}

/// 新书向导 Store
@MainActor
final class OnboardingStore: ObservableObject {

    // MARK: - 状态

    /// 当前步骤
    @Published var currentStep: OnboardingStep = .novelInfo

    /// 小说基本信息
    @Published var novelTitle: String = ""
    @Published var novelAuthor: String = ""
    @Published var novelPremise: String = ""
    @Published var targetChapters: Int = 100
    @Published var genre: String = ""
    @Published var worldPreset: String = ""
    @Published var storyStructure: String = ""
    @Published var pacingControl: String = ""
    @Published var writingStyle: String = ""
    @Published var specialRequirements: String = ""
    @Published var lengthTier: String? = nil
    @Published var targetWordsPerChapter: Int? = nil

    /// 已创建的小说
    @Published var createdNovel: NovelDTO?

    /// Bible 生成状态
    @Published var bibleStatus: BibleGenerationStatus?
    @Published var bibleGenerationLog: [String] = []
    @Published var bible: BibleDTO?

    /// 宏观规划 SSE 事件
    @Published var macroPlanEvents: [MacroPlanEvent] = []
    @Published var macroPlanStructure: [AnyCodable]?

    /// 是否正在处理
    @Published var isProcessing: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 依赖

    private let apiClient: APIClient
    private let sseRegistry: SSEStreamRegistry

    init(apiClient: APIClient = .shared, sseRegistry: SSEStreamRegistry = .shared) {
        self.apiClient = apiClient
        self.sseRegistry = sseRegistry
    }

    // MARK: - 步骤 1: 创建小说

    /// 创建小说
    /// - Returns: 创建的小说
    @discardableResult
    func createNovel() async throws -> NovelDTO {
        isProcessing = true
        defer { isProcessing = false }

        let novelId = UUID().uuidString
        let request = CreateNovelRequest(
            novelId: novelId,
            title: novelTitle,
            author: novelAuthor,
            targetChapters: targetChapters,
            premise: novelPremise,
            genre: genre,
            worldPreset: worldPreset,
            storyStructure: storyStructure,
            pacingControl: pacingControl,
            writingStyle: writingStyle,
            specialRequirements: specialRequirements,
            lengthTier: lengthTier,
            targetWordsPerChapter: targetWordsPerChapter
        )

        let novel: NovelDTO = try await apiClient.request(APIEndpoint.Novels.create, body: request)
        createdNovel = novel
        currentStep = .bibleGeneration
        return novel
    }

    // MARK: - 步骤 2: Bible 流式生成

    /// 启动 Bible 流式生成
    /// - Parameter stage: 生成阶段
    func startBibleGeneration(stage: String = "full") async {
        guard let novelId = createdNovel?.id else { return }

        isProcessing = true
        errorMessage = nil
        bibleGenerationLog.removeAll()

        // 订阅 Bible 生成 SSE
        sseRegistry.startBibleGenerateStream(
            novelId: novelId,
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.handleBibleSSEEvent(event)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.errorMessage = error.localizedDescription
                    self?.isProcessing = false
                }
            }
        )
    }

    /// 处理 Bible SSE 事件
    private func handleBibleSSEEvent(_ event: SSEEvent) {
        // 解析事件数据
        if let dict = event.decodeAsDictionary() {
            if let phase = dict["phase"] as? String {
                bibleGenerationLog.append("阶段: \(phase)")
            }
            if let message = dict["message"] as? String {
                bibleGenerationLog.append(message)
            }
            if let text = dict["text"] as? String {
                bibleGenerationLog.append(text)
            }
            if let done = dict["done"] as? Bool, done == true {
                isProcessing = false
                currentStep = .characterSetup
                // 加载生成的 Bible
                Task { await self.loadBible() }
            }
            if let error = dict["error"] as? String {
                errorMessage = error
                isProcessing = false
            }
        }
    }

    /// 加载 Bible
    func loadBible() async {
        guard let novelId = createdNovel?.id else { return }

        do {
            bible = try await apiClient.request(APIEndpoint.Bible.get(novelId: novelId))
        } catch {
            // Bible 可能还未生成完成
            Logger.data.error("加载 Bible 失败: \(error.localizedDescription)")
        }
    }

    /// 跳过 Bible 生成
    func skipBibleGeneration() {
        currentStep = .characterSetup
    }

    // MARK: - 步骤 3: 角色确认

    /// 添加角色
    /// - Parameter request: 角色创建请求
    func addCharacter(_ request: AddCharacterRequest) async {
        guard let novelId = createdNovel?.id else { return }

        do {
            let updatedBible: BibleDTO = try await apiClient.request(
                APIEndpoint.Bible.addCharacter(novelId: novelId),
                body: request
            )
            bible = updatedBible
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 进入宏观规划
    func proceedToMacroPlanning() {
        currentStep = .macroPlanning
    }

    // MARK: - 步骤 4: 宏观规划

    /// 启动宏观规划 SSE
    func startMacroPlanning() async {
        guard let novelId = createdNovel?.id else { return }

        isProcessing = true
        errorMessage = nil
        macroPlanEvents.removeAll()

        sseRegistry.startMacroPlanStream(
            novelId: novelId,
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.handleMacroPlanSSEEvent(event)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.errorMessage = error.localizedDescription
                    self?.isProcessing = false
                }
            }
        )
    }

    /// 处理宏观规划 SSE 事件
    private func handleMacroPlanSSEEvent(_ event: SSEEvent) {
        guard let planEvent = try? event.decode(MacroPlanEvent.self) else { return }
        macroPlanEvents.append(planEvent)

        switch planEvent.type {
        case "done":
            macroPlanStructure = planEvent.structure
            isProcessing = false
            currentStep = .completed
        case "error":
            errorMessage = planEvent.error ?? "宏观规划失败"
            isProcessing = false
        default:
            break
        }
    }

    /// 完成向导
    func complete() {
        currentStep = .completed
    }

    // MARK: - 重置

    /// 重置向导状态
    func reset() {
        currentStep = .novelInfo
        novelTitle = ""
        novelAuthor = ""
        novelPremise = ""
        targetChapters = 100
        genre = ""
        worldPreset = ""
        createdNovel = nil
        bibleStatus = nil
        bibleGenerationLog.removeAll()
        bible = nil
        macroPlanEvents.removeAll()
        macroPlanStructure = nil
        isProcessing = false
        errorMessage = nil

        // 取消所有 SSE 流
        if let novelId = createdNovel?.id {
            sseRegistry.cancelAll(novelId: novelId)
        }
    }
}
