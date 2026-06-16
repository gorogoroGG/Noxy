import SwiftUI

struct GoodbyeMessageView: View {
    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState

    @State private var settings: GreetingSettings? = nil
    @State private var channels: [Channel] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var toast: ToastMessage? = nil

    private let variables = ["{user.name}", "{server.name}", "{member.count}"]

    @State private var enabled = false
    @State private var channelId = ""
    @State private var channelName = ""
    @State private var message = ""
    @State private var dmEnabled = false
    @State private var dmMessage = ""

    @FocusState private var focusedField: FieldFocus?

    enum FieldFocus: Hashable {
        case message, dmMessage
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.md) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Spacing.xxl)
                } else {
                    // ON/OFF
                    FormSection("退室設定", icon: "arrow.left.circle") {
                        HStack {
                            Text("退室メッセージを有効にする")
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Color.textPrimary)
                            Spacer()
                            Toggle("", isOn: $enabled.animation())
                                .tint(Theme.Color.accent)
                                .labelsHidden()
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                    }

                    if enabled {
                        // チャンネル選択
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
                                        if !channelId.isEmpty {
                                            Button(role: .destructive) {
                                                channelId = ""
                                                channelName = ""
                                            } label: { Label("選択を解除", systemImage: "xmark") }
                                            Divider()
                                        }
                                        ForEach(textChs) { ch in
                                            Button {
                                                channelId = ch.id
                                                channelName = ch.name
                                            } label: {
                                                Label(ch.name, systemImage: ch.type == .announcement ? "megaphone" : "number")
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: Theme.Spacing.xs) {
                                            if channelId.isEmpty {
                                                Image(systemName: "number")
                                                    .font(Theme.Font.caption)
                                                    .foregroundStyle(Theme.Color.textTertiary)
                                                Text("チャンネルを選択...")
                                                    .font(Theme.Font.body)
                                                    .foregroundStyle(Theme.Color.textTertiary)
                                            } else {
                                                let sel = textChs.first(where: { $0.id == channelId })
                                                Image(systemName: sel?.type == .announcement ? "megaphone" : "number")
                                                    .font(Theme.Font.caption)
                                                    .foregroundStyle(Theme.Color.accent)
                                                Text(channelName)
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

                        // メッセージ
                        FormSection("メッセージ", icon: "message") {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                ZStack(alignment: .topLeading) {
                                    if message.isEmpty {
                                        Text("メッセージを入力...")
                                            .font(Theme.Font.body)
                                            .foregroundStyle(Theme.Color.textTertiary)
                                            .padding(.top, 10)
                                            .padding(.leading, 14)
                                            .allowsHitTesting(false)
                                    }
                                    TextEditor(text: $message)
                                        .font(Theme.Font.body)
                                        .foregroundStyle(Theme.Color.textPrimary)
                                        .scrollContentBackground(.hidden)
                                        .background(.clear)
                                        .frame(minHeight: 80, maxHeight: 140)
                                        .focused($focusedField, equals: .message)
                                }
                                .padding(2)
                                .background(Theme.Color.surfaceRaised)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))

                                variableChips(for: $message)

                                Text("{user.mention} は退室時には使用できません")
                                    .font(Theme.Font.caption2)
                                    .foregroundStyle(Theme.Color.textTertiary)
                            }
                        }

                        // DM
                        FormSection("ダイレクトメッセージ", icon: "envelope") {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                HStack {
                                    Text("退室前にDMを送信")
                                        .font(Theme.Font.body)
                                        .foregroundStyle(Theme.Color.textPrimary)
                                    Spacer()
                                    Toggle("", isOn: $dmEnabled.animation())
                                        .tint(Theme.Color.accent)
                                        .labelsHidden()
                                }

                                if dmEnabled {
                                    ZStack(alignment: .topLeading) {
                                        if dmMessage.isEmpty {
                                            Text("DMメッセージを入力...")
                                                .font(Theme.Font.body)
                                                .foregroundStyle(Theme.Color.textTertiary)
                                                .padding(.top, 10)
                                                .padding(.leading, 14)
                                                .allowsHitTesting(false)
                                        }
                                        TextEditor(text: $dmMessage)
                                            .font(Theme.Font.body)
                                            .foregroundStyle(Theme.Color.textPrimary)
                                            .scrollContentBackground(.hidden)
                                            .background(.clear)
                                            .frame(minHeight: 60, maxHeight: 120)
                                            .focused($focusedField, equals: .dmMessage)
                                    }
                                    .padding(2)
                                    .background(Theme.Color.surfaceRaised)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))

                                    variableChips(for: $dmMessage)
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
        .navigationTitle("退室メッセージ")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await save() } } label: {
                    if isSaving { ProgressView().scaleEffect(0.8) }
                    else { Text("保存").fontWeight(.semibold) }
                }
                .disabled(isSaving)
            }
            ToolbarItemGroup(placement: .keyboard) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.xs) {
                        ForEach(variables, id: \.self) { v in
                            Button { insertVariable(v) } label: {
                                Text(v)
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
        .toast($toast)
        .task { await load() }
        .redacted(reason: isLoading ? .placeholder : [])
    }

    private func insertVariable(_ v: String) {
        switch focusedField {
        case .message: message += v
        case .dmMessage: dmMessage += v
        case .none: break
        }
    }

    private func variableChips(for text: Binding<String>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(variables, id: \.self) { v in
                    Button { text.wrappedValue += v } label: {
                        Text(v)
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
            .padding(.vertical, 2)
        }
    }

    private func applyGreeting(_ s: GreetingSettings) {
        enabled     = s.goodbyeEnabled
        channelId   = s.goodbyeChannelId
        channelName = s.goodbyeChannelName
        message     = s.goodbyeMessage
        dmEnabled   = s.goodbyeDmEnabled
        dmMessage   = s.goodbyeDmMessage
        settings    = s
    }

    private func load() async {
        let gid = appState.selectedGuildId
        guard !gid.isEmpty else { isLoading = false; return }

        // 先読み済みキャッシュがあれば即表示
        if let cachedS: GreetingSettings = appState.guildData(.greeting, guild: gid) {
            applyGreeting(cachedS)
            if let cachedC: [Channel] = appState.guildData(.channels, guild: gid) { channels = cachedC }
            isLoading = false
        }

        async let sTask = services.greeting.fetch(guildId: gid)
        async let cTask = services.guilds.fetchChannels(guildId: gid)
        let s = (try? await sTask) ?? settings ?? GreetingSettings.defaultSettings(guildId: gid)
        applyGreeting(s)
        appState.setGuildData(s, .greeting, guild: gid)
        if let c = try? await cTask { channels = c; appState.setGuildData(c, .channels, guild: gid) }
        isLoading = false
    }

    private func save() async {
        isSaving = true
        var s = settings ?? GreetingSettings.defaultSettings(guildId: appState.selectedGuildId)
        s.goodbyeEnabled     = enabled
        s.goodbyeChannelId   = channelId
        s.goodbyeChannelName = channelName
        s.goodbyeMessage     = message
        s.goodbyeDmEnabled   = dmEnabled
        s.goodbyeDmMessage   = dmMessage
        let saved = (try? await services.greeting.save(s)) ?? s
        settings = saved
        isSaving = false
        toast = ToastMessage(type: .success, message: "保存しました")
    }
}

#Preview("Dark") {
    NavigationStack { GoodbyeMessageView() }
        .environment(\.services, ServiceContainer.live())
        .environment(AppState())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    NavigationStack { GoodbyeMessageView() }
        .environment(\.services, ServiceContainer.live())
        .environment(AppState())
        .preferredColorScheme(.light)
}
