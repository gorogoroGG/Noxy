import SwiftUI

struct WelcomeMessageView: View {
    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState

    @State private var settings: GreetingSettings? = nil
    @State private var channels: [Channel] = []
    @State private var roles: [DiscordRole] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var toast: ToastMessage? = nil

    private let variables = ["{user.mention}", "{user.name}", "{server.name}", "{member.count}"]

    @State private var enabled = false
    @State private var channelId = ""
    @State private var channelName = ""
    @State private var message = ""
    @State private var dmEnabled = false
    @State private var dmMessage = ""
    @State private var roleEnabled = false
    @State private var roleId = ""
    @State private var roleName = ""

    var body: some View {
        List {
            Section {
                Toggle("ウェルカムメッセージを有効にする", isOn: $enabled.animation())
                    .tint(Color.accentGreen)
            }

            if enabled {
                // ── 送信先チャンネル ──
                Section {
                    if channels.isEmpty {
                        ProgressView("チャンネルを読み込み中...")
                            .frame(maxWidth: .infinity)
                    } else {
                        Picker("チャンネル", selection: $channelId) {
                            Text("チャンネルを選択").tag("")
                            ForEach(channels.filter { $0.type == .text || $0.type == .announcement }) { ch in
                                Label("#\(ch.name)", systemImage: ch.type == .announcement ? "megaphone" : "number")
                                    .tag(ch.id)
                            }
                        }
                        .onChange(of: channelId) { id in
                            channelName = channels.first(where: { $0.id == id })?.name ?? ""
                        }
                    }
                } header: { Text("送信先チャンネル") }
                  footer: { Text("新メンバーが参加したときにメッセージを送るチャンネルです。") }

                // ── チャンネルメッセージ ──
                Section {
                    ZStack(alignment: .topLeading) {
                        if message.isEmpty {
                            Text("メッセージを入力...")
                                .foregroundStyle(Color.textTertiary)
                                .font(.bodyRegular)
                                .padding(.top, 8).padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $message)
                            .font(.bodyRegular)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                    }
                    variableChips(for: $message, color: .accentGreen)
                } header: { Text("チャンネルメッセージ") }

                // ── チャンネルプレビュー ──
                Section {
                    discordChannelPreview(
                        text: buildHighlighted(message, color: .accentGreen),
                        gradient: LinearGradient(
                            colors: [.accentIndigo, .accentPurple],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                        icon: "bolt.fill"
                    )
                } header: { Text("チャンネルメッセージ プレビュー") }

                // ── DM 設定 ──
                Section {
                    Toggle("新メンバーにDMを送信", isOn: $dmEnabled.animation())
                        .tint(Color.accentGreen)

                    if dmEnabled {
                        ZStack(alignment: .topLeading) {
                            if dmMessage.isEmpty {
                                Text("DMメッセージを入力...")
                                    .foregroundStyle(Color.textTertiary)
                                    .font(.bodyRegular)
                                    .padding(.top, 8).padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $dmMessage)
                                .font(.bodyRegular)
                                .frame(minHeight: 60)
                                .scrollContentBackground(.hidden)
                        }
                        variableChips(for: $dmMessage, color: .accentGreen)
                    }
                } header: { Text("ダイレクトメッセージ") }
                  footer: { dmEnabled ? Text("{user.mention} はDMでは使用できません。") : nil }

                // ── DM プレビュー ──
                if dmEnabled {
                    Section {
                        dmPreview(
                            text: buildHighlighted(dmMessage, color: .accentGreen),
                            gradient: LinearGradient(
                                colors: [.accentIndigo, .accentPurple],
                                startPoint: .topLeading, endPoint: .bottomTrailing),
                            icon: "bolt.fill"
                        )
                    } header: { Text("DM プレビュー") }
                }

                // ── 参加時ロール付与（入室のみ） ──
                Section {
                    Toggle("参加時にロールを付与", isOn: $roleEnabled.animation())
                        .tint(Color.accentGreen)

                    if roleEnabled {
                        if roles.isEmpty {
                            ProgressView("ロールを読み込み中...").frame(maxWidth: .infinity)
                        } else {
                            Picker("付与するロール", selection: $roleId) {
                                Text("ロールを選択").tag("")
                                ForEach(roles.filter { $0.name != "@everyone" && !$0.managed }) { role in
                                    Text("@\(role.name)").tag(role.id)
                                }
                            }
                            .onChange(of: roleId) { id in
                                roleName = roles.first(where: { $0.id == id })?.name ?? ""
                            }
                        }
                    }
                } header: { Text("参加時ロール付与") }
                  footer: {
                    if roleEnabled && !roleName.isEmpty {
                        Text("参加した全メンバーに @\(roleName) ロールを自動で付与します。")
                    }
                  }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("ウェルカムメッセージ")
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
        }
        .toast($toast)
        .task { await load() }
        .redacted(reason: isLoading ? .placeholder : [])
    }

    // MARK: - 変数チップ

    private func variableChips(for text: Binding<String>, color: Color) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .spacing8) {
                ForEach(variables, id: \.self) { v in
                    Button { text.wrappedValue += v } label: {
                        Text(v)
                            .font(.caption).fontWeight(.medium)
                            .foregroundStyle(color)
                            .padding(.horizontal, .spacing8).padding(.vertical, 4)
                            .background(color.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - チャンネルプレビュー

    private func discordChannelPreview(text: AttributedString, gradient: LinearGradient, icon: String) -> some View {
        HStack(alignment: .top, spacing: .spacing12) {
            ZStack {
                Circle().fill(gradient).frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: .spacing6) {
                    Text("Noxy").font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                    Text("BOT")
                        .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(Color.accentIndigo)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Text(text).font(.bodySmall).foregroundStyle(Color.textPrimary)
            }
        }
        .padding(.vertical, .spacing4)
    }

    // MARK: - DM プレビュー

    private func dmPreview(text: AttributedString, gradient: LinearGradient, icon: String) -> some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            HStack(spacing: .spacing6) {
                Image(systemName: "envelope.fill").font(.captionSmall).foregroundStyle(Color.accentGreen)
                Text("ダイレクトメッセージ").font(.captionSmall).foregroundStyle(Color.accentGreen)
            }
            HStack(alignment: .top, spacing: .spacing10) {
                ZStack {
                    Circle().fill(gradient).frame(width: 32, height: 32)
                    Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Noxy").font(.captionRegular).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                    Text(text).font(.captionRegular).foregroundStyle(Color.textPrimary)
                }
                .padding(.horizontal, .spacing10).padding(.vertical, .spacing8)
                .background(Color.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, .spacing4)
    }

    // MARK: - 変数ハイライト

    private func buildHighlighted(_ raw: String, color: Color) -> AttributedString {
        let map: [(String, String)] = [
            ("{user.mention}", "@NewMember"),
            ("{user.name}",    "NewMember"),
            ("{server.name}",  appState.selectedGuild?.name ?? "サーバー"),
            ("{member.count}", "1,234"),
        ]
        var result = AttributedString()
        var remaining = raw
        while !remaining.isEmpty {
            var matched = false
            for (variable, replacement) in map {
                if remaining.hasPrefix(variable) {
                    var chunk = AttributedString(replacement)
                    chunk.foregroundColor = UIColor(color)
                    chunk.font = UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)
                    result.append(chunk)
                    remaining = String(remaining.dropFirst(variable.count))
                    matched = true; break
                }
            }
            if !matched {
                result.append(AttributedString(String(remaining.removeFirst())))
            }
        }
        return result
    }

    // MARK: - Supabase

    private func load() async {
        guard !appState.selectedGuildId.isEmpty else { isLoading = false; return }
        async let sTask = services.greeting.fetch(guildId: appState.selectedGuildId)
        async let cTask = services.guilds.fetchChannels(guildId: appState.selectedGuildId)
        async let rTask = DiscordService().fetchRoles(guildId: appState.selectedGuildId)

        let s = (try? await sTask) ?? GreetingSettings.defaultSettings(guildId: appState.selectedGuildId)
        channels = (try? await cTask) ?? []
        roles    = (try? await rTask) ?? []

        enabled     = s.welcomeEnabled
        channelId   = s.welcomeChannelId
        channelName = s.welcomeChannelName
        message     = s.welcomeMessage
        dmEnabled   = s.welcomeDmEnabled
        dmMessage   = s.welcomeDmMessage
        roleEnabled = s.welcomeRoleEnabled
        roleId      = s.welcomeRoleId
        roleName    = s.welcomeRoleName
        settings    = s
        isLoading   = false
    }

    private func save() async {
        isSaving = true
        var s = settings ?? GreetingSettings.defaultSettings(guildId: appState.selectedGuildId)
        s.welcomeEnabled     = enabled
        s.welcomeChannelId   = channelId
        s.welcomeChannelName = channelName
        s.welcomeMessage     = message
        s.welcomeDmEnabled   = dmEnabled
        s.welcomeDmMessage   = dmMessage
        s.welcomeRoleEnabled = roleEnabled
        s.welcomeRoleId      = roleId
        s.welcomeRoleName    = roleName
        let saved = (try? await services.greeting.save(s)) ?? s
        settings = saved
        isSaving = false
        toast = ToastMessage(type: .success, message: "保存しました")
    }
}

#Preview {
    NavigationStack { WelcomeMessageView() }
        .environment(\.services, ServiceContainer.live())
        .environment(AppState())
        .preferredColorScheme(.dark)
}
