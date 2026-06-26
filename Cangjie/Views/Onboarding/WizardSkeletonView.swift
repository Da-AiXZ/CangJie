//
//  WizardSkeletonView.swift
//  Cangjie
//
//  引导页骨架屏（A-3），对齐原版 components/onboarding/WizardSkeleton.vue。
//  4 种 type：worldbuilding（维度状态）/characters（角色卡片）/locations（地图+列表）/storyline（故事线卡片）。
//

import SwiftUI

// MARK: - 骨架屏类型

/// 骨架屏类型，对齐原版 WizardSkeleton.vue:101 type
enum WizardSkeletonType: String, CaseIterable {
    case worldbuilding
    case characters
    case locations
    case storyline
}

// MARK: - 世界观维度定义

/// 世界观维度定义，对齐原版 WizardSkeleton.vue:116-122 dimensions
private let WIZARD_DIMENSIONS: [(key: String, label: String)] = [
    ("core_rules", "核心法则"),
    ("geography", "地理生态"),
    ("society", "社会结构"),
    ("culture", "历史文化"),
    ("daily_life", "沉浸感细节"),
]

// MARK: - 骨架屏视图

/// 引导页骨架屏，对齐原版 components/onboarding/WizardSkeleton.vue。
///
/// 4 种 type：worldbuilding/characters/locations/storyline。
/// shimmer 动画 + 状态指示器（等待中/生成中/已生成）。
struct WizardSkeletonView: View {

    /// 骨架屏类型
    let type: WizardSkeletonType

    /// 世界观：当前正在生成的维度 key
    var activeDimension: String = ""

    /// 世界观：已完成的维度 key 集合
    var completedDimensions: Set<String> = []

    /// 人物/地点：已完成的数量
    var completedCount: Int = 0

    /// shimmer 动画状态
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        Group {
            switch type {
            case .worldbuilding:
                worldbuildingSkeleton
            case .characters:
                charactersSkeleton
            case .locations:
                locationsSkeleton
            case .storyline:
                storylineSkeleton
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 200
            }
        }
    }

    // MARK: - 世界观维度骨架

    private var worldbuildingSkeleton: some View {
        VStack(spacing: 8) {
            ForEach(WIZARD_DIMENSIONS, id: \.key) { dim in
                let isActive = activeDimension == dim.key && !completedDimensions.contains(dim.key)
                let isDone = completedDimensions.contains(dim.key)

                HStack(spacing: 10) {
                    // 状态圆点
                    ZStack {
                        Circle()
                            .stroke(isDone ? Theme.success : (isActive ? Theme.primary : Color.gray.opacity(0.3)), lineWidth: 2)
                            .frame(width: 16, height: 16)

                        if isDone {
                            Text("✓")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        } else if isActive {
                            Circle()
                                .fill(Theme.primary)
                                .frame(width: 6, height: 6)
                        }
                    }

                    Text(dim.label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textPrimary)

                    Spacer()

                    // 状态标签
                    if isDone {
                        Text("已生成")
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.success.opacity(0.12))
                            .foregroundColor(Theme.success)
                            .cornerRadius(4)
                    } else if isActive {
                        Text("生成中")
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.info.opacity(0.12))
                            .foregroundColor(Theme.info)
                            .cornerRadius(4)
                    } else {
                        Text("等待中")
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(Theme.textTertiary)
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isDone ? Theme.success.opacity(0.05) : (isActive ? Theme.primary.opacity(0.05) : Theme.secondaryBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isDone ? Theme.success.opacity(0.3) : (isActive ? Theme.primary.opacity(0.3) : Color.gray.opacity(0.15)), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - 人物骨架

    private var charactersSkeleton: some View {
        VStack(spacing: 12) {
            ForEach(1...3, id: \.self) { i in
                let isDone = i <= completedCount

                HStack(spacing: 12) {
                    // 头像占位
                    ZStack {
                        Circle()
                            .fill(isDone ? Theme.success.opacity(0.15) : Color.gray.opacity(0.1))
                            .frame(width: 40, height: 40)

                        if isDone {
                            Text("✓")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.success)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        // 名字骨架条
                        skeletonBar(width: 80, height: 16, shimmer: !isDone)
                        // 描述骨架条
                        skeletonBar(width: 160, height: 12, shimmer: !isDone)
                    }
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isDone ? Theme.success.opacity(0.05) : Theme.secondaryBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isDone ? Theme.success.opacity(0.3) : Color.gray.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - 地点骨架

    private var locationsSkeleton: some View {
        VStack(spacing: 12) {
            // 地图占位
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.secondaryBackground)
                    .frame(height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )

                VStack(spacing: 12) {
                    ProgressView()
                    Text("地图生成中…")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textTertiary)
                }
            }

            // 地点列表
            VStack(spacing: 8) {
                ForEach(1...4, id: \.self) { i in
                    let isDone = i <= completedCount
                    VStack(alignment: .leading, spacing: 4) {
                        skeletonBar(width: 100, height: 14, shimmer: !isDone)
                        skeletonBar(width: 200, height: 12, shimmer: !isDone)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isDone ? Theme.success.opacity(0.05) : Theme.secondaryBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isDone ? Theme.success.opacity(0.3) : Color.gray.opacity(0.15), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - 故事线骨架

    private var storylineSkeleton: some View {
        VStack(spacing: 12) {
            ForEach(1...3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 6) {
                    skeletonBar(width: 120, height: 18, shimmer: true)
                    skeletonBar(width: 220, height: 12, shimmer: true)
                    skeletonBar(width: 110, height: 12, shimmer: true)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.secondaryBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - 骨架条

    private func skeletonBar(width: CGFloat, height: CGFloat, shimmer: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(shimmer ? shimmerGradient : Color.gray.opacity(0.15))
            .frame(width: width, height: height)
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.gray.opacity(0.15),
                Color.gray.opacity(0.25),
                Color.gray.opacity(0.15)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
