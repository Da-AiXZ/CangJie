import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        NavigationSplitView {
            List {
                Section("M0 验证") {
                    Label("SQLite 草稿", systemImage: "doc.text")
                    Label("Checkpoint", systemImage: "arrow.clockwise.circle")
                    Label("Keychain", systemImage: "key")
                    Label("SSE 流", systemImage: "wave.3.right")
                }
                Section("边界") {
                    Text("这里只验证本地存储、凭证、流式网络和恢复链路；完整写作 Agent 将按 M1–M5 逐步实现。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("仓颉")
        } detail: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("M0 可行性工作台")
                            .font(.title2.bold())
                            .accessibilityIdentifier("m0-title")
                        Text(model.status)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("status-label")
                    }
                    Spacer()
                    Button("保存", action: model.saveDraft)
                        .buttonStyle(.bordered)
                    Button("检查点") { model.createCheckpoint(reason: "manual") }
                        .buttonStyle(.borderedProminent)
                }

                TextEditor(text: $model.draft)
                    .font(.system(.body, design: .serif))
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("M0 草稿编辑器")
                    .accessibilityIdentifier("draft-editor")

                Divider()

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        keychainProbe
                        streamingProbe
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        keychainProbe
                        streamingProbe
                    }
                }
                .frame(maxHeight: 230)
            }
            .padding(20)
            .navigationTitle("仓颉")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var keychainProbe: some View {
        GroupBox("Keychain 最小实验") {
            VStack(alignment: .leading, spacing: 10) {
                SecureField("输入临时测试值（不会写入数据库）", text: $model.apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("保存到 Keychain", action: model.saveProbeKey)
                    Button("删除", action: model.deleteProbeKey)
                        .disabled(!model.hasStoredKey)
                    Label(
                        model.hasStoredKey ? "已保存" : "未保存",
                        systemImage: model.hasStoredKey ? "checkmark.shield" : "shield"
                    )
                    .foregroundStyle(model.hasStoredKey ? .green : .secondary)
                }
            }
            .padding(.top, 4)
        }
    }

    private var streamingProbe: some View {
        GroupBox("HTTPS SSE 最小实验") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("https://你的测试端点", text: $model.streamURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button(model.isStreaming ? "重新开始" : "开始", action: model.startStreamingProbe)
                    Button("取消", action: model.cancelStreamingProbe)
                        .disabled(!model.isStreaming)
                }
                ScrollView {
                    Text(model.streamOutput.isEmpty ? "等待流式数据…" : model.streamOutput)
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 80)
            }
            .padding(.top, 4)
        }
    }
}