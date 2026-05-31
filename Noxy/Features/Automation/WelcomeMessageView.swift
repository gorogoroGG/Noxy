import SwiftUI

struct WelcomeMessageView: View {
    // ON/OFF
    @State private var isEnabled = true

    // 配置
    @State private var channelName = "welcome"

    // メッセージ
    @State private var messageText = "{user.mention} が {server.name} に参加しました！🎉 メンバー数: {member.count}人"

    // オプション
    @State private var sendDM = false
    @State private var autoRoleEnabled = false
    @State private var autoRoleName = "Member"

    @State private var toast: ToastMessage? = nil

    private let mockChannels = ["welcome", "general", "introductions", "new-members", "lobby"]
    private let mockRoles    = ["Member", "Guest", "New", "Verified", "Community"]
    private let variables    = ["{user.mention}", "{user.name}", "{server.name}", "{member.count}"]

    private var messagePreview: String {
        messageText
            .replacingOccurrences(of: "{user.mention}",  with: "@NewMember")
            .replacingOccurrences(of: "{user.name}",     with: "NewMember")
            .replacingOccurrences(of: "{server.name}",   with: "Valorant JP")
            .replacingOccurrences(of: "{member.count}",  with: "1,234")
    }

    var body: some View {
        List {
            // ── 有効 / 無効 ──
            Section {
                Toggle("ウェルカムメッセージを有効にする", isOn: $isEnabled.animation())
                    .tint(Color.accentGreen)
            }

            if isEnabled {
                // ── 送信先チャンネル ──
                Section {
                    Picker("チャンネル", selection: $channelName) {
                        ForEach(mockChannels, id: \.self) { ch in
                            Text("#\(ch)").tag(ch)
                        }
                    }
                } header: {
                    Text("送信先")
                } footer: {
                    Text("新メンバーが参加したときにメッセージを送るチャンネルです。")
                }

                // ── メッセージ内容 ──
                Section {
                    TextField("メッセージを入力...", text: $messageText, axis: .vertical)
                        .font(.bodyRegular)
                        .lineLimit(3...8)

                    variableHints
                } header: {
                    Text("メッセージ")
                }

                // ── プレビュー ──
                Section {
                    HStack(alignment: .top, spacing: .spacing12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color.accentIndigo, Color.accentPurple],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .frame(width: 36, height: 36)
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: .spacing6) {
                                Text("Noxy")
                                    .font(.bodySmall)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.textPrimary)
                                Text("BOT")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.accentIndigo)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            Text(messagePreview)
                                .font(.bodySmall)
                                .foregroundStyle(Color.textPrimary)
                        }
                    }
                    .padding(.vertical, .spacing4)
                } header: {
                    Text("プレビュー")
                }

                // ── オプション ──
                Section {
                    Toggle("新メンバーにDMを送信", isOn: $sendDM)
                        .tint(Color.accentGreen)

                    Toggle("参加時にロールを付与", isOn: $autoRoleEnabled.animation())
                        .tint(Color.accentGreen)

                    if autoRoleEnabled {
                        Picker("付与するロール", selection: $autoRoleName) {
                            ForEach(mockRoles, id: \.self) { role in
                                Text("@\(role)").tag(role)
                            }
                        }
                    }
                } header: {
                    Text("オプション")
                } footer: {
                    if autoRoleEnabled {
                        Text("参加した全メンバーに @\(autoRoleName) ロールを自動で付与します。")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("ウェルカムメッセージ")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    toast = ToastMessage(type: .success, message: "保存しました")
                }
                .fontWeight(.semibold)
                .disabled(!isEnabled)
            }
        }
        .toast($toast)
    }

    // MARK: Variable hints

    private var variableHints: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .spacing8) {
                ForEach(variables, id: \.self) { variable in
                    Button {
                        messageText += variable
                    } label: {
                        Text(variable)
                            .font(.caption)
                            .foregroundStyle(Color.accentGreen)
                            .padding(.horizontal, .spacing8)
                            .padding(.vertical, 4)
                            .background(Color.accentGreen.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

#Preview {
    NavigationStack { WelcomeMessageView() }
        .environment(\.services, ServiceContainer.live())
        .preferredColorScheme(.dark)
}
