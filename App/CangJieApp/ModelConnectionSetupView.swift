import CangJieCore
import Foundation
import SwiftUI
import UIKit

struct ModelConnectionManagementPage: View {
    @ObservedObject var setup: ModelConnectionSetupController
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !setup.savedConnections.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("已保存的连接")
                            .font(.headline)
                        ForEach(setup.savedConnections.map(\.connection)) { connection in
                            let isAvailable = setup.canUseForGeneration(connection)
                            Button {
                                _ = try? setup.selectCurrentConnection(connection.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(connection.name)
                                        Text(connection.selectedModel)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if !isAvailable {
                                            Text("当前版本暂不支持真实任务")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if setup.currentConnection?.id == connection.id {
                                        Text("当前")
                                            .font(.caption.weight(.semibold))
                                    } else if !isAvailable {
                                        Image(systemName: "lock.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(!isAvailable)
                            .accessibilityValue(
                                !isAvailable
                                    ? "当前版本暂不支持真实任务"
                                    : setup.currentConnection?.id == connection.id
                                        ? "当前连接"
                                        : "未选择"
                            )
                            .accessibilityIdentifier("saved-model-connection-\(connection.id.uuidString)")
                        }
                    }
                    .padding(.horizontal)
                }
                ModelConnectionSetupCard(setup: setup, cancelTitle: "重新开始") {
                    setup.openManagement()
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("模型连接")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setup.openManagement()
        }
        .onDisappear(perform: onClose)
        .accessibilityIdentifier("model-connection-management-page")
    }
}

struct ModelConnectionSetupCard: View {
    @ObservedObject var setup: ModelConnectionSetupController
    var cancelTitle = "稍后"
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
                    HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("连接一个模型服务")
                        .font(.headline)
                    Text("你可以随时更换当前连接，原来的对话和草稿不会丢失。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(cancelTitle) { onCancel() }
                    .accessibilityIdentifier("model-connection-cancel")
            }

            if let errorMessage = setup.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("model-connection-error")
            }

            switch setup.step {
            case .idle:
                EmptyView()
            case .chooseProvider:
                providerChoices
            case .enterCredentials, .discovering:
                credentialEntry
            case .chooseModel:
                modelChoices
            case .nameConnection, .saving:
                naming
            case .completed:
                completed
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.2))
        }
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("model-connection-setup-card")
        .onChange(of: setup.errorMessage) { message in
            guard UIAccessibility.isVoiceOverRunning,
                  let message,
                  !message.isEmpty else {
                return
            }
            UIAccessibility.post(
                notification: .announcement,
                argument: message
            )
        }
    }

    private var providerChoices: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("先选你要使用的服务")
                .font(.subheadline.weight(.medium))
            ForEach(ProviderConnectorRegistry.officialConnectors, id: \.displayName) { connector in
                providerButton(connector)
            }
            providerButton(ProviderConnectorRegistry.customConnector)
        }
    }

    private func providerButton(_ connector: ProviderConnector) -> some View {
        let isAvailable = setup.canUseForGeneration(connector.provider)
        Button {
            setup.selectProvider(connector.provider)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(connector.displayName)
                    if !isAvailable {
                        Text("当前版本暂不支持真实任务")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: isAvailable ? "chevron.forward" : "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .disabled(!isAvailable)
        .accessibilityValue(isAvailable ? "可用" : "当前版本暂不支持真实任务")
        .accessibilityIdentifier("model-provider-\(connector.provider.rawValue)")
    }

    private var credentialEntry: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("服务：\(setup.providerDisplayName)")
                .font(.subheadline.weight(.medium))
            if setup.selectedProvider == .custom {
                TextField("OpenAI 兼容服务地址", text: $setup.customBaseURLInput)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .disabled(setup.step == .discovering)
                    .accessibilityIdentifier("model-connection-custom-base-url")
            } else {
                Text(setup.baseURLText)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("model-connection-base-url")
            }
            SecureField("API Key 只会保存到钥匙串", text: $setup.secretInput)
                .textInputAutocapitalization(.never)
                .disabled(setup.step == .discovering)
                .accessibilityIdentifier("model-connection-secret")
            Button(setup.step == .discovering ? "正在测试……" : "测试连接并找模型") {
                Task {
                    _ = try? await setup.discoverModels()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(setup.step == .discovering || setup.secretInput.isEmpty)
            .accessibilityIdentifier("model-connection-discover")
        }
    }

    private var modelChoices: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("请选择要使用的模型")
                .font(.subheadline.weight(.medium))
            if setup.availableModelIDs.isEmpty && setup.canEnterModelManually {
                Text("这个服务没有提供模型列表，请明确输入模型名。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("模型名称", text: $setup.connectionNameInput)
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("model-manual-model")
                Button("使用这个模型") {
                    setup.selectModel(setup.connectionNameInput)
                    setup.connectionNameInput = ""
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("model-manual-select")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(setup.availableModelIDs, id: \.self) { modelID in
                            Button {
                                setup.selectModel(modelID)
                            } label: {
                                HStack {
                                    Text(modelID)
                                    Spacer()
                                    Image(
                                        systemName: setup.selectedModelID == modelID
                                            ? "checkmark.circle.fill"
                                            : "circle"
                                    )
                                }
                            }
                            .buttonStyle(.bordered)
                            .accessibilityValue(
                                setup.selectedModelID == modelID ? "已选择" : "未选择"
                            )
                            .accessibilityIdentifier(
                                modelID == "gpt-fixture"
                                    ? "model-choice-gpt-fixture"
                                    : "model-choice-\(Self.safeIdentifier(modelID))"
                            )
                        }
                    }
                }
                .frame(maxHeight: 260)
                .accessibilityIdentifier("model-choice-scroll")
            }
        }
    }

    private var naming: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("给这个连接起个名字")
                .font(.subheadline.weight(.medium))
            if let selectedModelID = setup.selectedModelID {
                Text("已选择：\(selectedModelID)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            TextField("例如：我的 GPT", text: $setup.connectionNameInput)
                .accessibilityIdentifier("model-connection-name")
            Button(setup.step == .saving ? "正在保存……" : "保存并设为当前连接") {
                _ = try? setup.saveCurrentConnection()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!setup.canSaveCurrentConnection)
            .accessibilityIdentifier("model-connection-save-current")
        }
    }

    private var completed: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("连接已经保存并设为当前", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            if let label = setup.currentConnectionLabel {
                Text(label)
                    .accessibilityIdentifier("current-model-connection")
            }
            Text(ModelConnectionSetupConversationCopy.connectionReady)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("model-connection-resume-notice")
        }
    }

    private static func safeIdentifier(_ value: String) -> String {
        let scalars = value.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(String(scalar))
            }
            return "-"
        }
        return String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
