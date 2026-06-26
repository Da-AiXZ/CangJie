//
//  BrandFooterView.swift
//  Cangjie
//
//  品牌页脚（A-5），对齐原版 components/brand/BrandFooter.vue。
//  显示 productName · chineseName · credit · douyinLink · liveSchedule。
//

import SwiftUI

// MARK: - 品牌页脚视图

/// 品牌页脚，对齐原版 components/brand/BrandFooter.vue。
///
/// 显示：productName · chineseName · credit · douyinLink · liveSchedule
struct BrandFooterView: View {

    var body: some View {
        HStack(spacing: 6) {
            Text(Brand.productName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.primary)

            Text("·")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)

            Text(Brand.chineseName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.primary)

            Text(Brand.credit)
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)

            if let url = URL(string: Brand.douyinUrl) {
                Link(Brand.douyinLabel, destination: url)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.primary)
            }

            Text(Brand.liveSchedule)
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
    }
}
