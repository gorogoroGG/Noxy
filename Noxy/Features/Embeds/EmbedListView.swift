import SwiftUI

// MARK: - EmbedListView
// Noxy Design Language に厳密に従った再設計。
// コンポーネント棚卸しに基づき、Dev Components を優先使用し、存在しない場合のみカスタム実装。

struct EmbedListView: View {
    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState

    @State private var embeds: [EmbedModel] = []
    @State private var isLoading = true
    @State private var editSession: EditSession? = nil
    @State private var embedToSend: EmbedModel? = nil
    @State private var deleteTarget: EmbedModel? = nil
    @State private var showDeleteConfirm = false
    @State private var toast: ToastMessage? = nil
    @State private var searchText = ""
    @State private var lastDeletedEmbed: EmbedModel? = nil

    private struct EditSession: Identifiable {
        let id = UUID()
        let embed: EmbedModel?
    }

    private var filtered: [EmbedModel] {
        guard !searchText.isEmpty else { return embeds }
        return embeds.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.title ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Theme.Color.bg.ignoresSafeArea()

            Group {
                if !appState.isPro {
                    freeUserView
                } else if isLoading {
                    skeletonContent
                } else if filtered.isEmpty && searchText.isEmpty {
                    EmptyStateView(
                        icon: "rectangle.stack.badge.plus",
                        title: "Embedがありません",
                        description: "右下の＋から最初のEmbedを作成しましょう",
                        actionTitle: "作成する"
                    ) {
                        editSession = EditSession(embed: nil)
                    }
                } else if filtered.isEmpty {
                    searchEmptyView
                } else {
                    embedListContent
                }
            }

            // FAB: 新規作成
            if appState.isPro && !isLoading && !filtered.isEmpty {
                fabButton
            }
        }
        .navigationTitle("Embedメッセージ")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Embedを検索")
        .sheet(item: $editSession, onDismiss: { Task { await load() } }) { session in
            EmbedEditorView(embed: session.embed) { saved in
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
        .overlay {
            if showDeleteConfirm, let target = deleteTarget {
                ConfirmModal(
                    icon: "trash.fill",
                    iconColor: Theme.Color.statusBad,
                    title: "「\(target.name)」を削除しますか？",
                    message: "この操作は取り消せません。",
                    primaryLabel: "削除",
                    primaryRole: .destructive,
                    onPrimary: {
                        deleteEmbed(target)
                        showDeleteConfirm = false
                        deleteTarget = nil
                    },
                    onCancel: {
                        showDeleteConfirm = false
                        deleteTarget = nil
                    }
                )
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .toast($toast)
        .task { await load() }
        .onChange(of: appState.selectedGuildId) { _, _ in
            isLoading = true
            Task { await load() }
        }
    }

    // MARK: - List Content

    private var embedListContent: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.xs) {
                SectionHeader(title: "保存されたテンプレート", actionTitle: "\(filtered.count)件") {}
                    .padding(.horizontal, Theme.Spacing.md)

                ForEach(filtered) { embed in
                    EmbedRowNoxy(
                        embed: embed,
                        onEdit: { editSession = EditSession(embed: embed) },
                        onSend: { embedToSend = embed },
                        onDuplicate: { duplicateEmbed(embed) },
                        onDelete: {
                            deleteTarget = embed
                            showDeleteConfirm = true
                        }
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                }

                // FAB 分の余白
                Color.clear
                    .frame(height: 80)
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    // MARK: - FAB
    // Noxy Design Language §7: 56px 円形、acc / acc-ink、シャドウ 0 4px 16px rgba(214,179,106,.3)

    private var fabButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            editSession = EditSession(embed: nil)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.Color.accentInk)
                .frame(width: 56, height: 56)
                .background(Theme.Color.accent)
                .clipShape(Circle())
                .shadow(
                    color: Theme.Color.accent.opacity(0.3),
                    radius: 16,
                    x: 0,
                    y: 4
                )
        }
        .padding(.trailing, Theme.Spacing.md)
        .padding(.bottom, 20)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Free User View

    private var freeUserView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Card(padding: Theme.Spacing.md, background: Theme.Color.accentDim, showBorder: false) {
                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.Color.accent)

                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("送信専用モード")
                                .font(Theme.Font.bodyMedium)
                                .foregroundStyle(Theme.Color.textPrimary)
                            Text("無料プランではEmbedの保存ができません。作成したEmbedは直接送信できます。")
                                .font(Theme.Font.caption2)
                                .foregroundStyle(Theme.Color.textSecondary)
                                .lineLimit(3)
                        }
                    }
                }

                AccentButton(title: "新しいEmbedを作成・送信") {
                    editSession = EditSession(embed: nil)
                }

                GhostButton(title: "保存するにはProへアップグレード") {
                    // SubscriptionView への遷移は親のナビゲーションに委譲
                }
            }
            .padding(Theme.Spacing.md)
        }
    }

    // MARK: - Search Empty

    private var searchEmptyView: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Theme.Color.textTertiary)
            Text("「\(searchText)」に一致するEmbedがありません")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Skeleton

    private var skeletonContent: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xs) {
                SectionHeader(title: "保存されたテンプレート") {}
                    .padding(.horizontal, Theme.Spacing.md)

                ForEach(0..<5, id: \.self) { _ in
                    SkeletonCard()
                        .padding(.horizontal, Theme.Spacing.md)
                }
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    // MARK: - Actions

    private func load() async {
        guard !appState.selectedGuildId.isEmpty else {
            embeds = []
            isLoading = false
            return
        }
        if let cached = appState.cachedEmbeds[appState.selectedGuildId] {
            embeds = cached
            isLoading = false
        }
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
}

// MARK: - EmbedRowNoxy
// Noxy Design Language §3.3 リストアイテム + §6 情報密度

private struct EmbedRowNoxy: View {
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
            HStack(spacing: Theme.Spacing.sm) {
                // カラーインジケータ (4px)
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 4, height: 36)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(embed.name.isEmpty ? "名前なし" : embed.name)
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .lineLimit(1)

                    if let title = embed.title, !title.isEmpty {
                        Text(title)
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.textSecondary)
                            .lineLimit(1)
                    }

                    // メタ情報: IBM Plex Mono で等幅表現
                    Text(relativeTimeString(from: embed.updatedAt))
                        .font(Theme.Font.monoCap)
                        .foregroundStyle(Theme.Color.textTertiary)
                }

                Spacer()

                // 右端メニュー
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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Color.textTertiary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
            .padding(EdgeInsets(top: 12, leading: 13, bottom: 12, trailing: 13))
            .background(Theme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(Theme.Color.line, lineWidth: 1)
            )
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

// MARK: - Preview

#Preview {
    NavigationStack {
        EmbedListView()
            .environment(\.services, ServiceContainer.live())
            .environment(AppState())
    }
}
