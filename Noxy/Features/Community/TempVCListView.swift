import SwiftUI

struct TempVCListView: View {
    let guildId: String

    @Environment(\.services)    private var services
    @Environment(AppState.self) private var appState
    @State private var sources: [TempVCSource] = []
    @State private var isLoading = true
    @State private var isEditing = false
    @State private var editingSource: TempVCSource? = nil
    @State private var categories: [(id: String, name: String)] = []

    // MARK: - Toast
    @State private var toastMessage: String? = nil
    @State private var toastIsError: Bool = false

    // MARK: - Confirm
    @State private var confirmDeleteSource: TempVCSource? = nil

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.lg) {
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .padding(.vertical, Theme.Spacing.xl)
                } else {
                    if sources.isEmpty {
                        emptyState
                    } else {
                        sourceList
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
        }
        .background(Theme.Color.bg)
        .navigationTitle("一時チャンネル")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                let atFreeLimit = !appState.isPro && sources.count >= 1
                Button {
                    editingSource = TempVCSource.defaultSource(guildId: guildId)
                    isEditing = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                        .foregroundStyle(atFreeLimit ? Theme.Color.textTertiary : Theme.Color.accent)
                }
                .disabled(atFreeLimit)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !appState.isPro && !sources.isEmpty {
                proBanner
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                TempVCSourceEditView(
                    guildId: guildId,
                    source: editingSource ?? TempVCSource.defaultSource(guildId: guildId),
                    categories: categories,
                    onSave: { source in
                        Task { await saveSource(source) }
                    }
                )
            }
        }
        .overlay {
            toastOverlay
        }
        .overlay {
            confirmOverlay
        }
        .task { await loadAll() }
        .onChange(of: guildId) { _, _ in
            isLoading = true
            Task { await loadAll() }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(Theme.Color.textTertiary)
            Text("一時チャンネルが登録されていません")
                .font(Theme.Font.bodyMedium)
                .foregroundStyle(Theme.Color.textPrimary)
            Text("＋ボタンをタップしてトリガーVCを登録")
                .font(Theme.Font.caption2)
                .foregroundStyle(Theme.Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Theme.Color.line, lineWidth: 1)
        )
    }

    // MARK: - Source List

    private var sourceList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionLabel(title: "トリガーVC (\(sources.count)件)")

            VStack(spacing: 0) {
                ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                    sourceRow(source)
                    if index < sources.count - 1 {
                        Divider()
                            .padding(.leading, Theme.Spacing.md + 7 + Theme.Spacing.md)
                            .foregroundStyle(Theme.Color.line)
                    }
                }
            }
            .background(Theme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Theme.Color.line, lineWidth: 1)
            )
        }
    }

    // MARK: - Source Row

    private func sourceRow(_ source: TempVCSource) -> some View {
        Button {
            editingSource = source
            isEditing = true
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                StatusDot(color: source.triggerVcId != nil ? Theme.Color.statusOK : Theme.Color.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(source.triggerVcName)
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(Theme.Color.textPrimary)

                    HStack(spacing: Theme.Spacing.sm) {
                        Text("VC: \(categoryName(for: source.vcCategoryId))")
                        if !source.textChannelCategoryId.isEmpty {
                            Text("・")
                            Text("Text: \(categoryName(for: source.textChannelCategoryId))")
                        }
                        if source.userLimit > 0 {
                            Text("・")
                            Text("\(source.userLimit)人")
                                .monospaced()
                        }
                    }
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
                }

                Spacer()

                HStack(spacing: Theme.Spacing.xs) {
                    if source.waitingRoomEnabled {
                        Text("待機室")
                            .font(Theme.Font.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.Color.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Color.accentDim)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
                    }
                    if source.triggerVcId == nil {
                        Text("未作成")
                            .font(Theme.Font.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.Color.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Color.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
                    }
                    Image(systemName: "chevron.right")
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
            }
            .padding(.vertical, Theme.Spacing.sm)
            .padding(.horizontal, Theme.Spacing.md)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                confirmDeleteSource = source
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    // MARK: - Pro Banner

    private var proBanner: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "lock.fill")
                .font(Theme.Font.caption2)
                .foregroundStyle(Theme.Color.textTertiary)
            Text("無料プランはソース1つまで。Proで追加できます。")
                .font(Theme.Font.caption2)
                .foregroundStyle(Theme.Color.textTertiary)
            Spacer()
            NavigationLink(destination: SubscriptionView()) {
                Text("アップグレード")
                    .font(Theme.Font.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Color.accent)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Color.surface)
        .overlay(
            Rectangle()
                .stroke(Theme.Color.line, lineWidth: 1)
        )
    }

    // MARK: - Toast Overlay

    private var toastOverlay: some View {
        VStack {
            Spacer()
            if let toastMessage {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: toastIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(toastIsError ? Theme.Color.statusBad : Theme.Color.statusOK)
                    Text(toastMessage)
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Color.textPrimary)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Color.surfaceRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.button)
                        .stroke(Theme.Color.line, lineWidth: 1)
                )
                .padding(.bottom, Theme.Spacing.xl)
                .padding(.horizontal, Theme.Spacing.md)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Confirm Overlay

    private var confirmOverlay: some View {
        Group {
            if let source = confirmDeleteSource {
                ConfirmModal(
                    icon: "trash.fill",
                    iconColor: Theme.Color.statusBad,
                    title: "ソースを削除しますか？",
                    message: "「\(source.triggerVcName)」を削除すると、関連する一時チャンネルも停止します。",
                    primaryLabel: "削除する",
                    primaryRole: .destructive,
                    onPrimary: {
                        confirmDeleteSource = nil
                        Task { await deleteSource(source) }
                    },
                    onCancel: {
                        confirmDeleteSource = nil
                    }
                )
            }
        }
    }

    // MARK: - Helpers

    private func categoryName(for id: String) -> String {
        categories.first(where: { $0.id == id })?.name ?? id
    }

    // MARK: - Actions

    private func loadAll(silent: Bool = false) async {
        if !silent { isLoading = true }

        let fetched = (try? await services.tempVCSource.fetchSources(guildId: guildId)) ?? []
        if !silent || !fetched.isEmpty {
            sources = fetched
        }

        struct RawCh: Decodable { let id: String; let name: String; let type: Int }
        if let chs = try? await WorkerClient().get("/bot/channels?guild_id=\(guildId)") as [RawCh] {
            categories = chs.filter { $0.type == 4 }.map { ($0.id, $0.name) }
        }

        if !silent { isLoading = false }
    }

    private func saveSource(_ source: TempVCSource) async {
        do {
            var saved: TempVCSource
            if source.id != nil {
                saved = try await services.tempVCSource.updateSource(source)
                if let triggerVcId = saved.triggerVcId {
                    try await services.tempVCSource.showTriggerVc(
                        id: saved.effectiveId,
                        guildId: guildId,
                        triggerVcId: triggerVcId
                    )
                }
                withAnimation {
                    if let idx = sources.firstIndex(where: { $0.id == saved.id }) {
                        sources[idx] = saved
                    }
                }
                showToast("保存しました")
            } else {
                saved = try await services.tempVCSource.createSource(source)
                if saved.triggerVcId == nil {
                    saved = try await services.tempVCSource.createTriggerVc(
                        id: saved.effectiveId,
                        guildId: guildId,
                        triggerVcName: saved.triggerVcName,
                        vcCategoryId: saved.vcCategoryId
                    )
                    showToast("作成し、トリガーVCも作成しました")
                } else {
                    showToast("作成しました")
                }
                withAnimation { sources.insert(saved, at: 0) }
            }
            withAnimation { isEditing = false }
        } catch {
            showToast("保存に失敗しました", isError: true)
        }
    }

    private func deleteSource(_ source: TempVCSource) async {
        withAnimation { sources.removeAll { $0.id == source.id } }
        showToast("削除しました")
        do {
            try await services.tempVCSource.deleteSource(id: source.effectiveId)
        } catch {
            withAnimation { sources.append(source) }
            showToast("削除に失敗しました", isError: true)
        }
    }

    private func showToast(_ message: String, isError: Bool = false) {
        withAnimation {
            toastMessage = message
            toastIsError = isError
        }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation {
                toastMessage = nil
            }
        }
    }
}

#Preview {
    NavigationStack {
        TempVCListView(guildId: "g001")
    }
    .environment(\.services, ServiceContainer.mock())
    .environment(AppState())
}
