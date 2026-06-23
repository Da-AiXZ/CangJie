//
//  VoiceVaultPanel.swift
//  Cangjie
//
//  文风金库（文风样本库+当前角色声线参考+漂移预警），调 BibleStore/MonitorStore。
//

import SwiftUI

struct VoiceVaultPanel: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var bibleStore = BibleStore()
    @StateObject private var monitorStore = MonitorStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // 文风公约
                if let bible = bibleStore.bible, !bible.style.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("文风公约", systemImage: "textformat").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.primary)
                        Text(bible.style).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                    }
                }

                // 角色声线
                if let bible = bibleStore.bible {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("角色声线", systemImage: "waveform").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.primary)
                        ForEach(bible.characters) { ch in
                            if !ch.verbalTic.isEmpty || !ch.idleBehavior.isEmpty {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(ch.name).font(.system(size: 11, weight: .medium))
                                    if !ch.verbalTic.isEmpty { Text("声线：\(ch.verbalTic)").font(.system(size: 9)).foregroundColor(Theme.textTertiary) }
                                    if !ch.idleBehavior.isEmpty { Text("空闲：\(ch.idleBehavior)").font(.system(size: 9)).foregroundColor(Theme.textTertiary) }
                                }
                            }
                        }
                    }
                }

                // 漂移预警
                if !monitorStore.voiceDrifts.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("漂移预警", systemImage: "exclamationmark.triangle.fill").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.warning)
                        ForEach(monitorStore.voiceDrifts) { drift in
                            HStack {
                                Circle().fill(drift.status == "normal" ? Theme.success : drift.status == "warning" ? Theme.warning : Theme.error).frame(width: 6, height: 6)
                                Text(drift.characterName).font(.system(size: 11))
                                Spacer()
                                Text(String(format: "%.2f", drift.driftScore)).font(.system(size: 10, design: .monospaced)).foregroundColor(Theme.textTertiary)
                            }
                        }
                    }
                }
            }
            .padding(Theme.Spacing.sm)
        }
        .background(Theme.background)
        .task {
            if let novelId = appState.currentNovelId {
                await bibleStore.loadBible(novelId: novelId)
                await monitorStore.loadVoiceDrift(novelId: novelId)
            }
        }
    }
}
