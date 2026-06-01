import SwiftUI

// MARK: - TempChannelSettingsView

struct TempChannelSettingsView: View {
    let guildId: String

    @Environment(\.services) private var services
    @State private var settings: TempChannelSettings? = nil
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var toast: ToastMessage? = nil

    // フォームフィールド
    @State private var enabled             = false
    @State private var categoryId          = ""
    @State private var channelNameFormat   = "💬-{vc-name}"
    @State private var autoDelete          = true
    @State private var deleteDelay         = 0
    @State private var joinLeaveNotif      = true
    @State private var watchAllVcs         = true
    @State private var minMembers          = 1

    // Discord データ
    @State private var categories:   [(id: String, name: String)] = []
    @State private var voiceChannels: [(id: String, name: String)] = []
    @State private var activeChannels: [ActiveTempChannel] = []

    private let delayOptions = [
        (0, "即座に削除"),
        (1, "1分後"),
        (3, "3分後"),
        (5, "5分後"),
        (10, "10分後"),
        (30, "30分後"),
    ]

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color(.systemGroupedBackground))
            } else {
                // ── ON/OFF ──
                Section {
                    Toggle("一時チャンネルを有効にする", isOn: $enabled.animation())
                        .tint(Color.accentIndigo)
                } footer: {
                    Text("VCに参加したとき、参加者専用のテキストチャンネルが自動で作成されます。")
                }

                if enabled {
                    // ── 基本設定 ──
                    Section {
                        Picker("作成先カテゴリ", selection: $categoryId) {
                            Text("なし（デフォルト）").tag("")
                            ForEach(categories, id: \.id) { Text($0.name).tag($0.id) }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("チャンネル名フォーマット").font(.captionSmall).foregroundStyle(Color.textTertiary)
                            TextField("例: 💬-{vc-name}", text: $channelNameFormat)
                                .font(.bodySmall)
                            // 変数チップ
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(["{vc-name}", "{user-name}", "{count}"], id: \.self) { v in
                                        Button { channelNameFormat += v } label: {
                                            Text(v).font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(Color.accentIndigo)
                                                .padding(.horizontal, 8).padding(.vertical, 4)
                                                .background(Color.accentIndigo.opacity(0.1)).clipShape(Capsule())
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        Stepper("最小参加人数：\(minMembers)人", value: $minMembers, in: 1...10)
                    } header: { Text("基本設定") }
                      footer: { Text("{vc-name}=VCの名前  {user-name}=最初の参加者  {count}=参加人数") }

                    // ── 自動削除 ──
                    Section {
                        Toggle("全員退室後に自動削除", isOn: $autoDelete.animation()).tint(Color.accentIndigo)
                        if autoDelete {
                            Picker("削除までの猶予", selection: $deleteDelay) {
                                ForEach(delayOptions, id: \.0) { sec, label in
                                    Text(label).tag(sec)
                                }
                            }
                        }
                    } header: { Text("自動削除") }
                      footer: { Text("猶予時間を設けると、全員退室後もその間はメッセージを読めます。") }

                    // ── 通知 ──
                    Section {
                        Toggle("参加/退出の通知", isOn: $joinLeaveNotif).tint(Color.accentIndigo)
                    } header: { Text("通知") }
                      footer: { Text("VCに誰かが参加/退出したとき、テキストチャンネルに通知メッセージを表示します。") }

                    // ── 対象VC ──
                    Section {
                        Toggle("すべてのVCを対象にする", isOn: $watchAllVcs.animation()).tint(Color.accentIndigo)
                        if !watchAllVcs {
                            if voiceChannels.isEmpty {
                                Text("VCが見つかりません").font(.captionRegular).foregroundStyle(Color.textTertiary)
                            } else {
                                Text("対象VCを選択してください").font(.captionSmall).foregroundStyle(Color.textTertiary)
                                // 特定VC選択（将来実装: watchVcIds を使う）
                                // 現状はすべてON/OFFのみ
                            }
                        }
                    } header: { Text("対象VCの設定") }
                      footer: { watchAllVcs ? Text("") : Text("特定のVCのみ一時チャンネルを作成します。") }

                    // ── アクティブな一時チャンネル ──
                    if !activeChannels.isEmpty {
                        Section {
                            ForEach(activeChannels) { ch in
                                HStack(spacing: .spacing12) {
                                    Image(systemName: "number").font(.captionSmall).foregroundStyle(Color.textTertiary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("<#\(ch.textChannelId)>").font(.bodySmall).foregroundStyle(Color.textPrimary)
                                        Text("VC: \(ch.vcChannelId) • \(ch.createdAt.formatted(.relative(presentation: .named)))")
                                            .font(.captionSmall).foregroundStyle(Color.textTertiary)
                                    }
                                }
                            }
                        } header: { Text("現在アクティブな一時チャンネル（\(activeChannels.count)件）") }
                    }

                    // ── 使い方ガイド ──
                    Section {
                        tipRow(icon: "mic.fill", color: .accentIndigo,
                               title: "VCに参加",
                               detail: "設定対象のVCに入ると、専用テキストチャンネルが自動で作成されます。")
                        tipRow(icon: "lock.fill", color: .accentOrange,
                               title: "参加者専用",
                               detail: "チャンネルはVCに入っている人だけが見えます。誰でも閲覧できるわけではありません。")
                        tipRow(icon: "trash.fill", color: .red,
                               title: "自動削除",
                               detail: "VCが空になると（猶予時間後に）チャンネルは自動削除されます。")
                    } header: { Text("使い方") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("一時チャンネル")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !isLoading {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "保存中..." : "保存") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(isSaving ? Color.textTertiary : Color.accentIndigo)
                    .disabled(isSaving)
                }
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

    // MARK: - Helpers

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
        async let settingsTask     = services.tempChannel.fetchSettings(guildId: guildId)
        async let activeTask       = services.tempChannel.fetchActiveChannels(guildId: guildId)

        let s = (try? await settingsTask) ?? TempChannelSettings.defaultSettings(guildId: guildId)
        settings = s
        enabled              = s.enabled
        categoryId           = s.categoryId ?? ""
        channelNameFormat    = s.channelNameFormat
        autoDelete           = s.autoDelete
        deleteDelay          = s.deleteDelayMinutes
        joinLeaveNotif       = s.joinLeaveNotification
        watchAllVcs          = s.watchAllVcs
        minMembers           = s.minMembers

        activeChannels = (try? await activeTask) ?? []

        // チャンネル一覧（カテゴリ・VC）を取得
        if let url = URL(string: "\(DiscordConfig.workerURL)/bot/channels?guild_id=\(guildId)"),
           let (data, _) = try? await URLSession.shared.data(from: url) {
            struct RawCh: Decodable { let id: String; let name: String; let type: Int }
            if let chs = try? JSONDecoder().decode([RawCh].self, from: data) {
                categories    = chs.filter { $0.type == 4 }.map { ($0.id, $0.name) }
                voiceChannels = chs.filter { $0.type == 2 }.map { ($0.id, $0.name) }
            }
        }

        isLoading = false
    }

    private func save() async {
        guard var s = settings else { return }
        isSaving = true

        s.enabled              = enabled
        s.categoryId           = categoryId.isEmpty ? nil : categoryId
        s.channelNameFormat    = channelNameFormat.isEmpty ? "💬-{vc-name}" : channelNameFormat
        s.autoDelete           = autoDelete
        s.deleteDelayMinutes   = deleteDelay
        s.joinLeaveNotification = joinLeaveNotif
        s.watchAllVcs          = watchAllVcs
        s.minMembers           = minMembers

        do {
            settings = try await services.tempChannel.saveSettings(s)
            showToast("✅ 保存しました")
        } catch {
            showToast("❌ 保存に失敗しました")
        }
        isSaving = false
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
        TempChannelSettingsView(guildId: "g001")
    }
    .environment(\.services, ServiceContainer.mock())
    .environment(AppState())
    .preferredColorScheme(.dark)
}
