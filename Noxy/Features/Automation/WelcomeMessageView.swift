import SwiftUI

// MARK: - WelcomeMessageView

struct WelcomeMessageView: View {
    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState

    enum MessageTab: String, CaseIterable {
        case welcome = "入室"
        case goodbye = "退室"
    }

    enum FieldFocus: Hashable {
        case welcomeMsg, welcomeDmMsg, goodbyeMsg, goodbyeDmMsg
    }

    @State private var selectedTab: MessageTab = .welcome
    @FocusState private var focusedField: FieldFocus?

    @State private var settings: GreetingSettings? = nil
    @State private var channels: [Channel] = []
    @State private var roles: [DiscordRole] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var toast: ToastMessage? = nil
    @State private var keyboardHeight: CGFloat = 0

    // 入室
    @State private var welcomeEnabled     = false
    @State private var welcomeChannelId   = ""
    @State private var welcomeChannelName = ""
    @State private var welcomeMessage     = ""
    @State private var welcomeDmEnabled   = false
    @State private var welcomeDmMessage   = ""
    @State private var welcomeRoleEnabled = false
    @State private var welcomeRoleId      = ""
    @State private var welcomeRoleName    = ""

    // 退室
    @State private var goodbyeEnabled     = false
    @State private var goodbyeChannelId   = ""
    @State private var goodbyeChannelName = ""
    @State private var goodbyeMessage     = ""
    @State private var goodbyeDmEnabled   = false
    @State private var goodbyeDmMessage   = ""

    private let welcomeVars = [
        ("{user.mention}", "{user.mention}"),
        ("{user.name}",    "{user.name}"),
        ("{server.name}",  "{server.name}"),
        ("{member.count}", "{member.count}"),
    ]
    private let goodbyeVars = [
        ("{user.name}",    "{user.name}"),
        ("{server.name}",  "{server.name}"),
        ("{member.count}", "{member.count}"),
    ]

    private var currentVars: [(String, String)] {
        switch focusedField {
        case .welcomeMsg, .welcomeDmMsg, .none: welcomeVars
        case .goodbyeMsg, .goodbyeDmMsg:        goodbyeVars
        }
    }

    private var welcomeGradient: LinearGradient {
        LinearGradient(colors: [.accentGreen, .accentIndigo], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    private var goodbyeGradient: LinearGradient {
        LinearGradient(colors: [.accentPink, .accentPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: .spacing16) {
                // タブ
                Picker("", selection: $selectedTab.animation()) {
                    ForEach(MessageTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, .spacing16)

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if selectedTab == .welcome {
                    welcomeTabContent
                } else {
                    goodbyeTabContent
                }
            }
            .padding(.vertical, .spacing16)
            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight : 0)
        }
        .scrollDismissesKeyboard(.never)
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

    // MARK: - Keyboard Toolbar

    @ToolbarContentBuilder
    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: .spacing6) {
                    ForEach(currentVars, id: \.0) { label, value in
                        Button {
                            insertVariable(value)
                        } label: {
                            Text(label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(selectedTab == .welcome ? Color.accentGreen : Color.accentPink)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(
                                    (selectedTab == .welcome ? Color.accentGreen : Color.accentPink).opacity(0.1)
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 34)
            .clipped()

            Button("完了") { focusedField = nil }
                .font(.captionRegular).fontWeight(.semibold)
                .foregroundStyle(selectedTab == .welcome ? Color.accentGreen : Color.accentPink)
                .padding(.leading, .spacing8)
        }
    }

    private func insertVariable(_ v: String) {
        switch focusedField {
        case .welcomeMsg:    welcomeMessage    += v
        case .welcomeDmMsg:  welcomeDmMessage  += v
        case .goodbyeMsg:    goodbyeMessage    += v
        case .goodbyeDmMsg:  goodbyeDmMessage  += v
        case .none: break
        }
    }

    // MARK: - 入室タブ

    private var welcomeTabContent: some View {
        VStack(spacing: .spacing16) {
            // ON/OFF
            Card {
                HStack {
                    Label("入室メッセージを送信する", systemImage: "arrow.right.circle.fill")
                        .font(.bodySmall).fontWeight(.semibold)
                        .foregroundStyle(Color.accentGreen)
                    Spacer()
                    Toggle("", isOn: $welcomeEnabled.animation())
                        .tint(Color.accentGreen)
                        .labelsHidden()
                }
            }

            if welcomeEnabled {
                // チャンネル選択
                channelPickerCard(
                    id: $welcomeChannelId,
                    name: $welcomeChannelName,
                    accentColor: Color.accentGreen
                )

                // チャンネルメッセージ
                inlineMessageEditor(
                    text: $welcomeMessage,
                    placeholder: "入室メッセージを入力...",
                    focusValue: .welcomeMsg,
                    accentColor: Color.accentGreen,
                    gradient: welcomeGradient,
                    botIcon: "bolt.fill"
                )

                // DM
                dmSection(
                    enabled: $welcomeDmEnabled,
                    message: $welcomeDmMessage,
                    focusValue: .welcomeDmMsg,
                    enableLabel: "新メンバーにDMを送信",
                    placeholder: "DMメッセージを入力...",
                    accentColor: Color.accentGreen,
                    gradient: welcomeGradient,
                    botIcon: "bolt.fill"
                )

                // ロール付与
                roleSection
            }
        }
        .padding(.horizontal, .spacing16)
    }

    // MARK: - 退室タブ

    private var goodbyeTabContent: some View {
        VStack(spacing: .spacing16) {
            // ON/OFF
            Card {
                HStack {
                    Label("退室メッセージを送信する", systemImage: "arrow.left.circle.fill")
                        .font(.bodySmall).fontWeight(.semibold)
                        .foregroundStyle(Color.accentPink)
                    Spacer()
                    Toggle("", isOn: $goodbyeEnabled.animation())
                        .tint(Color.accentPink)
                        .labelsHidden()
                }
            }

            if goodbyeEnabled {
                // チャンネル選択
                channelPickerCard(
                    id: $goodbyeChannelId,
                    name: $goodbyeChannelName,
                    accentColor: Color.accentPink
                )

                // チャンネルメッセージ
                inlineMessageEditor(
                    text: $goodbyeMessage,
                    placeholder: "退室メッセージを入力...",
                    focusValue: .goodbyeMsg,
                    accentColor: Color.accentPink,
                    gradient: goodbyeGradient,
                    botIcon: "hand.wave.fill"
                )

                Text("{user.mention} は退室時には使用できません")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, .spacing4)

                // DM
                dmSection(
                    enabled: $goodbyeDmEnabled,
                    message: $goodbyeDmMessage,
                    focusValue: .goodbyeDmMsg,
                    enableLabel: "退室前にDMを送信",
                    placeholder: "DMメッセージを入力...",
                    accentColor: Color.accentPink,
                    gradient: goodbyeGradient,
                    botIcon: "hand.wave.fill"
                )
            }
        }
        .padding(.horizontal, .spacing16)
    }

    // MARK: - インラインメッセージエディタ

    private func inlineMessageEditor(
        text: Binding<String>,
        placeholder: String,
        focusValue: FieldFocus,
        accentColor: Color,
        gradient: LinearGradient,
        botIcon: String
    ) -> some View {
        HStack(alignment: .top, spacing: .spacing12) {
            ZStack {
                Circle().fill(gradient).frame(width: 40, height: 40)
                Image(systemName: botIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: .spacing4) {
                HStack(spacing: .spacing6) {
                    Text("Noxy")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accentColor)
                    Text("BOT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.accentIndigo)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    (Text("今日 ") + Text(Date(), style: .time))
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                    Spacer()
                }

                ZStack(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textTertiary)
                            .padding(.top, 8).padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: text)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .frame(minHeight: 56, maxHeight: 140)
                        .focused($focusedField, equals: focusValue)
                }
                .padding(2)
                .embedDashedBorder(focused: focusedField == focusValue)
            }
        }
        .padding(.spacing12)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - DM セクション

    private func dmSection(
        enabled: Binding<Bool>,
        message: Binding<String>,
        focusValue: FieldFocus,
        enableLabel: String,
        placeholder: String,
        accentColor: Color,
        gradient: LinearGradient,
        botIcon: String
    ) -> some View {
        Card {
            VStack(alignment: .leading, spacing: .spacing12) {
                HStack {
                    Label(enableLabel, systemImage: "envelope.fill")
                        .font(.bodySmall).fontWeight(.semibold)
                        .foregroundStyle(accentColor)
                    Spacer()
                    if !appState.isPro {
                        Badge(text: "Pro", color: .accentOrange)
                    } else {
                        Toggle("", isOn: enabled.animation())
                            .tint(accentColor)
                            .labelsHidden()
                    }
                }

                if !appState.isPro {
                    Text("Proプランで利用可能")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                } else if enabled.wrappedValue {
                    // DM インライン編集
                    HStack(alignment: .top, spacing: .spacing10) {
                        ZStack {
                            Circle().fill(gradient).frame(width: 32, height: 32)
                            Image(systemName: botIcon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: .spacing4) {
                            Text("Noxy")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(accentColor)

                            ZStack(alignment: .topLeading) {
                                if message.wrappedValue.isEmpty {
                                    Text(placeholder)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.textTertiary)
                                        .padding(.top, 6).padding(.leading, 4)
                                        .allowsHitTesting(false)
                                }
                                TextEditor(text: message)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .background(.clear)
                                    .frame(minHeight: 48, maxHeight: 120)
                                    .focused($focusedField, equals: focusValue)
                            }
                            .padding(.horizontal, .spacing10).padding(.vertical, .spacing8)
                            .background(Color.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }

    // MARK: - ロール付与セクション

    private var roleSection: some View {
        Card {
            VStack(alignment: .leading, spacing: .spacing12) {
                HStack {
                    Label("参加時ロール付与", systemImage: "person.badge.plus.fill")
                        .font(.bodySmall).fontWeight(.semibold)
                        .foregroundStyle(Color.accentGreen)
                    Spacer()
                    if !appState.isPro {
                        Badge(text: "Pro", color: .accentOrange)
                    } else {
                        Toggle("", isOn: $welcomeRoleEnabled.animation())
                            .tint(Color.accentGreen)
                            .labelsHidden()
                    }
                }

                if !appState.isPro {
                    Text("Proプランで利用可能")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                } else if welcomeRoleEnabled {
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

    // MARK: - UI ヘルパー

    @ViewBuilder
    private func channelPickerCard(id: Binding<String>, name: Binding<String>, accentColor: Color) -> some View {
        Card {
            VStack(alignment: .leading, spacing: .spacing10) {
                Text("送信先チャンネル")
                    .font(.captionSmall).fontWeight(.semibold)
                    .foregroundStyle(Color.textTertiary).textCase(.uppercase)

                if channels.isEmpty {
                    HStack(spacing: .spacing8) {
                        ProgressView().scaleEffect(0.7)
                        Text("読み込み中...").font(.captionSmall).foregroundStyle(Color.textTertiary)
                    }
                    .padding(.horizontal, .spacing12).padding(.vertical, .spacing10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.bgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    let textChs = channels.filter { $0.type == .text || $0.type == .announcement }
                    Menu {
                        if !id.wrappedValue.isEmpty {
                            Button(role: .destructive) {
                                id.wrappedValue = ""
                                name.wrappedValue = ""
                            } label: { Label("選択を解除", systemImage: "xmark") }
                            Divider()
                        }
                        ForEach(textChs) { ch in
                            Button {
                                id.wrappedValue = ch.id
                                name.wrappedValue = ch.name
                            } label: {
                                Label(ch.name, systemImage: ch.type == .announcement ? "megaphone" : "number")
                            }
                        }
                    } label: {
                        HStack(spacing: .spacing8) {
                            if id.wrappedValue.isEmpty {
                                Image(systemName: "number")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.textTertiary)
                                Text("チャンネルを選択...")
                                    .font(.bodySmall)
                                    .foregroundStyle(Color.textTertiary)
                            } else {
                                let sel = textChs.first(where: { $0.id == id.wrappedValue })
                                Image(systemName: sel?.type == .announcement ? "megaphone" : "number")
                                    .font(.system(size: 13))
                                    .foregroundStyle(accentColor)
                                Text(name.wrappedValue)
                                    .font(.bodySmall).fontWeight(.medium)
                                    .foregroundStyle(Color.textPrimary)
                            }
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(.horizontal, .spacing12).padding(.vertical, .spacing10)
                        .background(Color.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
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
            .tint(Color.textSecondary)
            .onChange(of: id.wrappedValue) { _, newId in
                name.wrappedValue = roles.first(where: { $0.id == newId })?.name ?? ""
            }
        }
    }

    // MARK: - Load / Save

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
        settings = s
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
}
