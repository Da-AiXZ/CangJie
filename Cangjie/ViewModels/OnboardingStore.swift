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

/// 新书向导步骤（Q4决策：3步，去掉 macroPlanning UI 入口）
enum OnboardingStep: Int, CaseIterable, Comparable {
    case novelInfo = 0
    case bibleGeneration = 1
    case characterSetup = 2
    case locationSetup = 3
    case macroPlanning = 4  // 保留枚举值（工作台 MacroPlanModal 仍在用），向导 UI 不走此步
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
            // Q1/Q2决策：显示提示，不阻塞流程
            let sessionId = dict["session_id"] as? String ?? ""
            let status = dict["status"] as? String
            let nextAction = dict["next_action"] as? String
            let stageStr = dict["stage"] as? String

            if !sessionId.isEmpty {
                approvalMessage = "需要AI审批（审批面板后续实现）"
                if let status = status {
                    approvalMessage += " [\(status)]"
                }
                Logger.engine.info("Bible SSE approval_required: sessionId=\(sessionId), status=\(status ?? ""), nextAction=\(nextAction ?? ""), stage=\(stageStr ?? "")")
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

        // 取消所有 SSE 流
        if let novelId = createdNovel?.id {
            sseRegistry.cancelAll(novelId: novelId)
        }
    }
}
