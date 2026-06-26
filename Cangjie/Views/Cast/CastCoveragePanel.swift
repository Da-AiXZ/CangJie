//
//  CastCoveragePanel.swift
//  Cangjie
//
//  Cast 对照面板，显示角色在章节中的出场覆盖情况。
//  对齐原版 Cast.vue Coverage 区域。
//

import SwiftUI

/// 角色覆盖对照面板
struct CastCoveragePanel: View {
    let novelId: String

    @State private var coverage: AnyCodable?
    @State private var loading: Bool = false

    private let apiClient = APIClient.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("角色覆盖", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.primary)
                Spacer()
                if loading {
                    ProgressView().scaleEffect(0.6)
                }
            }

            if let coverage = coverage?.dictionaryValue {
                // 显示覆盖统计
                ForEach(coverage.sorted(by: { $0.key < $1.key }), id: \.key) { name, data in
                    HStack {
                        Text(name)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Text("\(data ?? 0)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(4)
                }
            } else if !loading {
                Text("暂无覆盖数据")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding(8)
        .background(Theme.background)
        .task {
            await loadCoverage()
        }
    }

    private func loadCoverage() async {
        loading = true
        do {
            let data = try await apiClient.download(
                APIEndpoint.Cast.coverage(novelId: novelId)
            )
            coverage = try? CangjieDecoder.shared.decode(AnyCodable.self, from: data)
        } catch {
            coverage = nil
        }
        loading = false
    }
}
