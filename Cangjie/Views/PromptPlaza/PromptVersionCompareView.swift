//
//  PromptVersionCompareView.swift
//  Cangjie
//
//  版本对比：左右两版并排，差异高亮。
//

import SwiftUI

/// 提示词版本对比视图
struct PromptVersionCompareView: View {

    let versions: [PromptVersion]
    var onCompare: (String, String) -> Void
    let comparison: PromptComparison?

    @State private var v1Id: String = ""
    @State private var v2Id: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 版本选择
                HStack {
                    versionPicker(selection: $v1Id, label: "版本 A")
                    versionPicker(selection: $v2Id, label: "版本 B")

                    Button("对比") {
                        if !v1Id.isEmpty && !v2Id.isEmpty {
                            onCompare(v1Id, v2Id)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(v1Id.isEmpty || v2Id.isEmpty || v1Id == v2Id)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.secondaryBackground)

                // 对比结果
                if let comparison = comparison {
                    ScrollView {
                        HStack(alignment: .top, spacing: 0) {
                            // 版本 A
                            VStack(alignment: .leading, spacing: 4) {
                                Text("版本 A")
                                    .font(Theme.headlineFont())
                                Text(comparison.v1Content)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(Theme.Spacing.md)

                            Divider()

                            // 版本 B
                            VStack(alignment: .leading, spacing: 4) {
                                Text("版本 B")
                                    .font(Theme.headlineFont())
                                Text(comparison.v2Content)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(Theme.Spacing.md)
                        }
                    }

                    // 差异
                    if let diff = comparison.diff, !diff.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("差异")
                                .font(Theme.headlineFont())
                            Text(diff)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.tertiaryBackground)
                    }
                } else {
                    VStack {
                        Image(systemName: "arrow.left.and.right.square")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.textTertiary)
                        Text("选择两个版本进行对比")
                            .font(Theme.bodyFont())
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .navigationTitle("版本对比")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                if versions.count >= 2 {
                    v1Id = versions[0].id
                    v2Id = versions[1].id
                }
            }
        }
    }

    // MARK: - 版本选择器

    private func versionPicker(selection: Binding<String>, label: String) -> some View {
        Picker(label, selection: selection) {
            ForEach(versions) { version in
                Text("v\(version.versionNumber)").tag(version.id)
            }
        }
        .pickerStyle(.menu)
    }
}
