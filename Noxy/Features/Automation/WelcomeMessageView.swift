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

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.md) {
                // タブ
                Picker("", selection: $selectedTab.animation()) {
                    ForEach(MessageTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.Spacing.md)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Spacing.xxl)
                } else if selectedTab == .welcome {
                    welcomeTabContent
                } else {
                    goodbyeTabContent
                }
            }
            .padding(.vertical, Theme.Spacing.md)
            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight : 0)
        }
        .scrollDismissesKeyboard(.never)
        .background(Theme.Color.bg)
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
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(currentVars, id: \.0) { label, value in
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
        case .welcomeMsg:    welcomeMessage    += v
        case .welcomeDmMsg:  welcomeDmMessage  += v
        case .goodbyeMsg:    goodbyeMessage    += v
        case .goodbyeDmMsg:  goodbyeDmMessage  += v
        case .none: break
        }
    }

    // MARK: - 入室タブ

    private var welcomeTabContent: some View {
        VStack(spacing: Theme.Spacing.md) {
            // ON/OFF
            FormSection("入室設定", icon: "arrow.right.circle") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("入室メッセージを送信する")
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Color.textPrimary)
                        Text(welcomeEnabled ? "有効" : "無効")
                            .font(Theme.Font.caption2)
                            .foregroundStyle(welcomeEnabled ? Theme.Color.statusOK : Theme.Color.textTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $welcomeEnabled.animation())
                        .tint(Theme.Color.accent)
                        .labelsHidden()
                }
                .padding(.vertical, Theme.Spacing.xs)
            }

            if welcomeEnabled {
                // チャンネル選択
                channelPickerSection(
                    id: $welcomeChannelId,
                    name: $welcomeChannelName
                )

                // チャンネルメッセージ
                FormSection("メッセージ", icon: "message") {
                    ZStack(alignment: .topLeading) {
                        if welcomeMessage.isEmpty {
                            Text("入室メッセージを入力...")
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Color.textTertiary)
                                .padding(.top, 10)
                                .padding(.leading, 14)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $welcomeMessage)
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Color.textPrimary)
                            .scrollContentBackground(.hidden)
                            .background(.clear)
                            .frame(minHeight: 80, maxHeight: 140)
                            .focused($focusedField, equals: .welcomeMsg)
                    }
                    .padding(2)
                    .background(Theme.Color.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                }

                // DM
                dmSection(
                    enabled: $welcomeDmEnabled,
                    message: $welcomeDmMessage,
                    focusValue: .welcomeDmMsg,
                    enableLabel: "新メンバーにDMを送信",
                    placeholder: "DMメッセージを入力..."
                )

                // ロール付与
                roleSection
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    // MARK: - 退室タブ

    private var goodbyeTabContent: some View {
        VStack(spacing: Theme.Spacing.md) {
            // ON/OFF
            FormSection("退室設定", icon: "arrow.left.circle") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("退室メッセージを送信する")
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Color.textPrimary)
                        Text(goodbyeEnabled ? "有効" : "無効")
                            .font(Theme.Font.caption2)
                            .foregroundStyle(goodbyeEnabled ? Theme.Color.statusOK : Theme.Color.textTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $goodbyeEnabled.animation())
                        .tint(Theme.Color.accent)
                        .labelsHidden()
                }
                .padding(.vertical, Theme.Spacing.xs)
            }

            if goodbyeEnabled {
                // チャンネル選択
                channelPickerSection(
                    id: $goodbyeChannelId,
                    name: $goodbyeChannelName
                )

                // チャンネルメッセージ
                FormSection("メッセージ", icon: "message") {
                    ZStack(alignment: .topLeading) {
                        if goodbyeMessage.isEmpty {
                            Text("退室メッセージを入力...")
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Color.textTertiary)
                                .padding(.top, 10)
                                .padding(.leading, 14)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $goodbyeMessage)
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Color.textPrimary)
                            .scrollContentBackground(.hidden)
                            .background(.clear)
                            .frame(minHeight: 80, maxHeight: 140)
                            .focused($focusedField, equals: .goodbyeMsg)
                    }
                    .padding(2)
                    .background(Theme.Color.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                }

                Text("{user.mention} は退室時には使用できません")
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)

                // DM
                dmSection(
                    enabled: $goodbyeDmEnabled,
                    message: $goodbyeDmMessage,
                    focusValue: .goodbyeDmMsg,
                    enableLabel: "退室前にDMを送信",
                    placeholder: "DMメッセージを入力..."
                )
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    // MARK: - DM セクション

    private func dmSection(
        enabled: Binding<Bool>,
        message: Binding<String>,
        focusValue: FieldFocus,
        enableLabel: String,
        placeholder: String
    ) -> some View {
        FormSection("ダイレクトメッセージ", icon: "envelope") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text(enableLabel)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Spacer()
                    if !appState.isPro {
                        Badge(text: "Pro", color: Theme.Color.statusWarn)
                    } else {
                        Toggle("", isOn: enabled.animation())
                            .tint(Theme.Color.accent)
                            .labelsHidden()
                    }
                }

                if !appState.isPro {
                    Text("Proプランで利用可能")
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                } else if enabled.wrappedValue {
                    ZStack(alignment: .topLeading) {
                        if message.wrappedValue.isEmpty {
                            Text(placeholder)
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Color.textTertiary)
                                .padding(.top, 10)
                                .padding(.leading, 14)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: message)
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Color.textPrimary)
                            .scrollContentBackground(.hidden)
                            .background(.clear)
                            .frame(minHeight: 60, maxHeight: 120)
                            .focused($focusedField, equals: focusValue)
                    }
                    .padding(2)
                    .background(Theme.Color.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                }
            }
        }
    }

    // MARK: - ロール付与セクション

    private var roleSection: some View {
        FormSection("ロール付与", icon: "person.badge.plus") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("参加時ロール付与")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Spacer()
                    if !appState.isPro {
                        Badge(text: "Pro", color: Theme.Color.statusWarn)
                    } else {
                        Toggle("", isOn: $welcomeRoleEnabled.animation())
                            .tint(Theme.Color.accent)
                            .labelsHidden()
                    }
                }

                if !appState.isPro {
                    Text("Proプランで利用可能")
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                } else if welcomeRoleEnabled {
                    rolePicker(id: $welcomeRoleId, name: $welcomeRoleName)
                    if !welcomeRoleName.isEmpty {
                        HStack(spacing: Theme.Spacing.xs) {
                            StatusDot(color: Theme.Color.statusOK)
                            Text("全参加者に @\(welcomeRoleName) を付与します")
                                .font(Theme.Font.caption2)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - UI ヘルパー

    @ViewBuilder
    private func channelPickerSection(id: Binding<String>, name: Binding<String>) -> some View {
        FormSection("送信先チャンネル", icon: "number") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if channels.isEmpty {
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
                        HStack(spacing: Theme.Spacing.xs) {
                            if id.wrappedValue.isEmpty {
                                Image(systemName: "number")
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Color.textTertiary)
                                Text("チャンネルを選択...")
                                    .font(Theme.Font.body)
                                    .foregroundStyle(Theme.Color.textTertiary)
                            } else {
                                let sel = textChs.first(where: { $0.id == id.wrappedValue })
                                Image(systemName: sel?.type == .announcement ? "megaphone" : "number")
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Color.accent)
                                Text(name.wrappedValue)
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

    @ViewBuilder
    private func rolePicker(id: Binding<String>, name: Binding<String>) -> some View {
        if roles.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
        } else {
            Picker("ロール", selection: id) {
                Text("ロールを選択").tag("")
                ForEach(roles.filter { $0.name != "@everyone" && !$0.managed }) { role in
                    Text("@\(role.name)").tag(role.id)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.Color.textSecondary)
            .onChange(of: id.wrappedValue) { _, newId in
                name.wrappedValue = roles.first(where: { $0.id == newId })?.name ?? ""
            }
        }
    }

    // MARK: - Load / Save

    private func applyGreeting(_ s: GreetingSettings) {
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
    }

    private func load() async {
        let gid = appState.selectedGuildId
        guard !gid.isEmpty else { isLoading = false; return }

        // 先読み済みキャッシュがあれば即表示
        if let cachedS: GreetingSettings = appState.guildData(.greeting, guild: gid) {
            applyGreeting(cachedS)
            if let cachedC: [Channel] = appState.guildData(.channels, guild: gid) { channels = cachedC }
            if let cachedR: [DiscordRole] = appState.guildData(.roles, guild: gid) { roles = cachedR }
            isLoading = false
        }

        async let sTask = services.greeting.fetch(guildId: gid)
        async let cTask = services.guilds.fetchChannels(guildId: gid)
        async let rTask = DiscordService().fetchRoles(guildId: gid)
        let s = (try? await sTask) ?? settings ?? GreetingSettings.defaultSettings(guildId: gid)
        applyGreeting(s)
        appState.setGuildData(s, .greeting, guild: gid)
        if let c = try? await cTask { channels = c; appState.setGuildData(c, .channels, guild: gid) }
        if let r = try? await rTask { roles = r; appState.setGuildData(r, .roles, guild: gid) }
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

#Preview("Dark") {
    NavigationStack { WelcomeMessageView() }
        .environment(\.services, ServiceContainer.live())
        .environment(AppState())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    NavigationStack { WelcomeMessageView() }
        .environment(\.services, ServiceContainer.live())
        .environment(AppState())
        .preferredColorScheme(.light)
}
