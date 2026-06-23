//
//  WritingPrefsSection.swift
//  Cangjie
//
//  写作偏好：默认章数/每章字数/摘要章数/全托管模式，调 SettingsStore。
//

import SwiftUI

/// 写作偏好设置分区
struct WritingPrefsSection: View {

    @AppStorage("cangjie.writing.defaultChapters") private var defaultChapters: Int = 100
    @AppStorage("cangjie.writing.defaultWordsPerChapter") private var defaultWordsPerChapter: Int = 2500
    @AppStorage("cangjie.writing.inlineProseAggregation") private var inlineProseAggregation: Bool = true
    @AppStorage("cangjie.writing.phaseDisplayMode") private var phaseDisplayMode: String = "detailed"
    @AppStorage("cangjie.autopilot.convergeThreshold") private var convergeThreshold: Double = 0.85
    @AppStorage("cangjie.autopilot.landThreshold") private var landThreshold: Double = 0.75

    var body: some View {
        Stepper("默认章数：\(defaultChapters)", value: $defaultChapters, in: 1...9999, step: 10)
        Stepper("每章字数：\(defaultWordsPerChapter)", value: $defaultWordsPerChapter, in: 500...20000, step: 500)

        Toggle("内联散文聚合", isOn: $inlineProseAggregation)

        Picker("阶段显示模式", selection: $phaseDisplayMode) {
            Text("详细").tag("detailed")
            Text("简洁").tag("simple")
        }

        // 全托管阈值
        VStack(alignment: .leading, spacing: 4) {
            Text("指挥器收敛阈值：\(String(format: "%.2f", convergeThreshold))")
                .font(.system(size: 13))
            Slider(value: $convergeThreshold, in: 0.5...1.0, step: 0.05)
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("指挥器着陆阈值：\(String(format: "%.2f", landThreshold))")
                .font(.system(size: 13))
            Slider(value: $landThreshold, in: 0.5...1.0, step: 0.05)
        }
    }
}
