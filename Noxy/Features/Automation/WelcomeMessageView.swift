import SwiftUI

// MARK: - 入退室メッセージ統合ビュー

struct WelcomeMessageView: View {
    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState

    @State private var settings: GreetingSettings? = nil
    @State private var channels: [Channel] = []
    @State private var roles: [DiscordRole] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var toast: ToastMessage? = nil

    private let welcomeVariables = ["{user.mention}", "{user.name}", "{server.name}", "{member.count}"]
    private let goodbyeVariables = ["{user.name}", "{server.name}", "{member.count}"]

    // ── 入室ステート ─────────────────────────────────────────
    @State private var welcomeEnabled = false
    @State private var welcomeChannelId = ""
    @State private var welcomeChannelName = ""
    @State private var welcomeMessage = ""
    @State private var welcomeDmEnabled = false
    @State private var welcomeDmMessage = ""
    @State private var welcomeRoleEnabled = false
    @State private var welcomeRoleId = ""
    @State private var welcomeRoleName = ""

    // ── 退室ステート ─────────────────────────────────────────
    @State private var goodbyeEnabled = false
    @State private var goodbyeChannelId = ""
    @State private var goodbyeChannelName = ""
    @State private var goodbyeMessage = ""
    @State private var goodbyeDmEnabled = false
    @State private var goodbyeDmMessage = ""

    var body: some View {
        List {

            // ══════════════════════════════════════════════════
            // MARK: 入室メッセージ
            // ══════════════════════════════════════════════════

            Section {
                HStack(spacing: .spacing10) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(Color.accentGreen)
                    Text("入室メッセージ")
                        .font(.bodyRegular).fontWeight(.semibold)
                    Spacer()
                    Toggle("", isOn: $welcomeEnabled.animation())
                        .tint(Color.accentGreen)
                        .labelsHidden()
                }
            }

            if welcomeEnabled {
                // 送信先チャンネル
                Section {
                    channelPicker(id: $welcomeChannelId, name: $welcomeChannelName)
                } header: { Text("送信先チャンネル") }
                  footer: { Text("新メンバーが参加したときにメッセージを送るチャンネルです。") }

                // チャンネルメッセージ
                Section {
                    messageEditor(text: $welcomeMessage, placeholder: "入室メッセージを入力...")
                    variableChips(for: $welcomeMessage, variables: welcomeVariables, color: .accentGreen)
                } header: { Text("チャンネルメッセージ") }

                // チャンネルプレビュー
                Section {
                    channelPreview(
                        text: highlight(welcomeMessage, variables: welcomeVariables,
                                        replacements: welcomeReplacements, color: .accentGreen),
                        gradient: LinearGradient(colors: [.accentIndigo, .accentPurple],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing),
                        icon: "bolt.fill"
                    )
                } header: { Text("プレビュー") }

                // DM
                Section {
                    Toggle("新メンバーにDMを送信", isOn: $welcomeDmEnabled.animation())
                        .tint(Color.accentGreen)
                    if welcomeDmEnabled {
                        messageEditor(text: $welcomeDmMessage, placeholder: "DMメッセージを入力...")
                        variableChips(for: $welcomeDmMessage, variables: welcomeVariables, color: .accentGreen)
                    }
                } header: { Text("ダイレクトメッセージ") }
                  footer: { welcomeDmEnabled ? Text("{user.mention} はDMでは使用できません。") : nil }

                if welcomeDmEnabled {
                    Section {
                        dmPreview(
                            text: highlight(welcomeDmMessage, variables: welcomeVariables,
                                            replacements: welcomeReplacements, color: .accentGreen),
                            gradient: LinearGradient(colors: [.accentIndigo, .accentPurple],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing),
                            icon: "bolt.fill",
                            accentColor: .accentGreen
                        )
                    } header: { Text("DM プレビュー") }
                }

                // ロール付与（入室のみ）
                Section {
                    Toggle("参加時にロールを付与", isOn: $welcomeRoleEnabled.animation())
                        .tint(Color.accentGreen)
                    if welcomeRoleEnabled {
                        rolePicker(id: $welcomeRoleId, name: $welcomeRoleName)
                    }
                } header: { Text("参加時ロール付与") }
                  footer: {
                      welcomeRoleEnabled && !welcomeRoleName.isEmpty
                        ? Text("参加した全メンバーに @\(welcomeRoleName) を自動で付与します。")
                        : nil
                  }
            }

            // ══════════════════════════════════════════════════
            // MARK: 退室メッセージ
            // ══════════════════════════════════════════════════

            Section {
                HStack(spacing: .spacing10) {
                    Image(systemName: "arrow.left.circle.fill")
                        .foregroundStyle(Color.accentPink)
                    Text("退室メッセージ")
                        .font(.bodyRegular).fontWeight(.semibold)
                    Spacer()
                    Toggle("", isOn: $goodbyeEnabled.animation())
                        .tint(Color.accentPink)
                        .labelsHidden()
                }
            }

            if goodbyeEnabled {
                // 送信先チャンネル
                Section {
                    channelPicker(id: $goodbyeChannelId, name: $goodbyeChannelName)
                } header: { Text("送信先チャンネル") }
                  footer: { Text("メンバーが退室したときにメッセージを送るチャンネルです。") }

                // チャンネルメッセージ
                Section {
                    messageEditor(text: $goodbyeMessage, placeholder: "退室メッセージを入力...")
                    variableChips(for: $goodbyeMessage, variables: goodbyeVariables, color: .accentPink)
                } header: { Text("チャンネルメッセージ") }
                  footer: { Text("退室時は {user.mention} は使用できません。") }

                // チャンネルプレビュー
                Section {
                    channelPreview(
                        text: highlight(goodbyeMessage, variables: goodbyeVariables,
                                        replacements: goodbyeReplacements, color: .accentPink),
                        gradient: LinearGradient(colors: [.accentPink, .accentPurple],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing),
                        icon: "hand.wave.fill"
                    )
                } header: { Text("プレビュー") }

                // DM
                Section {
                    Toggle("退室前にDMを送信", isOn: $goodbyeDmEnabled.animation())
                        .tint(Color.accentPink)
                    if goodbyeDmEnabled {
                        messageEditor(text: $goodbyeDmMessage, placeholder: "DMメッセージを入力...")
                        variableChips(for: $goodbyeDmMessage, variables: goodbyeVariables, color: .accentPink)
                    }
                } header: { Text("ダイレクトメッセージ") }
                  footer: { goodbyeDmEnabled ? Text("退室処理前に本人へDMで送信されます。") : nil }

                if goodbyeDmEnabled {
                    Section {
                        dmPreview(
                            text: highlight(goodbyeDmMessage, variables: goodbyeVariables,
                                            replacements: goodbyeReplacements, color: .accentPink),
                            gradient: LinearGradient(colors: [.accentPink, .accentPurple],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing),
                            icon: "hand.wave.fill",
                            accentColor: .accentPink
                        )
                    } header: { Text("DM プレビュー") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("入退室メッセージ")
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

    // MARK: - プレビュー用変数マッピング

    private var welcomeReplacements: [(String, String)] {[
        ("{user.mention}", "@NewMember"),
        ("{user.name}",    "NewMember"),
        ("{server.name}",  appState.selectedGuild?.name ?? "サーバー"),
        ("{member.count}", "1,234"),
    ]}

    private var goodbyeReplacements: [(String, String)] {[
        ("{user.name}",    "OldMember"),
        ("{server.name}",  appState.selectedGuild?.name ?? "サーバー"),
        ("{member.count}", "1,233"),
    ]}

    // MARK: - 共通UI部品

    @ViewBuilder
    private func channelPicker(id: Binding<String>, name: Binding<String>) -> some View {
        if channels.isEmpty {
            ProgressView("チャンネルを読み込み中...").frame(maxWidth: .infinity)
        } else {
            Picker("チャンネル", selection: id) {
                Text("チャンネルを選択").tag("")
                ForEach(channels.filter { $0.type == .text || $0.type == .announcement }) { ch in
                    Label("#\(ch.name)", systemImage: ch.type == .announcement ? "megaphone" : "number")
                        .tag(ch.id)
                }
            }
            .onChange(of: id.wrappedValue) { newId in
                name.wrappedValue = channels.first(where: { $0.id == newId })?.name ?? ""
            }
        }
    }

    @ViewBuilder
    private func rolePicker(id: Binding<String>, name: Binding<String>) -> some View {
        if roles.isEmpty {
            ProgressView("ロールを読み込み中...").frame(maxWidth: .infinity)
        } else {
            Picker("付与するロール", selection: id) {
                Text("ロールを選択").tag("")
                ForEach(roles.filter { $0.name != "@everyone" && !$0.managed }) { role in
                    Text("@\(role.name)").tag(role.id)
                }
            }
            .onChange(of: id.wrappedValue) { newId in
                name.wrappedValue = roles.first(where: { $0.id == newId })?.name ?? ""
            }
        }
    }

    @ViewBuilder
    private func messageEditor(text: Binding<String>, placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .foregroundStyle(Color.textTertiary).font(.bodyRegular)
                    .padding(.top, 8).padding(.leading, 4)
                    .allowsHitTesting(false)
            }
            TextEditor(text: text)
                .font(.bodyRegular).frame(minHeight: 72)
                .scrollContentBackground(.hidden)
        }
    }

    private func variableChips(for text: Binding<String>, variables: [String], color: Color) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .spacing8) {
                ForEach(variables, id: \.self) { v in
                    Button { text.wrappedValue += v } label: {
                        Text(v)
                            .font(.caption).fontWeight(.medium)
                            .foregroundStyle(color)
                            .padding(.horizontal, .spacing8).padding(.vertical, 4)
                            .background(color.opacity(0.12)).clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }.padding(.vertical, 2)
        }
    }

    private func channelPreview(text: AttributedString, gradient: LinearGradient, icon: String) -> some View {
        HStack(alignment: .top, spacing: .spacing12) {
            ZStack {
                Circle().fill(gradient).frame(width: 36, height: 36)
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: .spacing6) {
                    Text("Noxy").font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                    Text("BOT").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(Color.accentIndigo).clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Text(text).font(.bodySmall).foregroundStyle(Color.textPrimary)
            }
        }.padding(.vertical, .spacing4)
    }

    private func dmPreview(text: AttributedString, gradient: LinearGradient, icon: String, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            HStack(spacing: .spacing6) {
                Image(systemName: "envelope.fill").font(.captionSmall).foregroundStyle(accentColor)
                Text("ダイレクトメッセージ").font(.captionSmall).foregroundStyle(accentColor)
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
                .background(Color.bgElevated).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }.padding(.vertical, .spacing4)
    }

    // MARK: - 変数ハイライト

    private func highlight(_ raw: String, variables: [String], replacements: [(String, String)], color: Color) -> AttributedString {
        var result = AttributedString()
        var remaining = raw
        while !remaining.isEmpty {
            var matched = false
            for (variable, replacement) in replacements {
                if remaining.hasPrefix(variable) {
                    var chunk = AttributedString(replacement)
                    chunk.foregroundColor = UIColor(color)
                    chunk.font = UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)
                    result.append(chunk)
                    remaining = String(remaining.dropFirst(variable.count))
                    matched = true; break
                }
            }
            if !matched { result.append(AttributedString(String(remaining.removeFirst()))) }
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

        welcomeEnabled     = s.welcomeEnabled
        welcomeChannelId   = s.welcomeChannelId
        welcomeChannelName = s.welcomeChannelName
        welcomeMessage     = s.welcomeMessage
        welcomeDmEnabled   = s.welcomeDmEnabled
        welcomeDmMessage   = s.welcomeDmMessage
        welcomeRoleEnabled = s.welcomeRoleEnabled
        welcomeRoleId      = s.welcomeRoleId
        welcomeRoleName    = s.welcomeRoleName

        goodbyeEnabled     = s.goodbyeEnabled
        goodbyeChannelId   = s.goodbyeChannelId
        goodbyeChannelName = s.goodbyeChannelName
        goodbyeMessage     = s.goodbyeMessage
        goodbyeDmEnabled   = s.goodbyeDmEnabled
        goodbyeDmMessage   = s.goodbyeDmMessage

        settings  = s
        isLoading = false
    }

    private func save() async {
        isSaving = true
        var s = settings ?? GreetingSettings.defaultSettings(guildId: appState.selectedGuildId)
        s.welcomeEnabled     = welcomeEnabled
        s.welcomeChannelId   = welcomeChannelId
        s.welcomeChannelName = welcomeChannelName
        s.welcomeMessage     = welcomeMessage
        s.welcomeDmEnabled   = welcomeDmEnabled
        s.welcomeDmMessage   = welcomeDmMessage
        s.welcomeRoleEnabled = welcomeRoleEnabled
        s.welcomeRoleId      = welcomeRoleId
        s.welcomeRoleName    = welcomeRoleName
        s.goodbyeEnabled     = goodbyeEnabled
        s.goodbyeChannelId   = goodbyeChannelId
        s.goodbyeChannelName = goodbyeChannelName
        s.goodbyeMessage     = goodbyeMessage
        s.goodbyeDmEnabled   = goodbyeDmEnabled
        s.goodbyeDmMessage   = goodbyeDmMessage
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
