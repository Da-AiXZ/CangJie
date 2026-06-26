//
//  StatCardView.swift
//  Cangjie
//
//  单项统计卡片，对齐原版 stats 组件目录中的统计卡片。
//

import SwiftUI

/// 单项统计卡片视图
struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    var trendColor: Color = Theme.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(trendColor)
                    .font(.system(size: 14))
                Spacer()
            }
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(12)
        .background(Theme.secondaryBackground)
        .cornerRadius(10)
    }
}
