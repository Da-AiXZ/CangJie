import SwiftUI

struct DeviceDiagnosticsView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        List {
            Section {
                Text("Device Diagnostics")
                    .font(.headline)
                    .accessibilityIdentifier("device-diagnostics-heading")
                Text("This secondary surface verifies the exact running candidate and local security primitives. It does not replace the Agent control plane.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Runtime activation") {
                diagnosticRow("Running executable", model.buildIdentity.displayText, "diagnostics-build-identity")
                diagnosticRow("Installed bundle", model.buildIdentity.bundleDisplayText, "diagnostics-bundle-identity")
                diagnosticRow("Candidate Set", model.buildIdentity.candidateSetDisplayText, "diagnostics-candidate-set")
                Label(
                    model.isAgentExecutionAllowed ? "Runtime and installed bundle match" : "Agent execution blocked",
                    systemImage: model.isAgentExecutionAllowed ? "checkmark.shield.fill" : "xmark.shield.fill"
                )
                .foregroundStyle(model.isAgentExecutionAllowed ? Color.green : Color.red)
                .accessibilityIdentifier("diagnostics-build-activation-status")
                Text(model.buildActivationMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("diagnostics-build-activation-message")
            }

            Section("Cross-App Keychain Isolation") {
                HStack {
                    Text("Canary status")
                    Spacer()
                    Text(model.isolationCanaryPresent ? "Prepared" : "Absent")
                        .foregroundStyle(model.isolationCanaryPresent ? Color.green : Color.secondary)
                        .accessibilityIdentifier("isolation-canary-status")
                }
                if let digest = model.isolationCanaryDigest {
                    HStack {
                        Text("Canary digest")
                        Spacer()
                        Text(digest)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                            .accessibilityIdentifier("isolation-canary-digest")
                    }
                }
                Text("Prepare a random ThisDeviceOnly canary, run the paired CangJie Isolation Probe app, then return here and verify the digest is unchanged. The plaintext canary is never displayed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button(model.isolationCanaryPresent ? "Canary already prepared" : "Prepare isolation canary") {
                    model.prepareIsolationCanary()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isolationCanaryPresent)
                .accessibilityIdentifier("isolation-canary-prepare")

                Button("Verify canary is unchanged") {
                    model.verifyIsolationCanary()
                }
                .buttonStyle(.bordered)
                .disabled(!model.isolationCanaryPresent)
                .accessibilityIdentifier("isolation-canary-verify")

                Button("Delete isolation canary", role: .destructive) {
                    model.deleteIsolationCanary()
                }
                .buttonStyle(.bordered)
                .disabled(!model.isolationCanaryPresent)
                .accessibilityIdentifier("isolation-canary-delete")
            }

            Section("ThisDeviceOnly Keychain probe") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(model.hasStoredKey ? "Stored" : "Absent")
                        .foregroundStyle(model.hasStoredKey ? Color.green : Color.secondary)
                        .accessibilityIdentifier("keychain-probe-status")
                }

                Text(keychainGuidance)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("keychain-probe-guidance")

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

                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Disposable value input")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("keychain-probe-input-heading")

                    SecureField("Type disposable value here", text: $model.apiKeyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("keychain-probe-input")
                        .accessibilityHint("Enter a disposable test value. Plaintext is never displayed or logged.")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("2. Create or update and verify")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("keychain-probe-action-heading")

                    Text("The blue action button below uses the value entered in the secure field above.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("keychain-probe-action-help")

                    Button {
                        model.saveProbeKey()
                    } label: {
                        Label(
                            model.hasStoredKey ? "Update and verify" : "Create and verify",
                            systemImage: model.hasStoredKey ? "arrow.triangle.2.circlepath" : "plus.circle"
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.apiKeyInput.isEmpty)
                    .accessibilityIdentifier("keychain-probe-save")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("3. Re-read or remove the stored value")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("keychain-probe-secondary-heading")

                    Button("Read and verify") { model.readProbeKey() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("keychain-probe-read")

                    Button("Delete and verify", role: .destructive) { model.deleteProbeKey() }
                        .buttonStyle(.bordered)
                        .disabled(!model.hasStoredKey)
                        .accessibilityIdentifier("keychain-probe-delete")
                }

                Text("Use a disposable value, never a real API key. The screen exposes only a 12-character SHA-256 digest; plaintext is never displayed or logged.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Device Diagnostics")
        .scrollDismissesKeyboard(.interactively)
    }

    private func diagnosticRow(_ title: String, _ value: String, _ identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .accessibilityIdentifier(identifier)
        }
    }

    private var keychainGuidance: String {
        if model.hasStoredKey {
            return "A test value already exists. Enter a different value in the secure field below, then tap Update and verify."
        }
        return "No test value exists. Enter a disposable value in the secure field below, then tap Create and verify."
    }
}
