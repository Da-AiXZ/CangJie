//
//  TensionDiagnosisModalView.swift
//  Cangjie
//
//  P0-5 张力诊断弹窗，对齐 WorkArea.vue L706-779。
//  问题描述输入 + 开始分析按钮 + 结果展示（张力等级 Tag + 诊断文本 + 缺失元素 Tag 列表 + 突破建议卡片列表）。
//

import SwiftUI

/// 张力诊断弹窗（对齐 WorkArea.vue L706-779）
struct TensionDiagnosisModalView: View {

    /// 当前小说 ID
    let novelId: String

    /// 当前章节号
    let chapterNumber: Int

    @EnvironmentObject var workbenchStore: WorkbenchStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 提示信息
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(Theme.info)
                        .font(.system(size: 14))
                    Text("诊断当前章节张力缺口，识别缺失元素并给出突破建议。")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(10)
                .background(Theme.info.opacity(0.08))
                .cornerRadius(8)

                // 问题描述输入
                VStack(alignment: .leading, spacing: 6) {
                    Text("问题描述（可选）")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)

                    TextEditor(text: $workbenchStore.tensionStuckReason)
                        .font(.system(size: 13))
                        .frame(minHeight: 40, maxHeight: 80)
                        .padding(4)
                        .background(Theme.secondaryBackground)
                        .cornerRadius(6)
                        .disabled(workbenchStore.tensionLoading)
                }

                // 开始分析按钮
                Button {
                    Task {
                        await workbenchStore.runTensionDiagnosis(
                            novelId: novelId,
                            chapterNumber: chapterNumber,
                            stuckReason: workbenchStore.tensionStuckReason
                        )
                    }
                } label: {
                    HStack {
                        if workbenchStore.tensionLoading {
                            ProgressView().scaleEffect(0.7)
                        }
                        Text("开始分析")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(workbenchStore.tensionLoading)

                // 结果展示
                if let result = workbenchStore.tensionResult {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        // 张力等级 Tag
                        HStack(spacing: 8) {
                            Text("张力等级")
                                .font(.system(size: 13, weight: .semibold))

                            Text(result.tensionLevelDisplay)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(tensionLevelColor(result.tensionLevel))
                                .cornerRadius(10)
                        }

                        // 诊断文本
                        VStack(alignment: .leading, spacing: 4) {
                            Text("诊断")
                                .font(.system(size: 13, weight: .semibold))
                            Text(result.diagnosis)
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // 缺失元素 Tag 列表
                        if !result.missingElements.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("缺失元素")
                                    .font(.system(size: 13, weight: .semibold))

                                FlowLayout(spacing: 6) {
                                    ForEach(result.missingElements, id: \.self) { element in
                                        Text(element)
                                            .font(.system(size: 11))
                                            .foregroundColor(Theme.warning)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Theme.warning.opacity(0.15))
                                            .cornerRadius(10)
                                    }
                                }
                            }
                        }

                        // 突破建议卡片列表
                        if !result.suggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("突破建议")
                                    .font(.system(size: 13, weight: .semibold))

                                ForEach(Array(result.suggestions.enumerated()), id: \.offset) { index, suggestion in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(index + 1). \(suggestion)")
                                            .font(.system(size: 12))
                                            .foregroundColor(Theme.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(10)
                                    .background(Theme.secondaryBackground)
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("张力诊断")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") {
                    workbenchStore.showTensionModal = false
                }
            }
        }
    }

    /// 张力等级颜色（对齐 WorkArea.vue L736-739）
    /// high=绿色"高张力" / medium=黄色"中等" / low=红色"低张力"
    private func tensionLevelColor(_ level: String) -> Color {
        switch level {
        case "high": return Theme.success
        case "medium": return Theme.warning
        case "low": return Theme.error
        default: return Theme.textSecondary
        }
    }
}
