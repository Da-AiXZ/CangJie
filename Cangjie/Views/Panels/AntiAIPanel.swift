//
//  AntiAIPanel.swift
//  Cangjie
//
//  Anti-AI 防御系统（七层防御+扫描+统计+分类+规则+白名单），对齐 AntiAIDashboard.vue:1-1043。
//

import SwiftUI

struct AntiAIPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var workbenchStore: WorkbenchStore
    @StateObject private var store = AntiAIStore()

    @State private var activeSubTab: String = "overview"
    @State private var scanInput: String = ""
    @State private var showTutorial = false

    private let subTabs = [
        ("overview", "概览"),
        ("scan", "快速扫描"),
        ("rules", "规则"),
        ("allowlist", "白名单"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            subTabBar
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch activeSubTab {
                    case "overview": overviewTab
                    case "scan": scanTab
                    case "rules": rulesTab
                    case "allowlist": allowlistTab
                    default: overviewTab
                    }
                }
                .padding(16)
            }
        }
        .background(Theme.background)
        .task {
            await store.loadAll()
        }
        .sheet(isPresented: $showTutorial) {
            tutorialSheet
        }
    }

    // MARK: - Header — AntiAIDashboard.vue:4-8
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Anti-AI 防御系统").font(.system(size: 16, weight: .bold))
                Text("七层纵深防御体系 · 让 AI 写出来的文字不再像 AI")
                    .font(.system(size: 11)).foregroundColor(Theme.textTertiary)
            }
            Spacer()
            Button("使用教程") { showTutorial = true }
                .buttonStyle(.bordered).controlSize(.small)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // MARK: - Sub tabs — AntiAIDashboard.vue:17-27
    private var subTabBar: some View {
        HStack(spacing: 0) {
            ForEach(subTabs, id: \.0) { key, label in
                Button { activeSubTab = key } label: {
                    Text(label)
                        .font(.system(size: 12, weight: activeSubTab == key ? .semibold : .regular))
                        .foregroundColor(activeSubTab == key ? Theme.primary : Theme.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .overlay(
                            Rectangle()
                                .fill(activeSubTab == key ? Theme.primary : Color.clear)
                                .frame(height: 2),
                            alignment: .bottom
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .overlay(
            Rectangle().fill(Theme.textTertiary.opacity(0.2)).frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - 概览 Tab — AntiAIDashboard.vue:32-77
    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 七层防御网格
            Text("七层防御体系").font(.system(size: 14, weight: .semibold))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(defenseLayers, id: \.key) { layer in
                    defenseCard(layer)
                }
            }

            // 系统统计 — AntiAIDashboard.vue:56-76
            if let stats = store.stats {
                Text("系统统计").font(.system(size: 14, weight: .semibold))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    statCard("总提示词数", "\(stats.totalPrompts)", Theme.primary)
                    statCard("Anti-AI 提示词", "\(stats.antiAiPrompts)", Color(red: 0.85, green: 0.28, blue: 0.94))
                    statCard("俗套检测模式", "\(stats.clichePatterns)", Theme.primary)
                    statCard("分类数", "\(stats.categoriesCount)", Theme.primary)
                }
            }
        }
    }

    // 七层防御定义 — AntiAIDashboard.vue:423-483
    private struct DefenseLayer: Identifiable {
        let key: String
        var id: String { key }
        let name: String
        let desc: String
        let color: Color
        let active: Bool
    }

    private var defenseLayers: [DefenseLayer] {
        let layers = store.stats?.layers
        return [
            DefenseLayer(key: "L1", name: "L1 正向行为映射", desc: "将否定指令转为确定性的动作映射", color: Color(red: 0.39, green: 0.40, blue: 0.95), active: true),
            DefenseLayer(key: "L2", name: "L2 核心协议 P1-P5", desc: "五大写作法则：密度/感官/差异/节奏/衔接", color: Color(red: 0.55, green: 0.36, blue: 0.96), active: true),
            DefenseLayer(key: "L3", name: "L3 场景化白名单", desc: "不同场景的差异化模式豁免", color: Color(red: 0.66, green: 0.33, blue: 0.97), active: (layers?.l3AllowlistScenes ?? 0) > 0),
            DefenseLayer(key: "L4", name: "L4 角色状态向量", desc: "声线指纹/紧张习惯/反应模式/信息边界", color: Color(red: 0.85, green: 0.28, blue: 0.94), active: layers?.l4StateVector == "active"),
            DefenseLayer(key: "L5", name: "L5 上下文配额", desc: "洋葱模型配额分配，T0 永不压缩", color: Color(red: 0.93, green: 0.28, blue: 0.60), active: layers?.l5ContextQuota == "active"),
            DefenseLayer(key: "L6", name: "L6 Token 级拦截", desc: "AC自动机流式扫描 + Logit Bias 抑制", color: Color(red: 0.96, green: 0.25, blue: 0.37), active: layers?.l6TokenGuard == "active"),
            DefenseLayer(key: "L7", name: "L7 章后审计", desc: "35+模式检测 + 指标趋势 + 自适应学习", color: Color(red: 0.94, green: 0.27, blue: 0.27), active: layers?.l7Audit == "active"),
        ]
    }

    private func defenseCard(_ layer: DefenseLayer) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(layer.name).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.textPrimary)
                Text(layer.desc).font(.system(size: 10)).foregroundColor(Theme.textTertiary).lineLimit(2)
            }
            Spacer()
            Text(layer.active ? "运行中" : "未激活")
                .font(.system(size: 9))
                .foregroundColor(layer.active ? Theme.success : Theme.textTertiary)
        }
        .padding(10)
        .background(Theme.secondaryBackground)
        .overlay(
            Rectangle().fill(layer.color).frame(width: 3), alignment: .leading
        )
        .cornerRadius(8)
    }

    private func statCard(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(color)
            Text(label).font(.system(size: 10)).foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - 快速扫描 Tab — AntiAIDashboard.vue:82-199
    private var scanTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("粘贴一段文本，检测其中的 AI 味模式")
                .font(.system(size: 11)).foregroundColor(Theme.textTertiary)

            TextField("在此粘贴要检测的文本…", text: $scanInput, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(5...14)

            HStack {
                Button {
                    Task { await store.scan(content: scanInput) }
                } label: {
                    Label("开始扫描", systemImage: "sparkles.magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(scanInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isScanning)

                if !scanInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("清空") { scanInput = "" }
                        .buttonStyle(.borderless).controlSize(.small)
                }
            }

            // 扫描结果
            if let result = store.scanResult {
                scanResultView(result)
            }
        }
    }

    private func scanResultView(_ result: AntiAIScanResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 总评+分数 — AntiAIDashboard.vue:108-114
            HStack {
                Text(result.overallAssessment)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(AntiAIAssessment.color(for: result.overallAssessment))
                Spacer()
                Text("严重性分数：") + Text("\(Int(result.severityScore))").bold() + Text("/100")
            }

            // 统计3项 — AntiAIDashboard.vue:117-130
            HStack(spacing: 20) {
                statItem("\(result.criticalHits)", "严重", Theme.error)
                statItem("\(max(0, result.warningHits - result.criticalHits))", "警告", Theme.warning)
                statItem("\(result.totalHits)", "总命中", Theme.textPrimary)
            }

            // 分类分布 — AntiAIDashboard.vue:133-151
            if !result.categoryDistribution.isEmpty {
                Text("分类分布").font(.system(size: 12, weight: .semibold))
                ForEach(result.categoryDistribution.sorted(by: { $0.value > $1.value }), id: \.key) { cat, count in
                    HStack(spacing: 8) {
                        Text(cat).font(.system(size: 10)).frame(width: 60, alignment: .trailing)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Theme.primary.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(LinearGradient(colors: [Theme.primary, Color.purple], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * CGFloat(result.totalHits > 0 ? count : 0) / CGFloat(max(result.totalHits, 1)))
                                )
                        }
                        .frame(height: 8)
                        Text("\(count)").font(.system(size: 10, weight: .semibold)).frame(width: 24)
                    }
                }
            }

            // 改进建议 — AntiAIDashboard.vue:154-163
            if !result.improvementSuggestions.isEmpty {
                Text("改进建议").font(.system(size: 12, weight: .semibold))
                ForEach(result.improvementSuggestions, id: \.self) { sug in
                    Text(sug).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                        .padding(8).background(Theme.secondaryBackground)
                        .cornerRadius(4)
                        .overlay(Rectangle().fill(Theme.success).frame(width: 3), alignment: .leading)
                }
            }

            // 修改建议 — AntiAIDashboard.vue:166-175
            if !result.recommendations.isEmpty {
                Text("修改建议").font(.system(size: 12, weight: .semibold))
                ForEach(result.recommendations, id: \.self) { rec in
                    Text(rec).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                        .padding(8).background(Theme.secondaryBackground)
                        .cornerRadius(4)
                        .overlay(Rectangle().fill(Theme.warning).frame(width: 3), alignment: .leading)
                }
            }

            // 命中详情 — AntiAIDashboard.vue:178-196
            if !result.hits.isEmpty {
                Text("命中详情 (\(result.hits.count))").font(.system(size: 12, weight: .semibold))
                ForEach(Array(result.hits.prefix(30))) { hit in
                    HStack(spacing: 6) {
                        Text(hit.severity)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(severityColor(hit.severity))
                            .cornerRadius(3)
                        Text(hit.pattern).font(.system(size: 11, weight: .medium)).lineLimit(1)
                        Text(hit.text).font(.system(size: 9, design: .monospaced))
                            .lineLimit(1).truncationMode(.tail)
                            .foregroundColor(Theme.textTertiary)
                        Spacer()
                        if !hit.replacementHint.isEmpty {
                            Text("→ \(hit.replacementHint)").font(.system(size: 9)).foregroundColor(Theme.primary)
                        }
                    }
                    .padding(6)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(4)
                    .overlay(
                        Rectangle().fill(severityColor(hit.severity)).frame(width: 3), alignment: .leading
                    )
                }
                if result.hits.count > 30 {
                    Text("还有 \(result.hits.count - 30) 处命中…")
                        .font(.system(size: 10)).foregroundColor(Theme.textTertiary)
                        .frame(maxWidth: .infinity).padding(.top, 4)
                }
            }
        }
        .padding(.top, 8)
    }

    private func statItem(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 10)).foregroundColor(Theme.textTertiary)
        }
    }

    private func severityColor(_ s: String) -> Color {
        switch s.lowercased() {
        case "critical": return Theme.error
        case "warning": return Theme.warning
        case "info": return Theme.info
        default: return Theme.textSecondary
        }
    }

    // MARK: - 规则 Tab — AntiAIDashboard.vue:204-237
    private var rulesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("正向行为映射规则：将\"禁止 X\"重构为\"当遇到场景 Y 时，必须执行 Z\"，避免否定指令在 Transformer Self-Attention 中激活被禁止的 Token。")
                .font(.system(size: 11)).foregroundColor(Theme.textTertiary)

            if store.rulesLoading {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else if store.rules.isEmpty {
                Text("暂无规则数据").font(.system(size: 12)).foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity).padding()
            } else {
                ForEach(store.rules) { rule in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(rule.severity)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(severityColor(rule.severity))
                                .cornerRadius(3)
                            Text(rule.antiPattern).font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text(rule.category)
                                .font(.system(size: 9))
                                .foregroundColor(Theme.info)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Theme.info.opacity(0.12))
                                .cornerRadius(3)
                        }
                        HStack(spacing: 4) {
                            Text("正向动作：").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.success)
                            Text(rule.positiveAction).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding(10)
                    .background(Theme.secondaryBackground)
                    .overlay(Rectangle().fill(Theme.primary).frame(width: 3), alignment: .leading)
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - 白名单 Tab — AntiAIDashboard.vue:242-295
    private var allowlistTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("在战斗/悬疑/恐怖/告白等特定场景中，部分"AI味"模式是被允许的。白名单不等于滥用——即使在允许的场景中也有密度限制。")
                .font(.system(size: 11)).foregroundColor(Theme.textTertiary)

            if store.allowlistLoading {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else if store.allowlistScenes.isEmpty {
                Text("暂无白名单数据").font(.system(size: 12)).foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity).padding()
            } else {
                ForEach(store.allowlistScenes) { scene in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text(AntiAIAssessment.sceneLabel(scene.sceneType))
                                .font(.system(size: 13, weight: .semibold))
                            Text(scene.sceneType)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(Theme.textTertiary)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Theme.tertiaryBackground).cornerRadius(3)
                            Spacer()
                            Text("密度上限: \(scene.maxDensityPer1000)/千字")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.info)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Theme.info.opacity(0.12)).cornerRadius(3)
                        }
                        Text(scene.description).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                        if !scene.allowedCategories.isEmpty {
                            HStack(spacing: 4) {
                                Text("豁免分类：").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.textTertiary)
                                ForEach(scene.allowedCategories, id: \.self) { cat in
                                    Text(cat)
                                        .font(.system(size: 9))
                                        .foregroundColor(Theme.success)
                                        .padding(.horizontal, 4).padding(.vertical, 1)
                                        .background(Theme.success.opacity(0.12)).cornerRadius(3)
                                }
                            }
                        }
                        if !scene.allowedPatterns.isEmpty {
                            HStack(spacing: 4) {
                                Text("豁免模式：").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.textTertiary)
                                ForEach(scene.allowedPatterns, id: \.self) { pat in
                                    Text(pat)
                                        .font(.system(size: 9))
                                        .foregroundColor(Theme.textSecondary)
                                        .padding(.horizontal, 4).padding(.vertical, 1)
                                        .background(Theme.tertiaryBackground).cornerRadius(3)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - 教程弹窗 — AntiAIDashboard.vue:298-385
    private var tutorialSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    tutorialSection("这是什么？", """
                    Anti-AI 防御系统是一套工程化的"去AI味"治理方案，从提示词重构到 Token 级拦截，建立七层纵深防御体系。
                    传统做法是在提示词中写"不要写X"，但这反而激活了 Transformer 中的 X Token。我们的正向行为映射策略把"禁止X"改为"当遇到Y时执行Z"。
                    """)

                    tutorialSection("七层防御体系", """
                    L1 正向行为映射：把"禁止X"改为"当遇到Y时执行Z"
                    L2 核心协议 P1-P5：信息密度/感官优先/角色差异/节奏/衔接
                    L3 场景化白名单：战斗允许生理描写，悬疑允许微表情
                    L4 角色状态向量：声线指纹/紧张习惯/反应模式/信息边界
                    L5 上下文配额：洋葱模型配额分配，Anti-AI 协议永远不被压缩
                    L6 Token 级拦截：AC 自动机流式扫描 + Logit Bias 抑制
                    L7 章后审计：35+ 模式检测、指标趋势追踪、自适应学习
                    """)

                    tutorialSection("如何使用？", """
                    1. 在提示词广场的 Anti-AI 防御分类中查看和编辑防御提示词
                    2. 使用快速扫描标签页检测文本中的 AI 味
                    3. 在规则标签页中查看正向行为映射规则
                    4. 在白名单标签页中了解各场景的豁免规则
                    5. 生成章节时，系统会自动注入 Anti-AI 行为协议到 T0 槽位
                    6. 章节生成后，系统会自动运行 Anti-AI 审计管线
                    7. 在 API 端点 /api/v1/anti-ai/scan 中可以程序化调用扫描
                    """)

                    tutorialSection("35+ 检测模式一览", """
                    微表情：嘴角上扬、眼里闪过、指尖泛白、一丝系列、下意识等
                    声线：带语气前缀、声线变化、字字带X、不容置疑等
                    比喻：仿佛/宛如/犹如、心湖涟漪、小动物比喻等
                    生理性：生理性泪水/水雾、生理性前缀等
                    情绪标签：直接情绪标签、心中波澜等
                    句式：不是而是、破折号等
                    俗套：面部大忌、身体大忌、四肢百骸等
                    严禁词：死死等
                    """)

                    tutorialSection("注意事项", """
                    • 白名单不等于滥用——即使在允许的场景中，也有密度限制
                    • 角色状态锁是防止"记忆漂移"的关键，请确保 Bible 中的角色信息完整
                    • AC 自动机对中文检测更准确，Logit Bias 仅用于英文 Token
                    • 学习服务发现的新模式需要人工审核通过后才会生效
                    • 正向行为映射的核心是"不要写禁止，要写替代"
                    • 章节审计是全自动的，每次生成章节后自动运行
                    """)
                }
                .padding(16)
            }
            .navigationTitle("Anti-AI 防御系统使用教程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showTutorial = false }
                }
            }
        }
    }

    private func tutorialSection(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(content).font(.system(size: 12)).foregroundColor(Theme.textSecondary)
        }
    }
}
