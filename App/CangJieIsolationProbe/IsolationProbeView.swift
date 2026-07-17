import SwiftUI

struct IsolationProbeView: View {
    @StateObject private var model: IsolationProbeViewModel

    init(model: @autoclosure @escaping () -> IsolationProbeViewModel = IsolationProbeViewModel()) {
        _model = StateObject(wrappedValue: model())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Keychain Isolation Companion Probe")
                        .font(.headline)
                        .accessibilityIdentifier("isolation-probe-heading")
                    Text("Install this exact paired Probe build separately from CangJie. It verifies only entitlement isolation for the paired candidate; it does not make a universal claim about every TrollStore app.")
                        .font(.footnote)
                    Text("The Probe never requests, reads, displays, or stores the CangJie canary value. It classifies OSStatus only.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("isolation-probe-privacy-notice")
                }

                Section("Candidate identity") {
                    Text(model.buildIdentity.executableText)
                        .font(.caption.monospaced())
                        .accessibilityIdentifier("isolation-probe-executable-identity")
                    Text(model.buildIdentity.installedText)
                        .font(.caption.monospaced())
                        .accessibilityIdentifier("isolation-probe-installed-identity")
                    LabeledContent("Candidate Set", value: model.buildIdentity.candidateSetText)
                        .accessibilityIdentifier("isolation-probe-candidate-set")
                    Label(
                        model.buildIdentity.isActive ? "Probe executable is active" : "Probe executable does not match installed bundle",
                        systemImage: model.buildIdentity.isActive ? "checkmark.shield.fill" : "xmark.shield.fill"
                    )
                    .foregroundColor(model.buildIdentity.isActive ? .green : .red)
                    .accessibilityIdentifier("isolation-probe-build-activation")
                    if !model.buildIdentity.isActive {
                        Text("Force-quit this Probe and reopen it. Do not run or accept isolation verification while the executable and installed bundle differ.")
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }

                Section("Verification") {
                    Button {
                        model.runVerification()
                    } label: {
                        Label("Run isolation verification", systemImage: "lock.shield")
                    }
                    .disabled(model.isRunning || !model.buildIdentity.isActive)
                    .accessibilityIdentifier("isolation-probe-run-button")

                    overallStatus
                        .accessibilityIdentifier("isolation-probe-overall-status")
                }

                if case let .completed(report) = model.state {
                    Section("Evidence") {
                        checkRow(
                            title: "Own-group control",
                            check: report.ownGroupControl,
                            identifier: "isolation-probe-own-group-status"
                        )
                        checkRow(
                            title: "Default-group lookup",
                            check: report.defaultGroupLookup,
                            identifier: "isolation-probe-default-group-status"
                        )
                        checkRow(
                            title: "Explicit CangJie group request",
                            check: report.forbiddenGroupLookup,
                            identifier: "isolation-probe-forbidden-group-status"
                        )
                    }

                    if report.overallDisposition != .pass {
                        Section("Fail-closed result") {
                            Text("Do not accept the candidate. A PASS requires the own-group control, default-group lookup, and explicit forbidden-group request to all pass exactly.")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Isolation Probe")
        }
    }

    @ViewBuilder
    private var overallStatus: some View {
        switch model.state {
        case .idle:
            Text("Not run")
                .foregroundColor(.secondary)
        case .running:
            Text("Running")
                .foregroundColor(.secondary)
        case let .completed(report):
            Text(overallText(report.overallDisposition))
                .font(.headline)
                .foregroundColor(color(report.overallDisposition))
        }
    }

    private func checkRow(
        title: String,
        check: KeychainIsolationCheck,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(dispositionText(check.disposition))
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(color(check.disposition))
                    .accessibilityIdentifier(identifier)
            }
            Text("OSStatus: \(check.status)")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
            Text(check.detail)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private func overallText(_ disposition: IsolationCheckDisposition) -> String {
        switch disposition {
        case .pass: return "PASS - entitlement isolation verified"
        case .criticalFail: return "CRITICAL FAIL - candidate rejected"
        case .inconclusive: return "INCONCLUSIVE - candidate rejected"
        }
    }

    private func dispositionText(_ disposition: IsolationCheckDisposition) -> String {
        switch disposition {
        case .pass: return "PASS"
        case .criticalFail: return "CRITICAL FAIL"
        case .inconclusive: return "INCONCLUSIVE"
        }
    }

    private func color(_ disposition: IsolationCheckDisposition) -> Color {
        switch disposition {
        case .pass: return .green
        case .criticalFail: return .red
        case .inconclusive: return .orange
        }
    }
}
