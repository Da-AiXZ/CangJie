//
//  AutopilotControlSection.swift
//  Cangjie
//
//  自动驾驶默认配置：目标章数/最大自动章数/熔断器阈值。
//

import SwiftUI

/// 自动驾驶设置分区
struct AutopilotControlSection: View {

    @AppStorage("cangjie.autopilot.defaultTargetChapters") private var defaultTargetChapters: Int = 100
    @AppStorage("cangjie.autopilot.defaultMaxAutoChapters") private var defaultMaxAutoChapters: Int = 9999
    @AppStorage("cangjie.autopilot.breakerThreshold") private var breakerThreshold: Int = 5
    @AppStorage("cangjie.autopilot.autoApproveMode") private var autoApproveMode: Bool = false

    var body: some View {
        Stepper("默认目标章数：\(defaultTargetChapters)", value: $defaultTargetChapters, in: 1...9999, step: 10)
        Stepper("最大自动章数：\(defaultMaxAutoChapters)", value: $defaultMaxAutoChapters, in: 1...9999, step: 10)
        Stepper("熔断器阈值：\(breakerThreshold) 次", value: $breakerThreshold, in: 1...20, step: 1)

        Toggle("全自动模式（跳过所有人工审阅）", isOn: $autoApproveMode)
            .tint(autoApproveMode ? Theme.warning : Theme.primary)

        if autoApproveMode {
            Text("⚠️ 开启后系统将跳过所有审阅环节，自动运行直到写完")
                .font(.system(size: 11))
                .foregroundColor(Theme.warning)
        }
    }
}
