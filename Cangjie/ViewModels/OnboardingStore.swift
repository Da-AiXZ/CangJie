//
//  OnboardingStore.swift
//  Cangjie
//
//  新书向导：三步（Bible 流式生成 SSE 分 stage / 角色创建 / 地点生成）。
//  对齐 Vue3 NovelSetupGuide.vue:1480-1676 的 startBibleGenerationSSE /
//  startCharactersGenerationSSE / startLocationsGenerationSSE 三个函数。
//

import SwiftUI
import Foundation

/// 新书向导步骤 — NovelSetupGuide.vue:16-17
/// Q4决策：maxVisitedStep 模式（顺序前进+后退到已到步骤）
enum OnboardingStep: Int, CaseIterable, Comparable {
    case novelInfo = 0
    case bibleGeneration = 1
    case characterSetup = 2
    case locationSetup = 3
    case plotOutline = 4    // 阶段3新增：剧情总纲（替换 macroPlanning 的向导 UI 入口）
    case completed = 5

    static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .novelInfo: return "基本信息"
        case .bibleGeneration: return "设定生成"
        case .characterSetup: return "角色确认"
        case .locationSetup: return "地点确认"
        case .plotOutline: return "剧情总纲"
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

    // MARK: - M1/M2 分阶段 SSE 生成状态字段（NovelSetupGuide.vue:1480-1676）

    /// 当前阶段进度提示（NovelSetupGuide.vue phaseMessage）
    @Published var phaseMessage: String = ""

    /// 文风公约文本（NovelSetupGuide.vue styleText）
    @Published var styleText: String = ""

    /// 世界观5维度数据（NovelSetupGuide.vue worldbuildingData: WorldbuildingDraftShape）
    /// 结构：[维度: [字段: 值]]（bibleSetupModel.ts:7）
    @Published var worldbuildingData: [String: [String: String]] = emptyWorldbuildingData()

    /// 世界观原始流式数据（兼容旧服务端，NovelSetupGuide.vue worldbuildingRawStream）
    @Published var worldbuildingRawStream: String = ""

    /// 当前正在生成的世界观维度（NovelSetupGuide.vue activeDimension）
    @Published var activeDimension: String = ""

    /// 当前正在生成的世界观字段（NovelSetupGuide.vue activeField）
    @Published var activeField: String = ""

    /// 已到达的字段集合（NovelSetupGuide.vue arrivedFields）
    @Published var arrivedFields: Set<String> = []

    /// 已完成的维度集合（NovelSetupGuide.vue completedDimensions）
    @Published var completedDimensions: Set<String> = []

    /// 审批提示消息（Q1/Q2决策：approval_required 事件提示）
    @Published var approvalMessage: String = ""

    // MARK: - M2 角色流式生成状态（NovelSetupGuide.vue:1567-1619）

    /// 流式生成的角色列表（NovelSetupGuide.vue streamingCharacters）
    @Published var streamingCharacters: [EditableCharacter] = []

    /// 可编辑角色列表（生成完成后从 Bible 映射，NovelSetupGuide.vue editableCharacters）
    @Published var editableCharacters: [EditableCharacter] = []

    /// 生成角色草稿缓存（NovelSetupGuide.vue generatedCharacterDrafts，key=characterDraftKey）
    @Published var generatedCharacterDrafts: [String: GeneratedCharacterPayload] = [:]

    /// 是否正在生成角色
    @Published var generatingCharacters: Bool = false

    /// 角色是否已生成
    @Published var charactersGenerated: Bool = false

    /// 角色生成错误
    @Published var charactersError: String = ""

    // MARK: - M2 地点流式生成状态（NovelSetupGuide.vue:1627-1676）

    /// 流式生成的地点列表（NovelSetupGuide.vue streamingLocations）
    @Published var streamingLocations: [GeneratedLocation] = []

    /// 可编辑地点列表（生成完成后从 Bible 映射，NovelSetupGuide.vue editableLocations）
    @Published var editableLocations: [GeneratedLocation] = []

    /// 是否正在生成地点
    @Published var generatingLocations: Bool = false

    /// 地点是否已生成
    @Published var locationsGenerated: Bool = false

    /// 地点生成错误
    @Published var locationsError: String = ""

    // MARK: - Bible 生成阶段状态

    /// 是否正在生成 Bible（worldbuilding 阶段）
    @Published var generatingBible: Bool = false

    /// Bible 是否已生成（worldbuilding 阶段完成）
    @Published var bibleGenerated: Bool = false

    /// Bible 生成错误
    @Published var bibleError: String = ""

    // MARK: - 宏观规划 SSE 事件（保留，工作台 MacroPlanModal 仍在用）

    @Published var macroPlanEvents: [MacroPlanEvent] = []
    @Published var macroPlanStructure: [AnyCodable]?

    /// 是否正在处理
    @Published var isProcessing: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 阶段3新增：剧情总纲状态（NovelSetupGuide.vue:1068-1076）

    /// Q4决策：maxVisitedStep 模式 — NovelSetupGuide.vue:2055
    @Published var maxVisitedStep: Int = 1

    /// 剧情总纲 — NovelSetupGuide.vue:1068
    @Published var plotOutline: PlotOutlineDTO? = nil

    /// 剧情总纲编辑副本 — NovelSetupGuide.vue:1074
    @Published var editablePlotOutline: PlotOutlineDTO = createEmptyPlotOutline()

    /// 是否正在生成剧情总纲 — NovelSetupGuide.vue:1069
    @Published var plotOutlineGenerating: Bool = false

    /// 剧情总纲错误 — NovelSetupGuide.vue:1070
    @Published var plotOutlineError: String = ""

    /// 剧情总纲是否已提交 — NovelSetupGuide.vue:1071
    @Published var plotOutlineCommitted: Bool = false

    /// 剧情总纲审批 session ID — NovelSetupGuide.vue:1072
    @Published var plotOutlineSessionId: String = ""

    /// 是否从缓存恢复 — NovelSetupGuide.vue:1073
    @Published var step4RestoredFromCache: Bool = false

    /// 是否正在同步草稿 — NovelSetupGuide.vue:1075
    @Published var syncingPlotOutlineDraft: Bool = false

    /// 剧情总纲状态 — NovelSetupGuide.vue:1076
    @Published var plotOutlineStatus: PlotOutlineStatus = .idle

    /// AI Invocation Store（审批面板）
    @Published var aiInvocationStore: AIInvocationStore = AIInvocationStore()

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

    // MARK: - 步骤 2: Bible 流式生成（分 stage 调用）

    /// 启动 Bible 流式生成（分 stage，对齐 NovelSetupGuide.vue:1480-1676）
    ///
    /// - Parameter stage: 生成阶段（worldbuilding / characters / locations）
    ///   - worldbuilding: 文风公约 + 世界观5维度（NovelSetupGuide.vue:1480-1559）
    ///   - characters: 角色（NovelSetupGuide.vue:1567-1619）
    ///   - locations: 地点（NovelSetupGuide.vue:1627-1676）
    func startBibleGeneration(stage: String) async {
        guard let novelId = createdNovel?.id else { return }

        isProcessing = true
        errorMessage = nil
        approvalMessage = ""

        // 按 stage 重置对应状态（NovelSetupGuide.vue:1480-1676）
        switch stage {
        case "worldbuilding":
            // 重置 worldbuilding 步骤状态（NovelSetupGuide.vue:1485-1498）
            generatingBible = true
            bibleGenerated = false
            bibleError = ""
            phaseMessage = ""
            activeDimension = ""
            activeField = ""
            completedDimensions = []
            arrivedFields = []
            worldbuildingData = emptyWorldbuildingData()
            worldbuildingRawStream = ""
            styleText = ""

        case "characters":
            // 重置角色步骤状态（NovelSetupGuide.vue:1571-1578）
            generatingCharacters = true
            charactersGenerated = false
            charactersError = ""
            streamingCharacters = []
            editableCharacters = []
            generatedCharacterDrafts = [:]
            phaseMessage = ""

        case "locations":
            // 重置地点步骤状态（NovelSetupGuide.vue:1631-1638）
            generatingLocations = true
            locationsGenerated = false
            locationsError = ""
            streamingLocations = []
            editableLocations = []
            phaseMessage = ""

        default:
            break
        }

        // 订阅 Bible 生成 SSE，传 stage 参数（bible.ts:363, SSEStreamRegistry.startBibleGenerateStream）
        sseRegistry.startBibleGenerateStream(
            novelId: novelId,
            stage: stage,
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.handleBibleSSEEvent(event, stage: stage)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.handleBibleSSEError(error.localizedDescription, stage: stage)
                }
            }
        )
    }

    /// 处理 Bible SSE 事件（对齐 bible.ts:339-500 consumeBibleGenerateStream）
    ///
    /// Bible 生成流的 SSE 帧格式：有 event 行（phase/data/done/error），data JSON 中的 type 字段确定子类型。
    /// 13 类事件：phase + data(10种子类型) + done + error
    ///
    /// - Parameters:
    ///   - event: SSE 事件
    ///   - stage: 当前生成阶段
    private func handleBibleSSEEvent(_ event: SSEEvent, stage: String) {
        // Bible 事件大类从 event 行获取（bible.ts:400-413 parseSseBlock）
        guard let eventType = event.bibleEventType else {
            // 无 event 行的事件忽略
            return
        }

        guard let dict = event.decodeAsDictionary() else { return }

        switch eventType {
        case "phase":
            // phase 事件（bible.ts:433-434）
            let phase = dict["phase"] as? String ?? ""
            let message = dict["message"] as? String ?? ""
            handlePhaseEvent(phase: phase, message: message, stage: stage)

        case "data":
            // data 事件，子类型从 data.type 获取（bible.ts:436）
            let dataType = dict["type"] as? String ?? ""
            handleDataEvent(dataType: dataType, dict: dict, stage: stage)

        case "done":
            // done 事件（bible.ts:475-477）
            let message = dict["message"] as? String ?? ""
            let novelId = dict["novel_id"] as? String ?? createdNovel?.id ?? ""
            let invocationSessionId = dict["invocation_session_id"] as? String
            handleDoneEvent(message: message, novelId: novelId, invocationSessionId: invocationSessionId, stage: stage)

        case "error":
            // error 事件（bible.ts:478-481）
            let message = dict["message"] as? String ?? "生成失败"
            handleBibleSSEError(message, stage: stage)

        default:
            break
        }
    }

    /// 处理 phase 事件（bible.ts:433-434, NovelSetupGuide.vue:1503-1521）
    private func handlePhaseEvent(phase: String, message: String, stage: String) {
        // 更新 phaseMessage（NovelSetupGuide.vue:1504）
        phaseMessage = message

        // worldbuilding 阶段：解析 worldbuilding_* phase 子类型更新 activeDimension（NovelSetupGuide.vue:1506-1515）
        if stage == "worldbuilding" {
            // phase 可能是 "worldbuilding_core_rules" / "worldbuilding_geography" 等
            for dim in WB_DIMS {
                if phase == "worldbuilding_\(dim)" || phase.contains(dim) {
                    activeDimension = dim
                    break
                }
            }
        }
    }

    /// 处理 data 事件子类型（bible.ts:435-474）
    private func handleDataEvent(dataType: String, dict: [String: Any], stage: String) {
        switch dataType {
        case "style":
            // data→style（bible.ts:437-438）：设置 styleText（覆盖式）
            let content = dict["content"] as? String ?? ""
            styleText = content

        case "style_chunk":
            // data→style_chunk（bible.ts:439-440）：追加 styleText（打字效果）
            let chunk = dict["chunk"] as? String ?? ""
            styleText += chunk

        case "worldbuilding_chunk":
            // data→worldbuilding_chunk（bible.ts:441-442）：追加 worldbuildingRawStream
            let chunk = dict["chunk"] as? String ?? ""
            worldbuildingRawStream += chunk

        case "worldbuilding_field":
            // data→worldbuilding_field（bible.ts:443-448）：写 worldbuildingData[dim][field]，更新 activeDimension/activeField/arrivedFields
            let dimension = dict["dimension"] as? String ?? ""
            let field = dict["field"] as? String ?? ""
            let value = dict["value"] as? String ?? ""

            if !dimension.isEmpty && !field.isEmpty {
                if worldbuildingData[dimension] == nil {
                    worldbuildingData[dimension] = [:]
                }
                worldbuildingData[dimension]?[field] = value

                // 更新 activeDimension/activeField（NovelSetupGuide.vue:1517-1521）
                activeDimension = dimension
                activeField = field
                arrivedFields.insert("\(dimension).\(field)")
            }

        case "worldbuilding_dimension":
            // data→worldbuilding_dimension（bible.ts:449-454）：合并 content 到 worldbuildingData[dim]，标记 completedDimensions
            let dimension = dict["dimension"] as? String ?? ""
            let label = dict["label"] as? String ?? ""
            let content = dict["content"] as? [String: String] ?? [:]

            if !dimension.isEmpty {
                if worldbuildingData[dimension] == nil {
                    worldbuildingData[dimension] = [:]
                }
                // 合并 content
                for (key, value) in content {
                    worldbuildingData[dimension]?[key] = value
                }
                completedDimensions.insert(dimension)
                activeDimension = dimension
            }

        case "character":
            // data→character（bible.ts:455-456, NovelSetupGuide.vue:1584-1596）
            let content = dict["content"] as? [String: Any] ?? [:]
            let index = dict["index"] as? Int ?? 0

            // 构造 GeneratedCharacterPayload → mapGeneratedCharacterToEditable（characterSetupModel.ts:147-174）
            let payload = GeneratedCharacterPayload(content: content)
            let editable = mapGeneratedCharacterToEditable(payload)

            // 生成 draftKey（characterSetupModel.ts:143-145）
            let draftKey = characterDraftKey(id: payload.id, name: payload.name)

            // 存 generatedCharacterDrafts（NovelSetupGuide.vue:1588）
            generatedCharacterDrafts[draftKey] = payload

            // 追加 streamingCharacters（NovelSetupGuide.vue:1590）
            streamingCharacters.append(editable)

        case "character_chunk":
            // data→character_chunk（bible.ts:457-458, NovelSetupGuide.vue:1598-1603）
            // 若 phaseMessage 不含"正在生成"，设为"AI 正在构思角色..."
            if !phaseMessage.contains("正在生成") {
                phaseMessage = "AI 正在构思角色..."
            }

        case "location":
            // data→location（bible.ts:459-460, NovelSetupGuide.vue:1648-1654）
            let content = dict["content"] as? [String: Any] ?? [:]
            let loc = GeneratedLocation(content: content)
            streamingLocations.append(loc)

        case "location_chunk":
            // data→location_chunk（bible.ts:461-462, NovelSetupGuide.vue:1656-1660）
            if !phaseMessage.contains("正在生成") {
                phaseMessage = "AI 正在构思地点..."
            }

        case "approval_required":
            // data→approval_required（bible.ts:463-474）
            // 阶段3接线：打开 AI 审批面板 — NovelSetupGuide.vue:1548-1550
            let sessionId = dict["session_id"] as? String ?? ""
            let status = dict["status"] as? String
            let nextAction = dict["next_action"] as? String
            let stageStr = dict["stage"] as? String

            if !sessionId.isEmpty {
                approvalMessage = ""
                Logger.engine.info("Bible SSE approval_required: sessionId=\(sessionId), status=\(status ?? ""), nextAction=\(nextAction ?? ""), stage=\(stageStr ?? "")")
                // 阶段3：接线到 AI 审批面板
                handleBibleApprovalRequired(sessionId: sessionId, stage: stage)
            }

        default:
            break
        }
    }

    /// 处理 done 事件（bible.ts:475-477, NovelSetupGuide.vue finishXxxGeneration）
    private func handleDoneEvent(message: String, novelId: String, invocationSessionId: String?, stage: String) {
        switch stage {
        case "worldbuilding":
            // finishWorldbuildingGeneration（NovelSetupGuide.vue:1537-1544）
            // 标记所有维度完成
            for dim in WB_DIMS {
                completedDimensions.insert(dim)
            }
            generatingBible = false
            bibleGenerated = true
            isProcessing = false
            phaseMessage = ""

        case "characters":
            // finishCharactersGeneration（NovelSetupGuide.vue:1607-1612）
            generatingCharacters = false
            charactersGenerated = true
            isProcessing = false
            phaseMessage = ""

        case "locations":
            // finishLocationsGeneration（NovelSetupGuide.vue:1668-1673）
            generatingLocations = false
            locationsGenerated = true
            isProcessing = false
            phaseMessage = ""

        default:
            isProcessing = false
        }

        // 加载 Bible 数据刷新 UI（NovelSetupGuide.vue:1679-1708 loadBibleData）
        Task { await self.loadBibleData() }
    }

    /// 处理 Bible SSE 错误（bible.ts:478-481）
    private func handleBibleSSEError(_ message: String, stage: String) {
        switch stage {
        case "worldbuilding":
            bibleError = message
            generatingBible = false
        case "characters":
            charactersError = message
            generatingCharacters = false
        case "locations":
            locationsError = message
            generatingLocations = false
        default:
            break
        }
        errorMessage = message
        isProcessing = false
    }

    /// 加载 Bible 数据（NovelSetupGuide.vue:1679-1708）
    /// Q3决策：只调 bibleApi.getBible，不调 worldbuildingApi.getWorldbuilding
    func loadBibleData() async {
        guard let novelId = createdNovel?.id else { return }

        do {
            bible = try await apiClient.request(APIEndpoint.Bible.get(novelId: novelId))

            // 刷新 styleText（NovelSetupGuide.vue:1699）
            if !bible!.style.isEmpty {
                styleText = bible!.style
            }

            // 将 characters 映射为 editableCharacters（NovelSetupGuide.vue:1696-1698）
            // 用 mapCharacterToEditable + generatedCharacterDrafts 回填
            if !bible!.characters.isEmpty {
                editableCharacters = bible!.characters.map { char in
                    let draftKey = characterDraftKey(id: char.id, name: char.name)
                    let fallback: EditableCharacter? = generatedCharacterDrafts[draftKey].map { mapGeneratedCharacterToEditable($0) }
                    return mapCharacterToEditable(char, fallback: fallback)
                }
            }

            // 将 locations 映射为 editableLocations
            if !bible!.locations.isEmpty {
                editableLocations = bible!.locations.map { loc in
                    GeneratedLocation(
                        id: loc.id,
                        name: loc.name,
                        type: loc.locationType,
                        locationType: loc.locationType,
                        description: loc.description
                    )
                }
            }
        } catch {
            Logger.data.error("加载 Bible 失败: \(error.localizedDescription)")
        }
    }

    /// 保留旧方法名兼容
    func loadBible() async {
        await loadBibleData()
    }

    /// 跳过 Bible 生成
    func skipBibleGeneration() {
        currentStep = .characterSetup
    }

    // MARK: - 更新 Bible（保存编辑，NovelSetupGuide.vue:1912-1931）

    /// 更新 Bible（保存编辑），对应 PUT /bible/novels/{id}/bible（bible.ts:225-234）
    /// 向导每步"下一步"时调用保存（Q4决策）
    func updateBible() async {
        guard let novelId = createdNovel?.id else { return }

        do {
            // 构造请求体：从当前 bible 取数据（如果有的话）
            let currentBible = bible
            let request = UpdateBibleRequest(
                characters: (currentBible?.characters ?? []).map { AnyCodable($0.dictionaryValue ?? [:]) },
                worldSettings: (currentBible?.worldSettings ?? []).map { AnyCodable($0.dictionaryValue ?? [:]) },
                locations: (currentBible?.locations ?? []).map { AnyCodable($0.dictionaryValue ?? [:]) },
                timelineNotes: (currentBible?.timelineNotes ?? []).map { AnyCodable($0.dictionaryValue ?? [:]) },
                styleNotes: (currentBible?.styleNotes ?? []).map { AnyCodable($0.dictionaryValue ?? [:]) }
            )

            let updatedBible: BibleDTO = try await apiClient.request(
                APIEndpoint.Bible.update(novelId: novelId),
                body: request
            )
            bible = updatedBible
            Logger.data.info("Bible 更新成功: \(novelId)")
        } catch {
            errorMessage = "保存设定失败: \(error.localizedDescription)"
            Logger.data.error("Bible 更新失败: \(error.localizedDescription)")
        }
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

    /// 进入地点步骤
    func proceedToLocationSetup() {
        currentStep = .locationSetup
    }

    // MARK: - 步骤 4: 宏观规划（REST 方式，保留供工作台 MacroPlanModal 使用）

    /// 启动宏观规划
    ///
    /// 【修复】原实现只连 SSE 流监听事件，但生成完成后从未调 POST /macro/confirm
    /// 确认大纲，导致结构没存进 DB → autopilot 启动报 409。
    /// 现改为 REST 方式：generate → 轮询 progress → result → confirm
    func startMacroPlanning() async {
        guard let novel = createdNovel else { return }
        let novelId = novel.id

        isProcessing = true
        errorMessage = nil
        macroPlanEvents.removeAll()

        // 1. 触发生成
        let request = MacroPlanRequest(
            targetChapters: novel.targetChapters,
            structure: StructurePreference(parts: 3, volumesPerPart: 3, actsPerVolume: 3)
        )

        do {
            let _: AnyCodable = try await apiClient.request(
                APIEndpoint.Planning.macroGenerate(novelId: novelId),
                body: request
            )
        } catch {
            errorMessage = "触发宏观规划失败: \(error.localizedDescription)"
            isProcessing = false
            return
        }

        // 2. 轮询进度
        let maxAttempts = 120
        for attempt in 0..<maxAttempts {
            do {
                let progress: AnyCodable = try await apiClient.request(
                    APIEndpoint.Planning.macroProgress(novelId: novelId)
                )
                let dict = progress.dictionaryValue ?? [:]
                let status = dict["status"] as? String ?? ""
                let message = dict["message"] as? String ?? ""
                let percent = dict["percent"] as? Double ?? 0

                macroPlanEvents.append(MacroPlanEvent(
                    type: "status", message: message, percent: percent
                ))

                if status == "completed" || status == "done" {
                    break
                }
                if status == "failed" {
                    errorMessage = "宏观规划失败: \(message)"
                    isProcessing = false
                    return
                }
            } catch {
                // 进度查询失败，继续重试
            }

            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if Task.isCancelled {
                isProcessing = false
                return
            }
        }

        // 3. 获取结果
        do {
            let result: AnyCodable = try await apiClient.request(
                APIEndpoint.Planning.macroResult(novelId: novelId)
            )
            let dict = result.dictionaryValue ?? [:]
            let structure = dict["structure"] as? [Any] ?? []
            let structureData = try JSONSerialization.data(withJSONObject: structure)
            let decoded = try CangjieDecoder.shared.decode([AnyCodable].self, from: structureData)
            macroPlanStructure = decoded

            macroPlanEvents.append(MacroPlanEvent(
                type: "done", message: "宏观规划完成", percent: 100,
                structure: decoded
            ))

            // 4. 确认大纲
            let confirmRequest = MacroPlanConfirmRequest(structure: decoded)
            let _: AnyCodable = try await apiClient.request(
                APIEndpoint.Planning.macroConfirm(novelId: novelId),
                body: confirmRequest
            )
        } catch {
            errorMessage = "获取/确认宏观规划结果失败: \(error.localizedDescription)"
            isProcessing = false
            return
        }

        isProcessing = false
    }

    /// 完成向导
    func complete() {
        currentStep = .completed
    }

    // MARK: - 阶段3：步骤导航（Q4 maxVisitedStep 模式）— NovelSetupGuide.vue:2054-2074

    /// 跳转到指定步骤 — NovelSetupGuide.vue:2058-2065
    /// Q4决策：只允许跳到 ≤ maxVisitedStep 的步骤；生成中禁止切换
    func goToStep(_ step: OnboardingStep) {
        guard step.rawValue >= 1 && step.rawValue <= 5 else { return }
        guard step.rawValue <= maxVisitedStep else { return }
        if step == currentStep { return }
        if isWizardGenerating { return }
        currentStep = step
    }

    /// 上一步 — NovelSetupGuide.vue:2068-2074
    func handlePrev() {
        if currentStep.rawValue > 1 && !isWizardGenerating {
            if let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) {
                currentStep = prev
            }
        }
    }

    /// 下一步 — NovelSetupGuide.vue:2076-2114 handleNext
    func handleNext() {
        if isWizardGenerating { return }
        let nextRaw = currentStep.rawValue + 1
        guard let nextStep = OnboardingStep(rawValue: nextRaw) else { return }
        currentStep = nextStep
        maxVisitedStep = max(maxVisitedStep, nextRaw)
        WizardUiCache.setLastStep(novelId: createdNovel?.id ?? "", step: nextRaw)
    }

    /// 是否正在生成（包含剧情总纲） — NovelSetupGuide.vue:1093-1095
    var isWizardGenerating: Bool {
        return generatingBible || generatingCharacters || generatingLocations || plotOutlineBusy
    }

    /// 剧情总纲是否忙 — NovelSetupGuide.vue:1089-1092
    var plotOutlineBusy: Bool {
        return plotOutlineGenerating || (plotOutlineStatus != .idle && plotOutlineStatus != .done && plotOutlineStatus != .error)
    }

    /// 剧情总纲状态消息 — NovelSetupGuide.vue:1096-1105
    var plotOutlineStatusMessage: String {
        if !phaseMessage.isEmpty { return phaseMessage }
        switch plotOutlineStatus {
        case .creating: return "正在创建剧情总纲任务..."
        case .reviewing: return "正在确认剧情总纲生成..."
        case .generating: return "AI 正在生成剧情总纲..."
        case .committing: return "正在写入剧情总纲..."
        case .done: return ""
        case .error: return plotOutlineError
        case .idle: return ""
        }
    }

    /// 剧情总纲实时预览 — NovelSetupGuide.vue:1106-1112
    var plotOutlineLivePreview: String {
        guard !plotOutlineSessionId.isEmpty else { return "" }
        guard aiInvocationStore.session?.id == plotOutlineSessionId else { return "" }
        let text = aiInvocationStore.liveAttemptDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }
        return text.count > 1000 ? String(text.suffix(1000)) : text
    }

    /// 剧情总纲进度项 — NovelSetupGuide.vue:1120-1132
    var plotOutlineProgressItems: [PlotOutlineProgressItem] {
        let current = plotOutlineProgressIndex
        let items = [
            PlotOutlineProgressItem(key: "context", label: "汇总设定", desc: "读取世界观、人物与地图", state: .pending),
            PlotOutlineProgressItem(key: "outline", label: "推演主线", desc: "生成核心冲突与故事走向", state: .pending),
            PlotOutlineProgressItem(key: "stage", label: "拆分阶段", desc: "规划阶段任务与章节范围", state: .pending),
            PlotOutlineProgressItem(key: "commit", label: "写入结果", desc: "回填可编辑的剧情总纲", state: .pending),
        ]
        return items.enumerated().map { (index, item) in
            var modified = item
            if current > index + 1 { modified.state = .done }
            else if current == index + 1 { modified.state = .active }
            else { modified.state = .pending }
            return modified
        }
    }

    /// 剧情总纲进度索引 — NovelSetupGuide.vue:1113-1119
    private var plotOutlineProgressIndex: Int {
        if plotOutlineStatus == .done { return 4 }
        if plotOutlineStatus == .committing { return 3 }
        if plotOutlineStatus == .generating || plotOutlineStatus == .reviewing { return 2 }
        if plotOutlineStatus == .creating { return 1 }
        return plotOutlineBusy ? 1 : 0
    }

    // MARK: - 阶段3：剧情总纲核心方法（NovelSetupGuide.vue:1068-1454）

    /// 加载剧情总纲 — NovelSetupGuide.vue:1328-1422
    func loadPlotOutline(forceNew: Bool = false) async {
        guard let novelId = createdNovel?.id else { return }
        step4RestoredFromCache = false
        plotOutlineError = ""
        plotOutlineStatus = .creating
        phaseMessage = "正在创建剧情总纲任务..."

        // 读取缓存
        let cached = forceNew ? nil : WizardUiCache.read(novelId: novelId)
        let cachedPlotOutline = (!forceNew && cached != nil && WizardUiCache.isPlotOutlineFresh(cached)) ? cached?.plotOutline : nil

        if let cachedPlotOutline = cachedPlotOutline {
            // 缓存有效：恢复
            let normalized = normalizePlotOutlineShape(cachedPlotOutline, totalChapters: targetChapters) ?? cachedPlotOutline
            plotOutline = normalized
            syncEditablePlotOutline(normalized)
            plotOutlineSessionId = cached?.invocationSessionId ?? ""
            step4RestoredFromCache = true
            resetPlotOutlineInvocationState()
            if !plotOutlineSessionId.isEmpty && !plotOutlineCommitted {
                await openPlotOutlineReviewPanel(sessionId: plotOutlineSessionId)
            }
            return
        }

        plotOutlineGenerating = true
        if forceNew {
            plotOutline = nil
            syncEditablePlotOutline(nil)
            plotOutlineCommitted = false
            plotOutlineSessionId = ""
            WizardUiCache.write(novelId: novelId, patch: WizardUiCachePatch(clearPlotOutline: true, clearInvocationSessionId: true))
        }

        // 尝试 SSE 流式生成
        do {
            try await consumePlotOutlineStream(novelId: novelId)
            if let outline = plotOutline {
                WizardUiCache.write(novelId: novelId, patch: WizardUiCachePatch(plotOutline: outline))
            }
        } catch {
            // 降级 POST
            do {
                let response: GeneratePlotOutlineResponse = try await apiClient.request(
                    APIEndpoint.Workflow.generatePlotOutline(novelId: novelId),
                    body: EmptyBody()
                )
                if let outline = response.plotOutline {
                    let normalized = normalizePlotOutlineShape(outline, totalChapters: targetChapters) ?? outline
                    plotOutline = normalized
                    syncEditablePlotOutline(normalized)
                }
                if let sessionId = response.invocationSessionId, !sessionId.isEmpty {
                    plotOutlineSessionId = sessionId
                    await openPlotOutlineReviewPanel(sessionId: sessionId)
                }
                if let outline = plotOutline {
                    WizardUiCache.write(novelId: novelId, patch: WizardUiCachePatch(plotOutline: outline))
                }
            } catch {
                plotOutlineError = "生成失败: \(error.localizedDescription)"
                plotOutlineGenerating = false
                plotOutlineStatus = .error
            }
        }

        if plotOutline != nil || !plotOutlineError.isEmpty || plotOutlineSessionId.isEmpty {
            resetPlotOutlineInvocationState()
        }
    }

    /// 刷新剧情总纲 — NovelSetupGuide.vue:1424-1426
    func refreshPlotOutline() async {
        await loadPlotOutline(forceNew: true)
    }

    /// SSE 流式消费剧情总纲 — workflow.ts:682-771 consumePlotOutlineStream
    private func consumePlotOutlineStream(novelId: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            // 构建 SSE URL
            guard let url = APIConfig.shared.fullURL(
                path: "/novels/\(novelId)/setup/generate-plot-outline-stream",
                prefix: APIConfig.apiV1Prefix
            ) else {
                continuation.resume(throwing: APIError.invalidURL)
                return
            }

            let bodyData = try? JSONSerialization.data(withJSONObject: [String: Any](), options: [])
            let request = APIClient.shared.makeSSEPostRequest(url: url, body: bodyData)
            let session = URLSession(configuration: APIConfig.makeSSEURLSessionConfiguration())

            var streamError: String = ""
            var didResume = false

            let task = session.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else {
                    if !didResume { continuation.resume(); didResume = true }
                    return
                }
                if let error = error {
                    streamError = error.localizedDescription
                    if !didResume { continuation.resume(); didResume = true }
                    return
                }
                // 解析 SSE 帧从 data
                guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                    if !didResume { continuation.resume(); didResume = true }
                    return
                }
                // 按 \n\n 分帧
                let frames = responseString.components(separatedBy: "\n\n")
                Task { @MainActor in
                    for frame in frames {
                        self.handlePlotOutlineSSEFrame(frame, novelId: novelId)
                    }
                    if !streamError.isEmpty && self.plotOutline == nil {
                        if !didResume { continuation.resume(throwing: APIError.unknown(streamError)); didResume = true }
                    } else {
                        if !didResume { continuation.resume(); didResume = true }
                    }
                }
            }
            task.resume()
        }
    }

    /// 处理剧情总纲 SSE 帧 — workflow.ts:717-751
    private func handlePlotOutlineSSEFrame(_ frame: String, novelId: String) {
        let lines = frame.components(separatedBy: "\n")
        var dataLines: [String] = []
        for line in lines {
            if line.hasPrefix("data:") {
                let value = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                dataLines.append(value)
            }
        }
        guard !dataLines.isEmpty else { return }
        let dataString = dataLines.joined(separator: "\n")
        guard let data = dataString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let type = dict["type"] as? String ?? ""

        switch type {
        case "phase":
            // workflow.ts:717-724
            let message = dict["message"] as? String ?? ""
            phaseMessage = message

        case "approval_required":
            // workflow.ts:725-736
            let sessionId = dict["session_id"] as? String ?? ""
            let status = dict["status"] as? String
            let nextAction = dict["next_action"] as? String
            if !sessionId.isEmpty {
                plotOutlineSessionId = sessionId
                Task { await openPlotOutlineReviewPanel(sessionId: sessionId) }
            }

        case "done":
            // workflow.ts:737-744
            if let outlineDict = dict["plot_outline"] as? [String: Any] {
                let normalized = normalizePlotOutlineShape(outlineDict, totalChapters: targetChapters)
                if let normalized = normalized {
                    plotOutline = normalized
                    syncEditablePlotOutline(normalized)
                }
            }

        case "error":
            // workflow.ts:745-751
            let message = dict["message"] as? String ?? "流式生成失败"
            plotOutlineError = message

        default:
            break
        }
    }

    /// 打开审批面板 — NovelSetupGuide.vue:1296-1326
    func openPlotOutlineReviewPanel(sessionId: String) async {
        guard !sessionId.isEmpty else { return }
        plotOutlineSessionId = sessionId
        plotOutlineGenerating = true
        if plotOutlineStatus == .idle || plotOutlineStatus == .done || plotOutlineStatus == .error {
            plotOutlineStatus = .creating
            phaseMessage = "正在创建剧情总纲任务..."
        }
        // 写入缓存
        if let novelId = createdNovel?.id {
            WizardUiCache.write(novelId: novelId, patch: WizardUiCachePatch(invocationSessionId: sessionId))
        }
        // 注册监听
        let unsub = aiInvocationStore.onSessionUpdate(sessionId: sessionId) { [weak self] payload in
            Task { @MainActor in
                await self?.handlePlotOutlineInvocationUpdate(payload)
            }
        }
        _ = unsub // 保留取消闭包
        do {
            try await aiInvocationStore.open(sessionId: sessionId)
            if aiInvocationStore.session?.id == sessionId {
                let payload = InvocationResponseDTO(
                    session: aiInvocationStore.session ?? InvocationSessionDTO(),
                    attempt: aiInvocationStore.attempt,
                    decision: aiInvocationStore.decision,
                    commit: aiInvocationStore.commit,
                    nextAction: aiInvocationStore.nextAction
                )
                await handlePlotOutlineInvocationUpdate(payload)
            }
        } catch {
            failPlotOutlineInvocation(error.localizedDescription)
        }
    }

    /// 处理审批更新 — NovelSetupGuide.vue:1271-1294
    private func handlePlotOutlineInvocationUpdate(_ payload: InvocationResponseDTO) async {
        updatePlotOutlineStatusFromInvocation(payload)

        // commit.result 有值时尝试提取
        if let result = payload.commit?.result {
            if let resultDict = result as? [String: Any] {
                let bindings = payload.session.outputBindings ?? []
                if applyPlotOutlineFromResult(result: resultDict, bindings: bindings) {
                    return
                }
            }
        }

        let commitStatus = payload.commit?.status ?? ""
        let sessionStatus = payload.session.status

        if commitStatus == "failed" || sessionStatus == "failed" || sessionStatus == "cancelled" || sessionStatus == "blocked" {
            failPlotOutlineInvocation(payload.commit?.error ?? "剧情总纲生成失败，请重试")
            return
        }

        if commitStatus == "succeeded" || sessionStatus == "completed" {
            let refreshed = await refreshPlotOutlineFromApi()
            if refreshed {
                finishPlotOutlineInvocation()
            } else {
                failPlotOutlineInvocation("剧情总纲生成完成，但未能读取结果，请重试")
            }
        }
    }

    /// 从审批状态更新剧情总纲状态 — NovelSetupGuide.vue:1205-1238
    private func updatePlotOutlineStatusFromInvocation(_ payload: InvocationResponseDTO) {
        let commitStatus = payload.commit?.status ?? ""
        let sessionStatus = payload.session.status

        if commitStatus == "succeeded" || sessionStatus == "completed" {
            plotOutlineStatus = .committing
            phaseMessage = "正在写入剧情总纲..."
            return
        }
        if commitStatus == "failed" || sessionStatus == "failed" || sessionStatus == "cancelled" || sessionStatus == "blocked" {
            return
        }
        if sessionStatus == "awaiting_commit" || sessionStatus == "committing" || commitStatus == "running" {
            plotOutlineStatus = .committing
            phaseMessage = "正在写入剧情总纲..."
            return
        }
        if sessionStatus == "generating" {
            plotOutlineStatus = .generating
            phaseMessage = "AI 正在生成剧情总纲..."
            return
        }
        if sessionStatus == "awaiting_acceptance" {
            plotOutlineStatus = .generating // Q8: aiInvocationDebug=false → generating
            phaseMessage = "正在确认剧情总纲生成..."
            return
        }
        if sessionStatus == "awaiting_pre_call_review" {
            plotOutlineStatus = .creating // Q8: aiInvocationDebug=false → creating
            phaseMessage = "正在准备剧情总纲生成..."
            return
        }
        plotOutlineStatus = .creating
        phaseMessage = "正在创建剧情总纲任务..."
    }

    /// 从 API 刷新剧情总纲 — NovelSetupGuide.vue:1240-1254
    private func refreshPlotOutlineFromApi() async -> Bool {
        guard let novelId = createdNovel?.id else { return false }
        do {
            let response: GeneratePlotOutlineResponse = try await apiClient.request(
                APIEndpoint.Workflow.getPlotOutline(novelId: novelId)
            )
            guard let outline = response.plotOutline else { return false }
            let normalized = normalizePlotOutlineShape(outline, totalChapters: targetChapters) ?? outline
            plotOutline = normalized
            syncEditablePlotOutline(normalized)
            plotOutlineCommitted = true
            if let novelId = createdNovel?.id {
                WizardUiCache.write(novelId: novelId, patch: WizardUiCachePatch(plotOutline: normalized))
            }
            return true
        } catch {
            return false
        }
    }

    /// 从审批结果提取剧情总纲 — NovelSetupGuide.vue:1256-1269
    private func applyPlotOutlineFromResult(result: [String: Any], bindings: [InvocationVariableBinding]) -> Bool {
        guard let outline = extractPlotOutlineFromResult(result, outputBindings: bindings, totalChapters: targetChapters) else {
            return false
        }
        plotOutline = outline
        syncEditablePlotOutline(outline)
        plotOutlineCommitted = true
        if let novelId = createdNovel?.id {
            WizardUiCache.write(novelId: novelId, patch: WizardUiCachePatch(plotOutline: outline))
        }
        finishPlotOutlineInvocation()
        return true
    }

    /// 完成剧情总纲审批 — NovelSetupGuide.vue:1182-1188
    private func finishPlotOutlineInvocation() {
        plotOutlineGenerating = false
        plotOutlineStatus = .done
        phaseMessage = ""
    }

    /// 失败 — NovelSetupGuide.vue:1190-1197
    private func failPlotOutlineInvocation(_ message: String) {
        plotOutlineError = message
        plotOutlineGenerating = false
        plotOutlineStatus = .error
        phaseMessage = ""
    }

    /// 重置状态 — NovelSetupGuide.vue:1199-1203
    private func resetPlotOutlineInvocationState() {
        plotOutlineGenerating = false
        plotOutlineStatus = .idle
        phaseMessage = ""
    }

    /// 同步编辑副本 — NovelSetupGuide.vue:1134-1140
    private func syncEditablePlotOutline(_ outline: PlotOutlineDTO?) {
        syncingPlotOutlineDraft = true
        editablePlotOutline = clonePlotOutline(outline, totalChapters: targetChapters)
        DispatchQueue.main.async { [weak self] in
            self?.syncingPlotOutlineDraft = false
        }
    }

    /// 更新阶段章节号 — NovelSetupGuide.vue:1146-1154
    func updateStageChapterNumber(index: Int, key: String, value: Int) {
        guard index < editablePlotOutline.stagePlan.count else { return }
        if key == "chapter_start" {
            editablePlotOutline.stagePlan[index].chapterStart = value > 0 ? value : nil
        } else if key == "chapter_end" {
            editablePlotOutline.stagePlan[index].chapterEnd = value > 0 ? value : nil
        }
        plotOutlineCommitted = false
    }

    /// 阶段范围标签 — NovelSetupGuide.vue:1156-1158
    func stageRangePercentLabel(index: Int) -> String {
        guard index < editablePlotOutline.stagePlan.count else { return "" }
        let stage = editablePlotOutline.stagePlan[index]
        return buildStageRangePercentLabel(stage, totalChapters: targetChapters)
    }

    /// 保存编辑 — NovelSetupGuide.vue:2033-2052
    func savePlotOutlineEdits() async -> Bool {
        guard let novelId = createdNovel?.id else { return false }
        let payload = buildEditablePlotOutlinePayload(editablePlotOutline, totalChapters: targetChapters)
        let validationError = validateEditablePlotOutline(payload)
        if !validationError.isEmpty {
            errorMessage = validationError
            return false
        }
        do {
            let response: GeneratePlotOutlineResponse = try await apiClient.request(
                APIEndpoint.Workflow.savePlotOutline(novelId: novelId),
                body: PlotOutlineSaveRequest(plotOutline: payload)
            )
            let saved = response.plotOutline ?? payload
            plotOutline = saved
            syncEditablePlotOutline(saved)
            plotOutlineCommitted = true
            WizardUiCache.write(novelId: novelId, patch: WizardUiCachePatch(plotOutline: saved))
            return true
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - 阶段3：Bible SSE approval_required 接线 — NovelSetupGuide.vue:1548-1550

    /// 覆写 handleDataEvent 中的 approval_required 分支
    /// 原版逻辑：openBibleReviewPanel → aiInvocationStore.open + onSessionUpdate
    /// iOS 接线：aiInvocationStore.openFromResponse
    private func handleBibleApprovalRequired(sessionId: String, stage: String) {
        guard !sessionId.isEmpty else { return }
        // 注册监听
        let _ = aiInvocationStore.onSessionUpdate(sessionId: sessionId) { [weak self] payload in
            Task { @MainActor in
                // Bible 审批完成后的处理
                if payload.session.status == "completed" || payload.commit?.status == "succeeded" {
                    // 审批完成，继续流程
                    self?.approvalMessage = ""
                }
            }
        }
        // 打开审批面板
        Task {
            do {
                try await aiInvocationStore.open(sessionId: sessionId)
            } catch {
                Logger.engine.error("Bible 审批面板打开失败: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - P0-1：suggestMainPlotOptionsStream 消费者（workflow.ts:581-680）

    /// 主线推荐选项（SSE 流式生成结果）
    @Published var mainPlotOptions: [MainPlotOptionDTO] = []

    /// 主线推荐流式 chunk 累积文本
    @Published var mainPlotOptionsChunkText: String = ""

    /// 主线推荐是否正在生成
    @Published var mainPlotOptionsGenerating: Bool = false

    /// 主线推荐错误
    @Published var mainPlotOptionsError: String = ""

    /// 启动主线推荐 SSE 流（workflow.ts:581-680 consumeMainPlotOptionsStream）
    /// POST /api/v1/novels/{novelId}/setup/suggest-main-plot-options-stream
    /// data-only 格式，6 类事件：phase/chunk/option/approval_required/done/error
    ///
    /// - Parameters:
    ///   - novelId: 小说 ID
    func startSuggestMainPlotOptionsStream(novelId: String) {
        mainPlotOptionsGenerating = true
        mainPlotOptions = []
        mainPlotOptionsChunkText = ""
        mainPlotOptionsError = ""
        errorMessage = nil

        Logger.engine.info("启动主线推荐 SSE 流: novel=\(novelId)")

        sseRegistry.startSuggestMainPlotOptionsStream(
            novelId: novelId,
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.handleMainPlotOptionsSSEEvent(event, novelId: novelId)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.mainPlotOptionsGenerating = false
                    self?.mainPlotOptionsError = "主线推荐连接失败: \(error.localizedDescription)"
                }
            }
        )
    }

    /// 处理主线推荐 SSE 事件（workflow.ts:617-660）
    private func handleMainPlotOptionsSSEEvent(_ event: SSEEvent, novelId: String) {
        // data-only 格式，用 mainPlotOptionsEventType 获取事件类型
        guard let eventType = event.mainPlotOptionsEventType else { return }
        guard let dict = event.decodeAsDictionary() else { return }

        switch eventType {
        case "phase":
            // workflow.ts:618-625
            let message = dict["message"] as? String ?? ""
            phaseMessage = message

        case "chunk":
            // workflow.ts:626-629
            let text = dict["text"] as? String ?? ""
            mainPlotOptionsChunkText += text

        case "option":
            // workflow.ts:630-635
            let optionDict = dict["option"] as? [String: Any] ?? [:]
            let index = dict["index"] as? Int ?? 0
            let option = MainPlotOptionDTO.fromDict(optionDict)
            // 确保 index 不越界
            while mainPlotOptions.count <= index {
                mainPlotOptions.append(MainPlotOptionDTO.empty)
            }
            mainPlotOptions[index] = option

        case "approval_required":
            // workflow.ts:636-647
            let sessionId = dict["session_id"] as? String ?? ""
            let status = dict["status"] as? String
            let nextAction = dict["next_action"] as? String
            if !sessionId.isEmpty {
                plotOutlineSessionId = sessionId
                Task { await openPlotOutlineReviewPanel(sessionId: sessionId) }
            }

        case "done":
            // workflow.ts:648-653
            let optionsArray = dict["plot_options"] as? [[String: Any]] ?? []
            mainPlotOptions = optionsArray.map { MainPlotOptionDTO.fromDict($0) }
            mainPlotOptionsGenerating = false
            sseRegistry.cancelSuggestMainPlotOptionsStream(novelId: novelId)

        case "error":
            // workflow.ts:654-660
            let message = dict["message"] as? String ?? "推演失败"
            mainPlotOptionsError = message
            mainPlotOptionsGenerating = false
            sseRegistry.cancelSuggestMainPlotOptionsStream(novelId: novelId)

        default:
            break
        }
    }

    /// 取消主线推荐 SSE 流
    func cancelSuggestMainPlotOptionsStream(novelId: String) {
        sseRegistry.cancelSuggestMainPlotOptionsStream(novelId: novelId)
        mainPlotOptionsGenerating = false
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

        // 重置 M1/M2 状态
        phaseMessage = ""
        styleText = ""
        worldbuildingData = emptyWorldbuildingData()
        worldbuildingRawStream = ""
        activeDimension = ""
        activeField = ""
        arrivedFields = []
        completedDimensions = []
        approvalMessage = ""
        streamingCharacters = []
        editableCharacters = []
        generatedCharacterDrafts = [:]
        generatingCharacters = false
        charactersGenerated = false
        charactersError = ""
        streamingLocations = []
        editableLocations = []
        generatingLocations = false
        locationsGenerated = false
        locationsError = ""
        generatingBible = false
        bibleGenerated = false
        bibleError = ""

        macroPlanEvents.removeAll()
        macroPlanStructure = nil
        isProcessing = false
        errorMessage = nil

        // 重置阶段3状态
        maxVisitedStep = 1
        plotOutline = nil
        editablePlotOutline = createEmptyPlotOutline()
        plotOutlineGenerating = false
        plotOutlineError = ""
        plotOutlineCommitted = false
        plotOutlineSessionId = ""
        step4RestoredFromCache = false
        syncingPlotOutlineDraft = false
        plotOutlineStatus = .idle
        aiInvocationStore.close()

        // 取消所有 SSE 流
        if let novelId = createdNovel?.id {
            sseRegistry.cancelAll(novelId: novelId)
        }
    }
}
