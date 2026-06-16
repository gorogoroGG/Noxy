import SwiftUI

// MARK: - VCNotificationSettingsView
// VC（ボイスチャンネル）への参加・退出・移動・配信を、指定テキストチャンネルへ通知する設定画面。

struct VCNotificationSettingsView: View {
    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState

    enum FieldFocus: Hashable {
        case joinMsg, leaveMsg
    }

    @FocusState private var focusedField: FieldFocus?

    @State private var settings: VCNotificationSettings? = nil
    @State private var channels: [Channel] = []
    @State private var roles: [DiscordRole] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var toast: ToastMessage? = nil
    @State private var keyboardHeight: CGFloat = 0

    // フォームフィールド
    @State private var enabled            = false
    @State private var notifyChannelId    = ""
    @State private var notifyChannelName  = ""
    @State private var notifyOnJoin       = true
    @State private var notifyOnLeave      = false
    @State private var notifyOnMove       = false
    @State private var notifyOnStream     = false
    @State private var watchAllVcs        = true
    @State private var watchVcIds: [String] = []
    @State private var joinMessage        = ""
    @State private var leaveMessage       = ""
    @State private var useEmbed           = true
    @State private var onlyFirstJoin      = false
    @State private var excludeBots        = true
    @State private var mentionRoleEnabled = false
    @State private var mentionRoleId      = ""
    @State private var mentionRoleName    = ""

    private let messageVars = [
        ("{user.mention}", "{user.mention}"),
        ("{user.name}",    "{user.name}"),
        ("{vc.name}",      "{vc.name}"),
        ("{vc.count}",     "{vc.count}"),
    ]

    private var voiceChannels: [Channel] {
        channels.filter { $0.type == .voice }
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.md) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Spacing.xxl)
                } else {
                    content
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight : 0)
        }
        .scrollDismissesKeyboard(.never)
        .background(Theme.Color.bg)
        .navigationTitle("VC参加通知")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving { ProgressView().scaleEffect(0.8) }
                    else { Text("保存").fontWeight(.semibold) }
                }
                .disabled(isSaving)
            }
            keyboardToolbar
        }
        .toast($toast)
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { n in
            if let rect = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = rect.height }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = 0 }
        }
    }

    @ViewBuilder
    private var content: some View {
        // ON/OFF
        FormSection("VC参加通知", icon: "speaker.wave.2.circle", footer: "VCの入退室を指定チャンネルに通知します") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("VC通知を有効にする")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text(enabled ? "有効" : "無効")
                        .font(Theme.Font.caption2)
                        .foregroundStyle(enabled ? Theme.Color.statusOK : Theme.Color.textTertiary)
                }
                Spacer()
                Toggle("", isOn: $enabled.animation())
                    .tint(Theme.Color.accent)
                    .labelsHidden()
            }
            .padding(.vertical, Theme.Spacing.xs)
        }

        if enabled {
            channelSection
            eventSection
            targetVcSection
            messageSection
            noiseSection
            mentionSection
        }
    }

    // MARK: - 通知先チャンネル

    private var channelSection: some View {
        FormSection("通知先チャンネル", icon: "number") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if channels.isEmpty {
                    loadingRow
                } else {
                    let textChs = channels.filter { $0.type == .text || $0.type == .announcement }
                    Menu {
                        if !notifyChannelId.isEmpty {
                            Button(role: .destructive) {
                                notifyChannelId = ""
                                notifyChannelName = ""
                            } label: { Label("選択を解除", systemImage: "xmark") }
                            Divider()
                        }
                        ForEach(textChs) { ch in
                            Button {
                                notifyChannelId = ch.id
                                notifyChannelName = ch.name
                            } label: {
                                Label(ch.name, systemImage: ch.type == .announcement ? "megaphone" : "number")
                            }
                        }
                    } label: {
                        HStack(spacing: Theme.Spacing.xs) {
                            if notifyChannelId.isEmpty {
                                Image(systemName: "number")
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Color.textTertiary)
                                Text("チャンネルを選択...")
                                    .font(Theme.Font.body)
                                    .foregroundStyle(Theme.Color.textTertiary)
                            } else {
                                let sel = textChs.first(where: { $0.id == notifyChannelId })
                                Image(systemName: sel?.type == .announcement ? "megaphone" : "number")
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Color.accent)
                                Text(notifyChannelName)
                                    .font(Theme.Font.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Theme.Color.textPrimary)
                            }
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Theme.Color.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 通知イベント

    private var eventSection: some View {
        FormSection("通知するイベント", icon: "bell.badge", footer: "通知したいタイミングを選択します") {
            VStack(spacing: 0) {
                eventToggle("参加したとき", systemImage: "arrow.right.circle", isOn: $notifyOnJoin)
                Divider().padding(.leading, 32)
                eventToggle("退出したとき", systemImage: "arrow.left.circle", isOn: $notifyOnLeave)
                Divider().padding(.leading, 32)
                eventToggle("別のVCへ移動したとき", systemImage: "arrow.left.arrow.right", isOn: $notifyOnMove)
                Divider().padding(.leading, 32)
                eventToggle("配信・画面共有の開始/終了", systemImage: "rectangle.on.rectangle", isOn: $notifyOnStream)
            }
        }
    }

    private func eventToggle(_ title: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.accent)
                .frame(width: 20)
            Toggle(title, isOn: isOn)
                .tint(Theme.Color.accent)
                .font(Theme.Font.body)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    // MARK: - 対象VC

    private var targetVcSection: some View {
        FormSection("対象VC", icon: "waveform", footer: watchAllVcs ? nil : "選択したVCのみ通知します") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Toggle("すべてのVCを対象にする", isOn: $watchAllVcs.animation())
                    .tint(Theme.Color.accent)
                    .font(Theme.Font.body)
                    .padding(.vertical, Theme.Spacing.xs)

                if !watchAllVcs {
                    if voiceChannels.isEmpty {
                        loadingRow
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(voiceChannels.enumerated()), id: \.element.id) { index, vc in
                                Button {
                                    toggleWatchVc(vc.id)
                                } label: {
                                    HStack(spacing: Theme.Spacing.sm) {
                                        Image(systemName: "speaker.wave.2")
                                            .font(Theme.Font.caption)
                                            .foregroundStyle(Theme.Color.textTertiary)
                                            .frame(width: 20)
                                        Text(vc.name)
                                            .font(Theme.Font.body)
                                            .foregroundStyle(Theme.Color.textPrimary)
                                        Spacer()
                                        if watchVcIds.contains(vc.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Theme.Color.accent)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundStyle(Theme.Color.textTertiary)
                                        }
                                    }
                                    .padding(.vertical, Theme.Spacing.sm)
                                }
                                .buttonStyle(.plain)
                                if index < voiceChannels.count - 1 {
                                    Divider().padding(.leading, 32)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func toggleWatchVc(_ id: String) {
        if let idx = watchVcIds.firstIndex(of: id) {
            watchVcIds.remove(at: idx)
        } else {
            watchVcIds.append(id)
        }
    }

    // MARK: - メッセージ

    private var messageSection: some View {
        FormSection("メッセージ", icon: "text.bubble") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Toggle("Embed形式で送信", isOn: $useEmbed.animation())
                    .tint(Theme.Color.accent)
                    .font(Theme.Font.body)

                Text("参加メッセージ")
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
                messageEditor(text: $joinMessage, focus: .joinMsg, placeholder: "参加メッセージを入力...")

                if notifyOnLeave {
                    Text("退出メッセージ")
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                    messageEditor(text: $leaveMessage, focus: .leaveMsg, placeholder: "退出メッセージを入力...")
                    Text("{user.mention} は退出時には使用できません")
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
            }
        }
    }

    private func messageEditor(text: Binding<String>, focus: FieldFocus, placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textTertiary)
                    .padding(.top, 10)
                    .padding(.leading, 14)
                    .allowsHitTesting(false)
            }
            TextEditor(text: text)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textPrimary)
                .scrollContentBackground(.hidden)
                .background(.clear)
                .frame(minHeight: 70, maxHeight: 120)
                .focused($focusedField, equals: focus)
        }
        .padding(2)
        .background(Theme.Color.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
    }

    // MARK: - ノイズ対策

    private var noiseSection: some View {
        FormSection("通知の調整", icon: "slider.horizontal.3", footer: "通知の鳴りすぎを防ぎます") {
            VStack(spacing: 0) {
                Toggle("最初の1人だけ通知（VCが立った瞬間）", isOn: $onlyFirstJoin)
                    .tint(Theme.Color.accent)
                    .font(Theme.Font.body)
                    .padding(.vertical, Theme.Spacing.xs)
                Divider()
                Toggle("BOTの入退室を無視", isOn: $excludeBots)
                    .tint(Theme.Color.accent)
                    .font(Theme.Font.body)
                    .padding(.vertical, Theme.Spacing.xs)
            }
        }
    }

    // MARK: - ロールメンション（Pro）

    private var mentionSection: some View {
        FormSection("ロールメンション", icon: "at") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("VCが立ったときロールに通知")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Spacer()
                    if !appState.isPro {
                        Badge(text: "Pro", color: Theme.Color.statusWarn)
                    } else {
                        Toggle("", isOn: $mentionRoleEnabled.animation())
                            .tint(Theme.Color.accent)
                            .labelsHidden()
                    }
                }

                if !appState.isPro {
                    Text("Proプランで利用可能")
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                } else if mentionRoleEnabled {
                    rolePicker
                    if !mentionRoleName.isEmpty {
                        HStack(spacing: Theme.Spacing.xs) {
                            StatusDot(color: Theme.Color.statusOK)
                            Text("VCが立つと @\(mentionRoleName) にメンションします")
                                .font(Theme.Font.caption2)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var rolePicker: some View {
        if roles.isEmpty {
            ProgressView().frame(maxWidth: .infinity)
        } else {
            Picker("ロール", selection: $mentionRoleId) {
                Text("ロールを選択").tag("")
                ForEach(roles.filter { $0.name != "@everyone" && !$0.managed }) { role in
                    Text("@\(role.name)").tag(role.id)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.Color.textSecondary)
            .onChange(of: mentionRoleId) { _, newId in
                mentionRoleName = roles.first(where: { $0.id == newId })?.name ?? ""
            }
        }
    }

    // MARK: - 共通UI

    private var loadingRow: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ProgressView().scaleEffect(0.7)
            Text("読み込み中...")
                .font(Theme.Font.caption2)
                .foregroundStyle(Theme.Color.textTertiary)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
    }

    // MARK: - Keyboard Toolbar

    @ToolbarContentBuilder
    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(messageVars, id: \.0) { label, value in
                        Button {
                            insertVariable(value)
                        } label: {
                            Text(label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.Color.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.Color.accentDim)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 34)
            .clipped()

            Button("完了") { focusedField = nil }
                .font(Theme.Font.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Color.accent)
                .padding(.leading, Theme.Spacing.xs)
        }
    }

    private func insertVariable(_ v: String) {
        switch focusedField {
        case .joinMsg:  joinMessage  += v
        case .leaveMsg: leaveMessage += v
        case .none: break
        }
    }

    // MARK: - Load / Save

    private func apply(_ s: VCNotificationSettings) {
        settings           = s
        enabled            = s.enabled
        notifyChannelId    = s.notifyChannelId
        notifyChannelName  = s.notifyChannelName
        notifyOnJoin       = s.notifyOnJoin
        notifyOnLeave      = s.notifyOnLeave
        notifyOnMove       = s.notifyOnMove
        notifyOnStream     = s.notifyOnStream
        watchAllVcs        = s.watchAllVcs
        watchVcIds         = s.watchVcIds
        joinMessage        = s.joinMessage
        leaveMessage       = s.leaveMessage
        useEmbed           = s.useEmbed
        onlyFirstJoin      = s.onlyFirstJoin
        excludeBots        = s.excludeBots
        mentionRoleEnabled = s.mentionRoleEnabled
        mentionRoleId      = s.mentionRoleId
        mentionRoleName    = s.mentionRoleName
    }

    private func load() async {
        let gid = appState.selectedGuildId
        guard !gid.isEmpty else { isLoading = false; return }

        // 先読み済みキャッシュがあれば即表示
        if let cachedS: VCNotificationSettings = appState.guildData(.vcNotificationSettings, guild: gid) {
            apply(cachedS)
            if let cachedC: [Channel] = appState.guildData(.channels, guild: gid) { channels = cachedC }
            if let cachedR: [DiscordRole] = appState.guildData(.roles, guild: gid) { roles = cachedR }
            isLoading = false
        }

        async let sTask = services.vcNotification.fetchSettings(guildId: gid)
        async let cTask = services.guilds.fetchChannels(guildId: gid)
        async let rTask = DiscordService().fetchRoles(guildId: gid)

        let s = (try? await sTask) ?? settings ?? VCNotificationSettings.defaultSettings(guildId: gid)
        apply(s)
        appState.setGuildData(s, .vcNotificationSettings, guild: gid)
        if let c = try? await cTask { channels = c; appState.setGuildData(c, .channels, guild: gid) }
        if let r = try? await rTask { roles = r; appState.setGuildData(r, .roles, guild: gid) }
        isLoading = false
    }

    private func save() async {
        isSaving = true
        var s = settings ?? VCNotificationSettings.defaultSettings(guildId: appState.selectedGuildId)
        s.enabled            = enabled
        s.notifyChannelId    = notifyChannelId
        s.notifyChannelName  = notifyChannelName
        s.notifyOnJoin       = notifyOnJoin
        s.notifyOnLeave      = notifyOnLeave
        s.notifyOnMove       = notifyOnMove
        s.notifyOnStream     = notifyOnStream
        s.watchAllVcs        = watchAllVcs
        s.watchVcIds         = watchVcIds
        s.joinMessage        = joinMessage
        s.leaveMessage       = leaveMessage
        s.useEmbed           = useEmbed
        s.onlyFirstJoin      = onlyFirstJoin
        s.excludeBots        = excludeBots
        s.mentionRoleEnabled = mentionRoleEnabled
        s.mentionRoleId      = mentionRoleId
        s.mentionRoleName    = mentionRoleName

        let saved = (try? await services.vcNotification.saveSettings(s)) ?? s
        apply(saved)
        appState.setGuildData(saved, .vcNotificationSettings, guild: appState.selectedGuildId)
        isSaving = false
        toast = ToastMessage(type: .success, message: "保存しました")
    }
}

#Preview("Dark") {
    NavigationStack { VCNotificationSettingsView() }
        .environment(\.services, ServiceContainer.mock())
        .environment(AppState())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    NavigationStack { VCNotificationSettingsView() }
        .environment(\.services, ServiceContainer.mock())
        .environment(AppState())
        .preferredColorScheme(.light)
}
