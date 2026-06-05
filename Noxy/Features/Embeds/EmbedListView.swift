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
                if !appState.isPro {
                    freeUserView
                } else if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty && searchText.isEmpty {
                    EmptyStateView(
                        icon: "rectangle.stack.badge.plus",
                        title: "Embedがありません",
                        description: "右下の＋から最初のEmbedを作成しましょう",
                        actionTitle: "作成する"
                    ) {
                        editingEmbed = nil
                        showEditor = true
                    }
                } else if filtered.isEmpty {
                    VStack(spacing: .spacing8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.textTertiary)
                        Text("「\(searchText)」に一致するEmbedがありません")
                            .font(.bodySmall)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered) { embed in
                            EmbedCard(
                                embed: embed,
                                onSend: { embedToSend = embed },
                                onEdit: { editingEmbed = embed; showEditor = true },
                                onDuplicate: { duplicateEmbed(embed) }
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteTarget = embed
                                    showDeleteConfirm = true
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                        // FAB 分の余白
                        Color.clear
                            .frame(height: 80)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.bgPrimary)

            if appState.isPro && !isLoading && !filtered.isEmpty {
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
        .navigationTitle("Embed")
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

    // MARK: - Free User View

    private var freeUserView: some View {
        ScrollView {
            VStack(spacing: .spacing20) {
                HStack(alignment: .top, spacing: .spacing12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.accentIndigo)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: .spacing4) {
                        Text("送信専用モード")
                            .font(.titleMedium)
                            .foregroundStyle(Color.textPrimary)
                        Text("無料プランではEmbedの保存ができません。作成したEmbedは直接送信できます。")
                            .font(.bodySmall)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .padding(.spacing16)
                .background(Color.accentIndigo.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))

                Button {
                    editingEmbed = nil
                    showEditor = true
                } label: {
                    HStack(spacing: .spacing8) {
                        Image(systemName: "paperplane.fill")
                        Text("新しいEmbedを作成・送信")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.accentIndigo)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                }
                .buttonStyle(ScalePressButtonStyle())

                NavigationLink(destination: SubscriptionView()) {
                    Text("保存するにはProへアップグレード")
                        .font(.captionRegular)
                        .foregroundStyle(Color.accentOrange)
                        .underline()
                }
            }
            .padding()
        }
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

    private var accentColor: Color {
        Color(uiColor: UIColor(hex: embed.colorHex))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ヘッダー: カラーバー + 名前 + メニュー
            HStack(spacing: .spacing10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 4, height: 20)

                Text(embed.name.isEmpty ? "名前なし" : embed.name)
                    .font(.titleMedium)
                    .foregroundStyle(embed.name.isEmpty ? Color.textTertiary : Color.textPrimary)
                    .lineLimit(1)

                Spacer()

                Menu {
                    Button { onEdit() } label: {
                        Label("編集", systemImage: "pencil")
                    }
                    Button { onDuplicate() } label: {
                        Label("複製", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.horizontal, .spacing12)
            .padding(.top, .spacing12)
            .padding(.bottom, .spacing8)

            // プレビュー
            if embed.title != nil || embed.description != nil || !embed.fields.isEmpty {
                EmbedPreviewCard(embed: .from(embed))
                    .padding(.horizontal, .spacing12)
                    .padding(.bottom, .spacing12)
            }

            // 送信ボタン
            Button(action: onSend) {
                HStack(spacing: .spacing6) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 13))
                    Text("このEmbedを送信")
                        .font(.bodySmall)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(accentColor)
                .clipShape(
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: .cornerRadiusMedium,
                        bottomTrailingRadius: .cornerRadiusMedium
                    )
                )
            }
            .buttonStyle(.plain)
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }
}

#Preview {
    NavigationStack {
        EmbedListView()
            .environment(\.services, ServiceContainer.live())
            .environment(AppState())
    }
}
