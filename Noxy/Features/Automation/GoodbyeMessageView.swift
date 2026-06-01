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

    var body: some View {
        List {
            Section {
                Toggle("退室メッセージを有効にする", isOn: $enabled.animation())
                    .tint(Color.accentPink)
            }

            if enabled {
                Section {
                    if channels.isEmpty {
                        ProgressView("チャンネルを読み込み中...").frame(maxWidth: .infinity)
                    } else {
                        Picker("チャンネル", selection: $channelId) {
                            Text("チャンネルを選択").tag("")
                            ForEach(channels.filter { $0.type == .text || $0.type == .announcement }) { ch in
                                Label("#\(ch.name)", systemImage: ch.type == .announcement ? "megaphone" : "number").tag(ch.id)
                            }
                        }
                        .onChange(of: channelId) { _, id in
                            channelName = channels.first(where: { $0.id == id })?.name ?? ""
                        }
                    }
                } header: { Text("送信先チャンネル") }
                  footer: { Text("メンバーが退室したときにメッセージを送るチャンネルです。") }

                Section {
                    ZStack(alignment: .topLeading) {
                        if message.isEmpty {
                            Text("メッセージを入力...").foregroundStyle(Color.textTertiary).font(.bodyRegular)
                                .padding(.top, 8).padding(.leading, 4).allowsHitTesting(false)
                        }
                        TextEditor(text: $message).font(.bodyRegular).frame(minHeight: 80).scrollContentBackground(.hidden)
                    }
                    variableChips(for: $message, color: .accentPink)
                } header: { Text("チャンネルメッセージ") }
                  footer: { Text("退室時は {user.mention} は使用できません。") }

                Section {
                    discordChannelPreview(text: buildHighlighted(message, color: .accentPink))
                } header: { Text("チャンネルメッセージ プレビュー") }

                Section {
                    Toggle("退室前にDMを送信", isOn: $dmEnabled.animation()).tint(Color.accentPink)
                    if dmEnabled {
                        ZStack(alignment: .topLeading) {
                            if dmMessage.isEmpty {
                                Text("DMメッセージを入力...").foregroundStyle(Color.textTertiary).font(.bodyRegular)
                                    .padding(.top, 8).padding(.leading, 4).allowsHitTesting(false)
                            }
                            TextEditor(text: $dmMessage).font(.bodyRegular).frame(minHeight: 60).scrollContentBackground(.hidden)
                        }
                        variableChips(for: $dmMessage, color: .accentPink)
                    }
                } header: { Text("ダイレクトメッセージ") }
                  footer: { dmEnabled ? Text("退室処理前に本人へDMで送信されます。") : nil }

                if dmEnabled {
                    Section {
                        dmPreview(text: buildHighlighted(dmMessage, color: .accentPink))
                    } header: { Text("DM プレビュー") }
                }
            }
        }
        .listStyle(.insetGrouped)
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
        }
        .toast($toast)
        .task { await load() }
        .redacted(reason: isLoading ? .placeholder : [])
    }

    private func variableChips(for text: Binding<String>, color: Color) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .spacing8) {
                ForEach(variables, id: \.self) { v in
                    Button { text.wrappedValue += v } label: {
                        Text(v).font(.caption).fontWeight(.medium).foregroundStyle(color)
                            .padding(.horizontal, .spacing8).padding(.vertical, 4)
                            .background(color.opacity(0.12)).clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }.padding(.vertical, 2)
        }
    }

    private func discordChannelPreview(text: AttributedString) -> some View {
        HStack(alignment: .top, spacing: .spacing12) {
            ZStack {
                Circle().fill(LinearGradient(colors: [.accentPink, .accentPurple], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 36, height: 36)
                Image(systemName: "hand.wave.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: .spacing6) {
                    Text("Noxy").font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                    Text("BOT").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 2).background(Color.accentIndigo).clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Text(text).font(.bodySmall).foregroundStyle(Color.textPrimary)
            }
        }.padding(.vertical, .spacing4)
    }

    private func dmPreview(text: AttributedString) -> some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            HStack(spacing: .spacing6) {
                Image(systemName: "envelope.fill").font(.captionSmall).foregroundStyle(Color.accentPink)
                Text("ダイレクトメッセージ").font(.captionSmall).foregroundStyle(Color.accentPink)
            }
            HStack(alignment: .top, spacing: .spacing10) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [.accentPink, .accentPurple], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 32, height: 32)
                    Image(systemName: "hand.wave.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
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

    private func buildHighlighted(_ raw: String, color: Color) -> AttributedString {
        let map: [(String, String)] = [
            ("{user.name}", "OldMember"),
            ("{server.name}", appState.selectedGuild?.name ?? "サーバー"),
            ("{member.count}", "1,233"),
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
            if !matched { result.append(AttributedString(String(remaining.removeFirst()))) }
        }
        return result
    }

    private func load() async {
        guard !appState.selectedGuildId.isEmpty else { isLoading = false; return }
        async let sTask = services.greeting.fetch(guildId: appState.selectedGuildId)
        async let cTask = services.guilds.fetchChannels(guildId: appState.selectedGuildId)
        let s = (try? await sTask) ?? GreetingSettings.defaultSettings(guildId: appState.selectedGuildId)
        channels = (try? await cTask) ?? []
        enabled     = s.goodbyeEnabled
        channelId   = s.goodbyeChannelId
        channelName = s.goodbyeChannelName
        message     = s.goodbyeMessage
        dmEnabled   = s.goodbyeDmEnabled
        dmMessage   = s.goodbyeDmMessage
        settings    = s
        isLoading   = false
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

#Preview {
    NavigationStack { GoodbyeMessageView() }
        .environment(\.services, ServiceContainer.live())
        .environment(AppState())
        .preferredColorScheme(.dark)
}
