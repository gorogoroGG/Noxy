import SwiftUI

struct TempVCListView: View {
    let guildId: String

    @Environment(\.services)    private var services
    @Environment(AppState.self) private var appState
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
                        tipRow(icon: "lock.shield.fill", color: .accentIndigo,
                               title: "待機室認証",
                               detail: "オンにすると「〇〇-待機室」が自動作成されます。一般ユーザーは待機室から入室リクエストを送り、VC内のメンバーが承認/拒否できます。")
                        tipRow(icon: "trash.fill", color: .red,
                               title: "自動削除",
                               detail: "全員が退室すると、作成されたVC・テキストチャンネル・待機室が自動削除されます。")
                    } header: { Text("使い方") }
                }
            }
        }
        .listStyle(.insetGrouped)
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
                        .foregroundStyle(atFreeLimit ? Color.textTertiary : Color.accentIndigo)
                }
                .disabled(atFreeLimit)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !appState.isPro && !sources.isEmpty {
                HStack(spacing: .spacing6) {
                    Image(systemName: "lock.fill").font(.captionSmall)
                    Text("無料プランはソース1つまで。Proプランで追加できます。")
                        .font(.captionSmall)
                    Spacer()
                    NavigationLink(destination: SubscriptionView()) {
                        Text("アップグレード").font(.captionSmall).fontWeight(.semibold)
                    }
                }
                .foregroundStyle(Color.textTertiary)
                .padding(.horizontal).padding(.vertical, .spacing10)
                .background(.regularMaterial)
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
                        .background(Color.gray.opacity(0.25)).clipShape(Capsule())
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .task { await loadAll() }
        .onChange(of: guildId) { _, _ in
            isLoading = true
            Task { await loadAll() }
        }
    }

    // MARK: - Source Row

    private func sourceRow(_ source: TempVCSource) -> some View {
        Button {
            editingSource = source
            isEditing = true
        } label: {
            VStack(alignment: .leading, spacing: .spacing8) {
                HStack(spacing: .spacing8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentIndigo)
                        .frame(width: 28, height: 28)
                        .background(Color.accentIndigo.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 7))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: .spacing6) {
                            Text(source.triggerVcName)
                                .font(.bodySmall)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.textPrimary)
                            if source.waitingRoomEnabled {
                                Badge(text: "待機室", color: .accentIndigo)
                            }
                        }
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

    /// 初回・guildId変更時のみ isLoading を立てる。
    /// silent=true のときはリストを維持したままバックグラウンドでデータを更新する。
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
                // ── 更新：リスト内の該当行だけ差し替え ──────────────
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
                showToast("✅ 保存しました")
            } else {
                // ── 新規作成：先頭に追加 ──────────────────────────
                saved = try await services.tempVCSource.createSource(source)

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

                withAnimation { sources.insert(saved, at: 0) }
            }

            withAnimation { isEditing = false }
        } catch {
            showToast("❌ 保存に失敗しました")
        }
    }

    private func deleteSource(_ source: TempVCSource) async {
        // 楽観的削除：先にリストから消してトーストを表示
        withAnimation { sources.removeAll { $0.id == source.id } }
        showToast("🗑️ 削除しました")

        do {
            try await services.tempVCSource.deleteSource(id: source.effectiveId)
        } catch {
            // 失敗時は元に戻す
            withAnimation { sources.append(source) }
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
}
