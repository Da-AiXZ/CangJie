//
//  SettingsView.swift
//  Cangjie
//
//  设置主页 List 分区（外观/写作偏好/自动驾驶/模型引擎/服务器连接/关于）。
//  对齐 Vue3 AppSettingsShell 的设置面板布局。
//

import SwiftUI

/// 设置主页
struct SettingsView: View {

    @EnvironmentObject var settingsStore: SettingsStore

    var body: some View {
        List {
            // 外观
            Section {
                AppearanceSection()
            } header: {
                Text("外观")
            }

            // 写作偏好
            Section {
                WritingPrefsSection()
            } header: {
                Text("写作偏好")
            }

            // 自动驾驶
            Section {
                AutopilotControlSection()
            } header: {
                Text("自动驾驶")
            }

            // 模型引擎
            Section {
                LLMConfigSection()
            } header: {
                Text("模型引擎")
            }

            // 服务器连接
            Section {
                ServerConnectionSection()
            } header: {
                Text("服务器连接")
            }

            // 关于
            Section {
                AboutSection()
            } header: {
                Text("关于")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .environmentObject(settingsStore)
    }
}
