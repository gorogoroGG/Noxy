import SwiftUI

struct TempVCListView: View {
    let guildId: String

    @Environment(\.services) private var services
    @State private var sources: [TempVCSource] = []
    @State private var isLoading = true
    @State private var isEditing = false
    @State private var editingSource: TempVCSource? = nil
    @State private var toast: ToastMessage? = nil
    @State private var categories: [(id: String, name: String)] = []

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color(.systemGroupedBackground))
            } else {
                Section {
                    if sources.isEmpty {
                        VStack(spacing: .spacing12) {
                            Image(systemName: "mic.slash.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.textTertiary)
                            Text("一時チャンネルが登録されていません")
                                .font(.bodySmall)
                                .foregroundStyle(Color.textTertiary)
                            Text("＋ボタンをタップして、一時チャンネルを作成するためのトリガーVCを登録してください。")
                                .font(.captionSmall)
                                .foregroundStyle(Color.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, .spacing24)
                    } else {
                        ForEach(sources) { source in
                            sourceRow(source)
                        }
                    }
                } header: {
                    Text("一時チャンネル（\(sources.count)件）")
                }

                if !sources.isEmpty {
                    Section {
                        tipRow(icon: "arrow.right.circle.fill", color: .accentIndigo,
                               title: "参加で自動作成",
                               detail: "トリガーVCに参加すると、指定カテゴリに新しいVC＋テキストチャンネルが自動作成されます。")
                        tipRow(icon: "person.2.fill", color: .accentGreen,
                               title: "参加者に移動",
                               detail: "参加したユーザーは自動的に作成されたVCに移動されます。")
                        tipRow(icon: "trash.fill", color: .red,
                               title: "自動削除",
                               detail: "全員が退室すると、作成されたVCとテキストチャンネルは自動削除されます。")
                    } header: { Text("使い方") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("一時チャンネル")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingSource = TempVCSource.defaultSource(guildId: guildId)
                    isEditing = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
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
            if let toast {
                VStack {
                    Spacer()
                    Text(toast.message)
                        .font(.captionRegular).fontWeight(.medium).foregroundStyle(.white)
                        .padding(.horizontal, .spacing16).padding(.vertical, .spacing10)
                        .background(Color(.systemGray2)).clipShape(Capsule())
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .task { await loadAll() }
    }

    // MARK: - Source Row

    private func sourceRow(_ source: TempVCSource) -> some View {
        Button {
            editingSource = source
            isEditing = true
        } label: {
            VStack(alignment: .leading, spacing: .spacing8) {
                HStack(spacing: .spacing8) {
                    Image(systemName: source.enabled ? "mic.fill" : "mic.slash.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(source.enabled ? Color.accentIndigo : Color.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(source.enabled ? Color.accentIndigo.opacity(0.12) : Color.textTertiary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 7))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.triggerVcName)
                            .font(.bodySmall)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.textPrimary)
                        if source.triggerVcId != nil {
                            Text("トリガーVC作成済")
                                .font(.captionSmall)
                                .foregroundStyle(Color.accentGreen)
                        } else {
                            Text("トリガーVC未作成")
                                .font(.captionSmall)
                                .foregroundStyle(Color.textTertiary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                }

                HStack(spacing: .spacing12) {
                    Label("VC: \(categoryName(for: source.vcCategoryId))", systemImage: "folder")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                    Label("テキスト: \(categoryName(for: source.textChannelCategoryId))", systemImage: "text.bubble")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                    if source.userLimit > 0 {
                        Label("\(source.userLimit)人", systemImage: "person.2")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task { await deleteSource(source) }
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    private func categoryName(for id: String) -> String {
        categories.first(where: { $0.id == id })?.name ?? id
    }

    private func tipRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: .spacing12) {
            Image(systemName: icon)
                .font(.system(size: 13)).foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                Text(detail).font(.captionSmall).foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func loadAll() async {
        isLoading = true

        sources = (try? await services.tempVCSource.fetchSources(guildId: guildId)) ?? []

        if let url = URL(string: "\(DiscordConfig.workerURL)/bot/channels?guild_id=\(guildId)"),
           let (data, _) = try? await URLSession.shared.data(from: url) {
            struct RawCh: Decodable { let id: String; let name: String; let type: Int }
            if let chs = try? JSONDecoder().decode([RawCh].self, from: data) {
                categories = chs.filter { $0.type == 4 }.map { ($0.id, $0.name) }
            }
        }

        isLoading = false
    }

    private func saveSource(_ source: TempVCSource) async {
        do {
            var saved: TempVCSource
            if source.id != nil {
                saved = try await services.tempVCSource.updateSource(source)

                // 有効/無効の切り替えを処理
                if let triggerVcId = saved.triggerVcId {
                    if saved.enabled {
                        try await services.tempVCSource.showTriggerVc(
                            id: saved.effectiveId,
                            guildId: guildId,
                            triggerVcId: triggerVcId
                        )
                    } else {
                        try await services.tempVCSource.hideTriggerVc(
                            id: saved.effectiveId,
                            guildId: guildId,
                            triggerVcId: triggerVcId
                        )
                    }
                }

                showToast("✅ 保存しました")
            } else {
                saved = try await services.tempVCSource.createSource(source)

                // トリガーVCが未作成の場合は作成
                if saved.triggerVcId == nil {
                    saved = try await services.tempVCSource.createTriggerVc(
                        id: saved.effectiveId,
                        guildId: guildId,
                        triggerVcName: saved.triggerVcName,
                        vcCategoryId: saved.vcCategoryId
                    )
                    showToast("✅ 作成し、トリガーVCも作成しました")
                } else {
                    showToast("✅ 作成しました")
                }
            }

            withAnimation { isEditing = false }
            await loadAll()
        } catch {
            showToast("❌ 保存に失敗しました")
        }
    }

    private func deleteSource(_ source: TempVCSource) async {
        do {
            try await services.tempVCSource.deleteSource(id: source.effectiveId)
            showToast("🗑️ 削除しました")
            await loadAll()
        } catch {
            showToast("❌ 削除に失敗しました")
        }
    }

    private func showToast(_ msg: String) {
        withAnimation { toast = ToastMessage(type: .success, message: msg) }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { toast = nil }
        }
    }
}

#Preview {
    NavigationStack {
        TempVCListView(guildId: "g001")
    }
    .environment(\.services, ServiceContainer.mock())
    .environment(AppState())
    .preferredColorScheme(.dark)
}
