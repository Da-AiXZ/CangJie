import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        HStack(spacing: 0) {
            leftRail
                .frame(width: 250)
            Divider()
            conversation
                .frame(maxWidth: .infinity)
            if model.isArtifactDrawerPresented {
                Divider()
                artifacts
                    .frame(width: 320)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var leftRail: some View {
        NavigationStack {
            List {
                Section("Navigate") {
                    NavigationLink("Conversations", destination: Text("Conversation history"))
                    NavigationLink("Novel Projects", destination: projectPage)
                    NavigationLink("Workbenches", destination: Text("Novel workbenches"))
                    NavigationLink("Research", destination: Text("Research center"))
                }
                Section {
                    Button { model.isArtifactDrawerPresented.toggle() } label: {
                        Label(model.isArtifactDrawerPresented ? "Hide artifacts" : "Show artifacts", systemImage: "square.stack.3d.up")
                    }
                }
            }
            .navigationTitle("CangJie")
        }
    }

    private var projectPage: some View {
        List {
            ForEach(model.projects) { project in
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title).font(.headline)
                    Text(project.premise).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                .padding(.vertical, 4)
            }
            Button { model.reloadProjects() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
        }
        .navigationTitle("Novel Projects")
    }

    private var conversation: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Agent Control Plane").font(.title2.bold())
                    Text(model.status).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.isArtifactDrawerPresented.toggle() } label: { Image(systemName: "sidebar.right") }
            }
            .padding()
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if model.conversationMessages.isEmpty {
                        VStack(spacing: 10) { Image(systemName: "sparkles").font(.largeTitle); Text("Start with an idea").font(.headline); Text("Ask CangJie to create or develop a novel. The Agent will operate the project tools for you.").font(.footnote).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(.vertical, 80)
                    }
                    ForEach(Array(model.conversationMessages.enumerated()), id: \.offset) { _, message in
                        Text(message).frame(maxWidth: .infinity, alignment: .leading).padding(12).background(.background, in: RoundedRectangle(cornerRadius: 12))
                    }
                }.padding()
            }
            if model.planAwaitingApproval {
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text("Opening plan awaiting approval").font(.headline); Spacer(); Button("Approve") { model.approveOpeningPlan() }.buttonStyle(.borderedProminent) }
                    Text(model.planBody).font(.footnote).lineLimit(6)
                }.padding().background(.background, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
            }
            HStack(alignment: .bottom) {
                TextEditor(text: $model.draft).frame(minHeight: 70, maxHeight: 130).padding(6).background(.background, in: RoundedRectangle(cornerRadius: 12))
                Button { model.sendAgentMessage() } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 32)) }.disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding()
        }
    }

    private var artifacts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conversation artifacts").font(.headline)
            Text("Projects: \(model.projects.count)")
            if let receipt = model.lastToolReceipt {
                Text("Last tool: \(receipt.toolID)").font(.footnote)
                Text("Outcome: \(receipt.outcome)").font(.footnote).foregroundStyle(.secondary)
            }
            Divider()
            Text("Tool receipts, plans, diffs, approvals, and chapter versions will appear here.").font(.footnote).foregroundStyle(.secondary)
            Spacer()
        }.padding()
    }
}
