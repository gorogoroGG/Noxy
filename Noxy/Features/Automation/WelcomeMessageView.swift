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

    private let welcomeVars = ["{user.mention}", "{user.name}", "{server.name}", "{member.count}"]
    private let goodbyeVars = ["{user.name}", "{server.name}", "{member.count}"]

    @State private var welcomeEnabled = false
    @State private var welcomeChannelId = ""
    @State private var welcomeChannelName = ""
    @State private var welcomeMessage = ""
    @State private var welcomeDmEnabled = false
    @State private var welcomeDmMessage = ""
    @State private var welcomeRoleEnabled = false
    @State private var welcomeRoleId = ""
    @State private var welcomeRoleName = ""

    @State private var goodbyeEnabled = false
    @State private var goodbyeChannelId = ""
    @State private var goodbyeChannelName = ""
    @State private var goodbyeMessage = ""
    @State private var goodbyeDmEnabled = false
    @State private var goodbyeDmMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing20) {

                // ══════════════════════════════════════
                // MARK: 入室カード（緑）
                // ══════════════════════════════════════
                GreetingCard(color: Color.accentGreen) {

                    // ── カードヘッダー ──
                    GreetingCardHeader(
                        icon: "arrow.right.circle.fill",
                        title: "入室メッセージ",
                        subtitle: "新メンバーが参加したときに送信",
                        color: Color.accentGreen,
                        isEnabled: $welcomeEnabled
                    )

                    if welcomeEnabled {
                        Divider().background(Color.accentGreen.opacity(0.2))

                        // チャンネル
                        GreetingRow(label: "送信先チャンネル", icon: "number", color: Color.accentGreen) {
                            channelPicker(id: $welcomeChannelId, name: $welcomeChannelName)
                        }

                        Divider().padding(.leading, 48)

                        // メッセージ
                        GreetingRow(label: "チャンネルメッセージ", icon: "text.bubble.fill", color: Color.accentGreen) {
                            VStack(alignment: .leading, spacing: .spacing8) {
                                messageEditor(text: $welcomeMessage, placeholder: "入室メッセージを入力...", color: Color.accentGreen)
                                variableChips(for: $welcomeMessage, variables: welcomeVars, color: Color.accentGreen)
                            }
                        }

                        Divider().padding(.leading, 48)

                        // プレビュー
                        GreetingRow(label: "プレビュー", icon: "eye.fill", color: Color.accentGreen) {
                            channelPreview(
                                text: highlight(welcomeMessage, map: welcomeMap, color: Color.accentGreen),
                                gradient: LinearGradient(colors: [.accentIndigo, .accentPurple], startPoint: .topLeading, endPoint: .bottomTrailing),
                                icon: "bolt.fill"
                            )
                        }

                        Divider().padding(.leading, 48)

                        // DM
                        GreetingRow(label: "ダイレクトメッセージ", icon: "envelope.fill", color: Color.accentGreen) {
                            VStack(alignment: .leading, spacing: .spacing10) {
                                Toggle("新メンバーにDMを送信", isOn: $welcomeDmEnabled.animation())
                                    .tint(Color.accentGreen)
                                    .font(.bodySmall)

                                if welcomeDmEnabled {
                                    messageEditor(text: $welcomeDmMessage, placeholder: "DMメッセージを入力...", color: Color.accentGreen)
                                    variableChips(for: $welcomeDmMessage, variables: welcomeVars, color: Color.accentGreen)
                                    dmPreview(
                                        text: highlight(welcomeDmMessage, map: welcomeMap, color: Color.accentGreen),
                                        gradient: LinearGradient(colors: [.accentIndigo, .accentPurple], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        icon: "bolt.fill",
                                        accentColor: Color.accentGreen
                                    )
                                }
                            }
                        }

                        Divider().padding(.leading, 48)

                        // ロール付与
                        GreetingRow(label: "参加時ロール付与", icon: "person.badge.plus.fill", color: Color.accentGreen) {
                            VStack(alignment: .leading, spacing: .spacing10) {
                                Toggle("参加時にロールを付与", isOn: $welcomeRoleEnabled.animation())
                                    .tint(Color.accentGreen)
                                    .font(.bodySmall)

                                if welcomeRoleEnabled {
                                    rolePicker(id: $welcomeRoleId, name: $welcomeRoleName)
                                    if !welcomeRoleName.isEmpty {
                                        Label("全参加者に @\(welcomeRoleName) を付与します", systemImage: "checkmark.circle.fill")
                                            .font(.captionSmall)
                                            .foregroundStyle(Color.accentGreen)
                                    }
                                }
                            }
                        }
                    }
                }

                // ══════════════════════════════════════
                // MARK: 退室カード（ピンク）
                // ══════════════════════════════════════
                GreetingCard(color: Color.accentPink) {

                    GreetingCardHeader(
                        icon: "arrow.left.circle.fill",
                        title: "退室メッセージ",
                        subtitle: "メンバーが退室したときに送信",
                        color: Color.accentPink,
                        isEnabled: $goodbyeEnabled
                    )

                    if goodbyeEnabled {
                        Divider().background(Color.accentPink.opacity(0.2))

                        GreetingRow(label: "送信先チャンネル", icon: "number", color: Color.accentPink) {
                            channelPicker(id: $goodbyeChannelId, name: $goodbyeChannelName)
                        }

                        Divider().padding(.leading, 48)

                        GreetingRow(label: "チャンネルメッセージ", icon: "text.bubble.fill", color: Color.accentPink) {
                            VStack(alignment: .leading, spacing: .spacing8) {
                                messageEditor(text: $goodbyeMessage, placeholder: "退室メッセージを入力...", color: Color.accentPink)
                                variableChips(for: $goodbyeMessage, variables: goodbyeVars, color: Color.accentPink)
                                Text("{user.mention} は退室時には使用できません")
                                    .font(.captionSmall)
                                    .foregroundStyle(Color.textTertiary)
                            }
                        }

                        Divider().padding(.leading, 48)

                        GreetingRow(label: "プレビュー", icon: "eye.fill", color: Color.accentPink) {
                            channelPreview(
                                text: highlight(goodbyeMessage, map: goodbyeMap, color: Color.accentPink),
                                gradient: LinearGradient(colors: [.accentPink, .accentPurple], startPoint: .topLeading, endPoint: .bottomTrailing),
                                icon: "hand.wave.fill"
                            )
                        }

                        Divider().padding(.leading, 48)

                        GreetingRow(label: "ダイレクトメッセージ", icon: "envelope.fill", color: Color.accentPink) {
                            VStack(alignment: .leading, spacing: .spacing10) {
                                Toggle("退室前にDMを送信", isOn: $goodbyeDmEnabled.animation())
                                    .tint(Color.accentPink)
                                    .font(.bodySmall)

                                if goodbyeDmEnabled {
                                    messageEditor(text: $goodbyeDmMessage, placeholder: "DMメッセージを入力...", color: Color.accentPink)
                                    variableChips(for: $goodbyeDmMessage, variables: goodbyeVars, color: Color.accentPink)
                                    dmPreview(
                                        text: highlight(goodbyeDmMessage, map: goodbyeMap, color: Color.accentPink),
                                        gradient: LinearGradient(colors: [.accentPink, .accentPurple], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        icon: "hand.wave.fill",
                                        accentColor: Color.accentPink
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, .spacing16)
            .padding(.vertical, .spacing20)
        }
        .background(Color(.systemGroupedBackground))
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

    // MARK: - プレビューマップ

    private var welcomeMap: [(String, String)] {[
        ("{user.mention}", "@NewMember"),
        ("{user.name}",    "NewMember"),
        ("{server.name}",  appState.selectedGuild?.name ?? "サーバー"),
        ("{member.count}", "1,234"),
    ]}
    private var goodbyeMap: [(String, String)] {[
        ("{user.name}",    "OldMember"),
        ("{server.name}",  appState.selectedGuild?.name ?? "サーバー"),
        ("{member.count}", "1,233"),
    ]}

    // MARK: - UI 部品

    @ViewBuilder
    private func channelPicker(id: Binding<String>, name: Binding<String>) -> some View {
        if channels.isEmpty {
            ProgressView().frame(maxWidth: .infinity)
        } else {
            Picker("チャンネル", selection: id) {
                Text("チャンネルを選択").tag("")
                ForEach(channels.filter { $0.type == .text || $0.type == .announcement }) { ch in
                    Label("#\(ch.name)", systemImage: ch.type == .announcement ? "megaphone" : "number").tag(ch.id)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: id.wrappedValue) { _, newId in
                name.wrappedValue = channels.first(where: { $0.id == newId })?.name ?? ""
            }
        }
    }

    @ViewBuilder
    private func rolePicker(id: Binding<String>, name: Binding<String>) -> some View {
        if roles.isEmpty {
            ProgressView().frame(maxWidth: .infinity)
        } else {
            Picker("ロール", selection: id) {
                Text("ロールを選択").tag("")
                ForEach(roles.filter { $0.name != "@everyone" && !$0.managed }) { role in
                    Text("@\(role.name)").tag(role.id)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: id.wrappedValue) { _, newId in
                name.wrappedValue = roles.first(where: { $0.id == newId })?.name ?? ""
            }
        }
    }

    @ViewBuilder
    private func messageEditor(text: Binding<String>, placeholder: String, color: Color) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder).foregroundStyle(Color.textTertiary).font(.bodySmall)
                    .padding(.top, 8).padding(.leading, 4).allowsHitTesting(false)
            }
            TextEditor(text: text)
                .font(.bodySmall).frame(minHeight: 64)
                .scrollContentBackground(.hidden)
                .tint(color)
        }
        .padding(10)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color.opacity(0.2), lineWidth: 1))
    }

    private func variableChips(for text: Binding<String>, variables: [String], color: Color) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .spacing6) {
                Text("変数:").font(.captionSmall).foregroundStyle(Color.textTertiary)
                ForEach(variables, id: \.self) { v in
                    Button { text.wrappedValue += v } label: {
                        Text(v).font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(color)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(color.opacity(0.12)).clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func channelPreview(text: AttributedString, gradient: LinearGradient, icon: String) -> some View {
        HStack(alignment: .top, spacing: .spacing10) {
            ZStack {
                Circle().fill(gradient).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Noxy").font(.captionRegular).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                    Text("BOT").font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 2).background(Color.accentIndigo)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Text(text).font(.captionRegular).foregroundStyle(Color.textPrimary)
            }
        }
        .padding(.spacing10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func dmPreview(text: AttributedString, gradient: LinearGradient, icon: String, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: .spacing6) {
            HStack(spacing: 5) {
                Image(systemName: "envelope.fill").font(.system(size: 10)).foregroundStyle(accentColor)
                Text("DMプレビュー").font(.system(size: 10, weight: .medium)).foregroundStyle(accentColor)
            }
            HStack(alignment: .top, spacing: .spacing10) {
                ZStack {
                    Circle().fill(gradient).frame(width: 28, height: 28)
                    Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Noxy").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.textPrimary)
                    Text(text).font(.system(size: 11)).foregroundStyle(Color.textPrimary)
                }
                .padding(.horizontal, .spacing10).padding(.vertical, .spacing8)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - 変数ハイライト

    private func highlight(_ raw: String, map: [(String, String)], color: Color) -> AttributedString {
        var result = AttributedString()
        var remaining = raw
        while !remaining.isEmpty {
            var matched = false
            for (variable, replacement) in map {
                if remaining.hasPrefix(variable) {
                    var chunk = AttributedString(replacement)
                    chunk.foregroundColor = UIColor(color)
                    chunk.font = UIFont.boldSystemFont(ofSize: UIFont.systemFontSize * 0.85)
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
        welcomeEnabled = s.welcomeEnabled; welcomeChannelId = s.welcomeChannelId
        welcomeChannelName = s.welcomeChannelName; welcomeMessage = s.welcomeMessage
        welcomeDmEnabled = s.welcomeDmEnabled; welcomeDmMessage = s.welcomeDmMessage
        welcomeRoleEnabled = s.welcomeRoleEnabled; welcomeRoleId = s.welcomeRoleId
        welcomeRoleName = s.welcomeRoleName
        goodbyeEnabled = s.goodbyeEnabled; goodbyeChannelId = s.goodbyeChannelId
        goodbyeChannelName = s.goodbyeChannelName; goodbyeMessage = s.goodbyeMessage
        goodbyeDmEnabled = s.goodbyeDmEnabled; goodbyeDmMessage = s.goodbyeDmMessage
        settings = s; isLoading = false
    }

    private func save() async {
        isSaving = true
        var s = settings ?? GreetingSettings.defaultSettings(guildId: appState.selectedGuildId)
        s.welcomeEnabled = welcomeEnabled; s.welcomeChannelId = welcomeChannelId
        s.welcomeChannelName = welcomeChannelName; s.welcomeMessage = welcomeMessage
        s.welcomeDmEnabled = welcomeDmEnabled; s.welcomeDmMessage = welcomeDmMessage
        s.welcomeRoleEnabled = welcomeRoleEnabled; s.welcomeRoleId = welcomeRoleId
        s.welcomeRoleName = welcomeRoleName
        s.goodbyeEnabled = goodbyeEnabled; s.goodbyeChannelId = goodbyeChannelId
        s.goodbyeChannelName = goodbyeChannelName; s.goodbyeMessage = goodbyeMessage
        s.goodbyeDmEnabled = goodbyeDmEnabled; s.goodbyeDmMessage = goodbyeDmMessage
        let saved = (try? await services.greeting.save(s)) ?? s
        settings = saved; isSaving = false
        toast = ToastMessage(type: .success, message: "保存しました")
    }
}

// MARK: - カード外枠

private struct GreetingCard<Content: View>: View {
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(color.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: color.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// MARK: - カードヘッダー（トグル付き）

private struct GreetingCardHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: .spacing12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.bodyRegular).fontWeight(.bold)
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()
            Toggle("", isOn: $isEnabled.animation())
                .tint(color)
                .labelsHidden()
        }
        .padding(.spacing16)
        .background(color.opacity(0.06))
    }
}

// MARK: - 各行

private struct GreetingRow<Content: View>: View {
    let label: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: .spacing12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: .spacing8) {
                Text(label)
                    .font(.captionSmall).fontWeight(.semibold)
                    .foregroundStyle(Color.textTertiary)
                    .textCase(.uppercase)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, .spacing16)
        .padding(.vertical, .spacing12)
    }
}

#Preview {
    NavigationStack { WelcomeMessageView() }
        .environment(\.services, ServiceContainer.live())
        .environment(AppState())
        .preferredColorScheme(.dark)
}
