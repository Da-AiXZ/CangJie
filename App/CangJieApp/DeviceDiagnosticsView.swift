import SwiftUI

struct DeviceDiagnosticsView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        List {
            Section {
                Text("Device Diagnostics")
                    .font(.headline)
                    .accessibilityIdentifier("device-diagnostics-heading")
                Text("This secondary surface verifies the exact installed candidate and local security primitives. It does not replace the Agent control plane.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Candidate identity") {
                Text(model.buildIdentity.displayText)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .accessibilityIdentifier("diagnostics-build-identity")
            }

            Section("ThisDeviceOnly Keychain probe") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(model.hasStoredKey ? "Stored" : "Absent")
                        .foregroundStyle(model.hasStoredKey ? Color.green : Color.secondary)
                        .accessibilityIdentifier("keychain-probe-status")
                }

                if let digest = model.keychainProbeDigest {
                    HStack {
                        Text("Value digest")
                        Spacer()
                        Text(digest)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                            .accessibilityIdentifier("keychain-probe-digest")
                    }
                }

                SecureField("Disposable test value", text: $model.apiKeyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("keychain-probe-input")

                Button(model.hasStoredKey ? "Update and verify" : "Create and verify") {
                    model.saveProbeKey()
                }
                .disabled(model.apiKeyInput.isEmpty)
                .accessibilityIdentifier("keychain-probe-save")

                Button("Read and verify") {
                    model.readProbeKey()
                }
                .accessibilityIdentifier("keychain-probe-read")

                Button("Delete and verify", role: .destructive) {
                    model.deleteProbeKey()
                }
                .disabled(!model.hasStoredKey)
                .accessibilityIdentifier("keychain-probe-delete")

                Text("Use a disposable value, never a real API key. The screen exposes only a 12-character SHA-256 digest; plaintext is never displayed or logged.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Device Diagnostics")
    }
}
