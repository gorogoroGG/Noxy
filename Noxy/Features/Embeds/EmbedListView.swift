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
                        .transition(.opacity)
                } else if isLoading {
                    skeletonList
                        .transition(.opacity)
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
                            EmbedRow(
                                embed: embed,
                                onEdit: { editingEmbed = embed; showEditor = true },
                                onSend: { embedToSend = embed },
                                onDuplicate: { duplicateEmbed(embed) },
                                onDelete: {
                                    deleteTarget = embed
                                    showDeleteConfirm = true
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
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
                .transition(.scale.combined(with: .opacity))
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
            .id(editingEmbed?.id ?? "new-embed")
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
        .onChange(of: appState.selectedGuildId) { _, _ in
            isLoading = true
            Task { await load() }
        }
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
        // キャッシュから即座に表示（ちらつき防止）
        if let cached = appState.cachedEmbeds[appState.selectedGuildId] {
            embeds = cached
            isLoading = false
        }
        // バックグラウンドで最新データを取得
        do {
            let guildEmbeds = try await services.embeds.fetchByGuild(appState.selectedGuildId)
            embeds = guildEmbeds
            appState.cacheEmbeds(guildEmbeds, for: appState.selectedGuildId)
        } catch {
            print("[EmbedListView] fetch error: \(error)")
            if appState.cachedEmbeds[appState.selectedGuildId] == nil {
                embeds = []
            }
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

    // MARK: - Skeleton Loading

    private var skeletonList: some View {
        List {
            ForEach(0..<5) { _ in
                HStack(spacing: .spacing12) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.textTertiary.opacity(0.2))
                        .frame(width: 4, height: 36)

                    VStack(alignment: .leading, spacing: .spacing4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.textTertiary.opacity(0.15))
                            .frame(width: 120, height: 16)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.textTertiary.opacity(0.1))
                            .frame(width: 180, height: 12)
                    }

                    Spacer()
                }
                .padding(.spacing12)
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - EmbedRow (compact list row)

private struct EmbedRow: View {
    let embed: EmbedModel
    let onEdit: () -> Void
    let onSend: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    private var accentColor: Color {
        Color(uiColor: UIColor(hex: embed.colorHex))
    }

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: .spacing12) {
                // カラーインジケータ
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 4, height: 36)

                VStack(alignment: .leading, spacing: .spacing2) {
                    Text(embed.name.isEmpty ? "名前なし" : embed.name)
                        .font(.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    if let title = embed.title, !title.isEmpty {
                        Text(title)
                            .font(.captionRegular)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }

                    Text(relativeTimeString(from: embed.updatedAt))
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()

                Menu {
                    Button { onEdit() } label: {
                        Label("編集", systemImage: "pencil")
                    }
                    Button { onSend() } label: {
                        Label("送信", systemImage: "paperplane")
                    }
                    Button { onDuplicate() } label: {
                        Label("複製", systemImage: "doc.on.doc")
                    }
                    Divider()
                    Button(role: .destructive) { onDelete() } label: {
                        Label("削除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.bodyRegular)
                        .foregroundStyle(Color.textTertiary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
            .padding(.spacing12)
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        }
        .buttonStyle(.plain)
    }

    private func relativeTimeString(from date: Date) -> String {
        let diff = Date.now.timeIntervalSince(date)
        if diff < 60 { return "たった今" }
        if diff < 3600 { return "\(Int(diff / 60))分前" }
        if diff < 86400 { return "\(Int(diff / 3600))時間前" }
        return "\(Int(diff / 86400))日前"
    }
}

#Preview {
    NavigationStack {
        EmbedListView()
            .environment(\.services, ServiceContainer.live())
            .environment(AppState())
    }
}
