//
//  CharacterNavigatorView.swift
//  Cangjie
//
//  角色导航列表，对齐原版 components/workbench/CharacterNavigator.vue:1-124。
//  头像+名字+心理状态点+角色Tag+选中高亮。
//

import SwiftUI

/// 角色导航视图
///
/// 对齐原版 `components/workbench/CharacterNavigator.vue`。
struct CharacterNavigatorView: View {

    /// 小说 ID（对齐 :66 props.slug）
    let novelId: String

    /// 选中角色 ID（对齐 :67 props.selectedCharacterId）
    let selectedCharacterId: String?

    /// 选中角色回调（对齐 :71 emit select-character）
    var onSelectCharacter: ((String?) -> Void)? = nil

    // MARK: - 状态

    @StateObject private var bibleStore = BibleStore()
    @State private var loading = false

    // MARK: - 计算属性

    /// 角色列表（对齐 :75 characters）
    private var characters: [CharacterDTO] {
        return bibleStore.bible?.characters ?? []
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 对齐 :3-6 header
            header

            // 对齐 :8-48 角色列表
            if loading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if characters.isEmpty {
                // 对齐 :36-48 空状态
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.textTertiary)
                    Text("暂无角色")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(characters) { char in
                            characterRow(char)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .background(Theme.background)
        .task {
            await loadCharacters()
        }
        .onChange(of: novelId) { _ in
            Task { await loadCharacters() }
        }
    }

    // MARK: - Header（对齐 :3-6）

    private var header: some View {
        HStack(spacing: 6) {
            Text("角色导航")
                .font(.system(size: 13, weight: .bold))
            if !characters.isEmpty {
                Text("\(characters.count)")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Theme.tertiaryBackground)
                    .cornerRadius(8)
                    .foregroundColor(Theme.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.gray.opacity(0.2)), alignment: .bottom)
    }

    // MARK: - 角色行（对齐 :10-33）

    private func characterRow(_ char: CharacterDTO) -> some View {
        Button {
            onSelectCharacter?(char.id)
        } label: {
            HStack(spacing: 9) {
                // 对齐 :17-19 头像
                ZStack {
                    Circle()
                        .fill(roleColor(char.role ?? ""))
                    Text(String(char.name.prefix(1)))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 30, height: 30)

                // 对齐 :20-32 信息
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(char.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)

                        // 对齐 :24-27 心理状态点
                        if let dotClass = stateDotClass(char.mentalState) {
                            Circle()
                                .fill(dotColor(dotClass))
                                .frame(width: 6, height: 6)
                        }
                    }

                    // 对齐 :29-32 角色Tag
                    Text(roleLabel(char.role ?? ""))
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(roleBgColor(char.role ?? ""))
                        .cornerRadius(4)
                        .foregroundColor(roleFgColor(char.role ?? ""))
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                selectedCharacterId == char.id ? Theme.primary.opacity(0.05) : Theme.secondaryBackground
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedCharacterId == char.id ? Theme.primary : Color.gray.opacity(0.2),
                            lineWidth: selectedCharacterId == char.id ? 3 : 1),
                alignment: .leading
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 角色颜色（对齐 :77-79 getCharacterRoleColor）

    private func roleColor(_ role: String) -> Color {
        switch role {
        case "protagonist": return .blue
        case "supporting": return .orange
        case "minor": return .gray
        default: return .gray
        }
    }

    private func roleBgColor(_ role: String) -> Color {
        switch role {
        case "protagonist": return Color.blue.opacity(0.1)
        case "supporting": return Color.orange.opacity(0.1)
        default: return Theme.tertiaryBackground
        }
    }

    private func roleFgColor(_ role: String) -> Color {
        switch role {
        case "protagonist": return .blue
        case "supporting": return .orange
        default: return Theme.textTertiary
        }
    }

    // MARK: - 角色标签（对齐 :81-83 getCharacterRoleLabel）

    private func roleLabel(_ role: String) -> String {
        switch role {
        case "protagonist": return "主角"
        case "supporting": return "配角"
        case "minor": return "次要"
        default: return role
        }
    }

    // MARK: - 心理状态点（对齐 :86-91 classifyCharacterMentalState）

    private func stateDotClass(_ mental: String) -> String? {
        let lower = mental.lowercased()
        if lower.contains("愤怒") || lower.contains("恐惧") || lower.contains("崩溃") { return "danger" }
        if lower.contains("焦虑") || lower.contains("紧张") || lower.contains("不安") { return "warning" }
        return nil
    }

    private func dotColor(_ cls: String) -> Color {
        switch cls {
        case "danger": return Theme.error
        case "warning": return Theme.warning
        default: return Theme.textTertiary
        }
    }

    // MARK: - 加载角色（对齐 :105-117 loadCharacters）

    private func loadCharacters() async {
        guard !novelId.isEmpty else { return }
        loading = true
        await bibleStore.loadBible(novelId: novelId)
        loading = false
    }
}
