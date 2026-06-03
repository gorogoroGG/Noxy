import SwiftUI

struct EmbedListView: View {
    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState
    @State private var embeds: [EmbedModel] = []
    @State private var isLoading = true
    @State private var showEditor = false
    @State private var editingEmbed: EmbedModel? = nil
    @State private var embedToSend: EmbedModel? = nil
    @State private var deleteTarget: EmbedModel? = nil
    @State private var showDeleteConfirm = false
    @State private var toast: ToastMessage? = nil
    @State private var searchText = ""
    @State private var lastDeletedEmbed: EmbedModel? = nil

    private var filtered: [EmbedModel] {
        guard !searchText.isEmpty else { return embeds }
        return embeds.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.title ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty {
                    EmptyStateView(
                        icon: "rectangle.stack.badge.plus",
                        title: "Embedがありません",
                        description: "右下の＋から最初のEmbedを作成しましょう",
                        actionTitle: "作成する"
                    ) {
                        editingEmbed = nil
                        showEditor = true
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: .spacing12) {
                            ForEach(filtered) { embed in
                                EmbedCard(embed: embed) {
                                    embedToSend = embed
                                } onEdit: {
                                    editingEmbed = embed
                                    showEditor = true
                                } onDuplicate: {
                                    duplicateEmbed(embed)
                                } onDelete: {
                                    deleteTarget = embed
                                    showDeleteConfirm = true
                                }
                            }
                        }
                        .padding()
                        .padding(.bottom, 80)  // FAB分の余白
                    }
                }
            }
            .background(Color.bgPrimary)

            // FAB（リストが空のときはEmptyStateViewのボタンがあるので非表示）
            if !isLoading && !filtered.isEmpty {
                Button {
                    editingEmbed = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.accentIndigo)
                        .clipShape(Circle())
                        .shadow(color: Color.accentIndigo.opacity(0.4), radius: 12, x: 0, y: 4)
                }
                .padding(.trailing, .spacing20)
                .padding(.bottom, .spacing24)
            }
        }
        .navigationTitle("埋め込みメッセージ")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Embedを検索")
        .sheet(isPresented: $showEditor, onDismiss: { Task { await load() } }) {
            EmbedEditorView(embed: editingEmbed) { saved in
                if let idx = embeds.firstIndex(where: { $0.id == saved.id }) {
                    embeds[idx] = saved
                } else {
                    embeds.insert(saved, at: 0)
                }
            }
        }
        .sheet(item: $embedToSend) { embed in
            SendEmbedView(embed: embed)
        }
        .alert(
            "「\(deleteTarget?.name ?? "")」を削除しますか？",
            isPresented: $showDeleteConfirm
        ) {
            Button("削除", role: .destructive) {
                if let target = deleteTarget { deleteEmbed(target) }
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("この操作は取り消せません。")
        }
        .toast($toast)
        .task { await load() }
        .onChange(of: appState.selectedGuildId) { Task { await load() } }
    }

    // MARK: - Actions

    private func load() async {
        guard !appState.selectedGuildId.isEmpty else {
            embeds = []
            isLoading = false
            return
        }
        do {
            let all = try await services.embeds.fetchAll()
            embeds = all.filter { $0.guildId == appState.selectedGuildId || $0.guildId == nil }
        } catch {
            embeds = []
        }
        isLoading = false
    }

    private func duplicateEmbed(_ embed: EmbedModel) {
        Task {
            var copy = embed
            copy.id = UUID().uuidString
            copy.name = embed.name + " のコピー"
            copy.createdAt = .now
            copy.updatedAt = .now
            do {
                let saved = try await services.embeds.create(copy)
                embeds.insert(saved, at: 0)
                toast = ToastMessage(type: .success, message: "複製しました")
            } catch {
                toast = ToastMessage(type: .error, message: "複製に失敗しました")
            }
        }
    }

    private func deleteEmbed(_ embed: EmbedModel) {
        Task {
            do {
                try await services.embeds.delete(id: embed.id)
            } catch {
                toast = ToastMessage(type: .error, message: "削除に失敗しました")
                return
            }
            embeds.removeAll { $0.id == embed.id }
            lastDeletedEmbed = embed
            let currentServices = services
            toast = ToastMessage(
                type: .info,
                message: "削除しました",
                actionTitle: "元に戻す",
                action: {
                    Task { @MainActor in
                        if let embed = self.lastDeletedEmbed,
                           let saved = try? await currentServices.embeds.create(embed) {
                            self.embeds.insert(saved, at: 0)
                            self.lastDeletedEmbed = nil
                        }
                    }
                }
            )
        }
    }
}

// MARK: - EmbedCard

private struct EmbedCard: View {
    let embed: EmbedModel
    let onSend: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    private var accentColor: Color {
        Color(uiColor: UIColor(hex: embed.colorHex))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // カラーバー + メタ情報
            HStack(spacing: .spacing12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 4, height: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(embed.name)
                        .font(.titleMedium)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, .spacing12)
            .padding(.vertical, .spacing12)

            // Embed プレビュー（コンパクト）
            if embed.title != nil || embed.description != nil || !embed.fields.isEmpty {
                EmbedPreviewCard(embed: .from(embed))
                    .padding(.horizontal, .spacing12)
                    .padding(.bottom, .spacing12)
            }

            Divider().background(Color.border)

            // アクションボタン（送信・編集・複製・削除）
            HStack(spacing: 0) {
                ForEach([
                    ("paperplane.fill", "送信", Color.accentIndigo, onSend),
                    ("pencil", "編集", Color.textSecondary, onEdit),
                    ("doc.on.doc", "複製", Color.textSecondary, onDuplicate),
                    ("trash", "削除", Color.accentPink, onDelete),
                ] as [(String, String, Color, () -> Void)], id: \.1) { icon, label, color, action in
                    Button(action: action) {
                        VStack(spacing: 3) {
                            Image(systemName: icon)
                                .font(.system(size: 14))
                                .foregroundStyle(color)
                            Text(label)
                                .font(.captionSmall)
                                .foregroundStyle(color)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, .spacing8)
                    }
                    .buttonStyle(.plain)
                    if label != "削除" {
                        Divider().frame(height: 24)
                    }
                }
            }
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }
}

#Preview {
    NavigationStack {
        EmbedListView()
            .environment(\.services, ServiceContainer.live())
    }
}
