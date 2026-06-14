import SwiftUI

// MARK: - TempChannelSettingsView

struct TempChannelSettingsView: View {
    let guildId: String

    @Environment(\.services) private var services
    @State private var settings: TempChannelSettings? = nil
    @State private var isLoading = true
    @State private var isSaving = false

    // フォームフィールド
    @State private var enabled             = false
    @State private var categoryId          = ""
    @State private var channelNameFormat   = "chat-{vc-name}"
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

    // MARK: - Toast
    @State private var toastMessage: String? = nil
    @State private var toastIsError: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .padding(.vertical, Theme.Spacing.xl)
                } else {
                    // ── ON/OFF ──
                    section("基本設定") {
                        toggleRow("一時チャンネルを有効にする", isOn: $enabled)
                    } footer: {
                        "VCに参加したとき、参加者専用テキストチャンネルが自動作成されます"
                    }

                    if enabled {
                        // ── 詳細設定 ──
                        section("詳細設定") {
                            VStack(spacing: 0) {
                                pickerRow("作成先カテゴリ", selection: $categoryId) {
                                    Text("なし（デフォルト）").tag("")
                                    ForEach(categories, id: \.id) { Text($0.name).tag($0.id) }
                                }

                                Divider().padding(.leading, Theme.Spacing.md)

                                textFieldRow("チャンネル名フォーマット", text: $channelNameFormat, placeholder: "例: chat-{vc-name}")

                                // 変数チップ
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(["{vc-name}", "{user-name}", "{count}"], id: \.self) { v in
                                            Button { channelNameFormat += v } label: {
                                                Text(v)
                                                    .font(Theme.Font.caption2)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(Theme.Color.accent)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Theme.Color.accentDim)
                                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.vertical, Theme.Spacing.sm)
                                }

                                Divider().padding(.leading, Theme.Spacing.md)

                                stepperRow("最小参加人数", value: $minMembers, range: 1...10, suffix: "人")
                            }
                        } footer: {
                            "{vc-name}=VCの名前  {user-name}=最初の参加者  {count}=参加人数"
                        }

                        // ── 自動削除 ──
                        section("自動削除") {
                            VStack(spacing: 0) {
                                toggleRow("全員退室後に自動削除", isOn: $autoDelete)
                                if autoDelete {
                                    Divider().padding(.leading, Theme.Spacing.md)
                                    pickerRow("削除までの猶予", selection: $deleteDelay) {
                                        ForEach(delayOptions, id: \.0) { sec, label in
                                            Text(label).tag(sec)
                                        }
                                    }
                                }
                            }
                        } footer: {
                            "猶予時間を設けると、全員退室後もその間はメッセージを読めます"
                        }

                        // ── 通知 ──
                        section("通知") {
                            toggleRow("参加/退出の通知", isOn: $joinLeaveNotif)
                        } footer: {
                            "VCに誰かが参加/退出したとき、テキストチャンネルに通知メッセージを表示します"
                        }

                        // ── 対象VC ──
                        section("対象VC") {
                            toggleRow("すべてのVCを対象にする", isOn: $watchAllVcs)
                        } footer: {
                            watchAllVcs ? "" : "特定のVCのみ一時チャンネルを作成します"
                        }

                        // ── アクティブな一時チャンネル ──
                        if !activeChannels.isEmpty {
                            section("アクティブ (\(activeChannels.count)件)") {
                                VStack(spacing: 0) {
                                    ForEach(Array(activeChannels.enumerated()), id: \.element.id) { index, ch in
                                        HStack(spacing: Theme.Spacing.md) {
                                            Image(systemName: "number")
                                                .font(Theme.Font.caption2)
                                                .foregroundStyle(Theme.Color.textTertiary)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("<#\(ch.textChannelId)>")
                                                    .font(Theme.Font.body)
                                                    .foregroundStyle(Theme.Color.textPrimary)
                                Text("VC: \(ch.vcChannelId) ・ \(ch.createdAt.formatted(.relative(presentation: .named)))")
                                    .font(Theme.Font.caption2)
                                    .foregroundStyle(Theme.Color.textTertiary)
                                    .monospaced()
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, Theme.Spacing.md)
                                        .padding(.vertical, Theme.Spacing.sm)
                                        if index < activeChannels.count - 1 {
                                            Divider().padding(.leading, Theme.Spacing.md)
                                        }
                                    }
                                }
                            }
                        }
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
            if !isLoading {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "保存中..." : "保存") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(isSaving ? Theme.Color.textTertiary : Theme.Color.accent)
                    .disabled(isSaving)
                }
            }
        }
        .overlay {
            toastOverlay
        }
        .task { await loadAll() }
    }

    // MARK: - Section Builder

    private func section(
        _ title: String,
        @ViewBuilder content: () -> some View,
        footer: @escaping () -> String? = { nil }
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionLabel(title: title)
            VStack(spacing: 0) {
                content()
            }
            .background(Theme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Theme.Color.line, lineWidth: 1)
            )
            if let f = footer(), !f.isEmpty {
                Text(f)
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
            }
        }
    }

    // MARK: - Row Components

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .tint(Theme.Color.accent)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
    }

    private func pickerRow<Selection: Hashable>(
        _ title: String,
        selection: Binding<Selection>,
        @ViewBuilder content: () -> some View
    ) -> some View {
        HStack {
            Text(title)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textPrimary)
            Spacer()
            Picker("", selection: selection) {
                content()
            }
            .pickerStyle(.menu)
            .tint(Theme.Color.accent)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func textFieldRow(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Font.caption2)
                .foregroundStyle(Theme.Color.textTertiary)
            TextField(placeholder, text: text)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textPrimary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Color.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.button)
                        .stroke(Theme.Color.line, lineWidth: 1)
                )
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func stepperRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, suffix: String) -> some View {
        HStack {
            Text(title)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textPrimary)
            Spacer()
            HStack(spacing: Theme.Spacing.sm) {
                Text("\(value.wrappedValue)\(suffix)")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .monospaced()
                    .monospaced()
                Stepper("", value: value, in: range)
                    .labelsHidden()
                    .tint(Theme.Color.accent)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
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

        struct RawCh: Decodable { let id: String; let name: String; let type: Int }
        if let chs = try? await WorkerClient().get("/bot/channels?guild_id=\(guildId)") as [RawCh] {
            categories    = chs.filter { $0.type == 4 }.map { ($0.id, $0.name) }
            voiceChannels = chs.filter { $0.type == 2 }.map { ($0.id, $0.name) }
        }

        isLoading = false
    }

    private func save() async {
        guard var s = settings else { return }
        isSaving = true

        s.enabled              = enabled
        s.categoryId           = categoryId.isEmpty ? nil : categoryId
        s.channelNameFormat    = channelNameFormat.isEmpty ? "chat-{vc-name}" : channelNameFormat
        s.autoDelete           = autoDelete
        s.deleteDelayMinutes   = deleteDelay
        s.joinLeaveNotification = joinLeaveNotif
        s.watchAllVcs          = watchAllVcs
        s.minMembers           = minMembers

        do {
            let saved = try await services.tempChannel.saveSettings(s)
            settings = saved
            showToast("保存しました")
        } catch {
            showToast("保存に失敗しました", isError: true)
        }
        isSaving = false
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
        TempChannelSettingsView(guildId: "g001")
    }
    .environment(\.services, ServiceContainer.mock())
    .environment(AppState())
}
