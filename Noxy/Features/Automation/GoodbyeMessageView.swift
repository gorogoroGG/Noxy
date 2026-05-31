import SwiftUI

struct GoodbyeMessageView: View {
    @State private var isEnabled = true
    @State private var channelName = "general"
    @State private var messageText = "{user.name} が {server.name} から退室しました。👋"
    @State private var sendDMBeforeLeave = false
    @State private var dmMessage = "{server.name} での参加ありがとうございました。またの機会をお待ちしています！"
    @State private var toast: ToastMessage? = nil

    private let mockChannels = ["general", "goodbye", "logs", "lobby"]
    private let variables = ["{user.mention}", "{user.name}", "{server.name}", "{member.count}"]

    private var messagePreview: String {
        messageText
            .replacingOccurrences(of: "{user.mention}", with: "@OldMember")
            .replacingOccurrences(of: "{user.name}", with: "OldMember")
            .replacingOccurrences(of: "{server.name}", with: "Valorant JP")
            .replacingOccurrences(of: "{member.count}", with: "1,233")
    }

    var body: some View {
        List {
            Section {
                Toggle("退室メッセージを有効にする", isOn: $isEnabled.animation())
                    .tint(Color.accentGreen)
            }

            if isEnabled {
                Section("送信先") {
                    Picker("チャンネル", selection: $channelName) {
                        ForEach(mockChannels, id: \.self) { ch in
                            Text("#\(ch)").tag(ch)
                        }
                    }
                }

                Section("メッセージ") {
                    TextField("メッセージを入力...", text: $messageText, axis: .vertical)
                        .font(.bodyRegular)
                        .lineLimit(3...8)
                    variableHints
                }

                Section("プレビュー") {
                    HStack(alignment: .top, spacing: .spacing12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color.accentPink, Color.accentPurple],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .frame(width: 36, height: 36)
                            Image(systemName: "hand.wave.fill")
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
                }

                Section("オプション") {
                    Toggle("退室前にDMを送信", isOn: $sendDMBeforeLeave.animation())
                        .tint(Color.accentGreen)

                    if sendDMBeforeLeave {
                        TextField("DMメッセージ...", text: $dmMessage, axis: .vertical)
                            .font(.bodyRegular)
                            .lineLimit(2...6)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("退室メッセージ")
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

    private var variableHints: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .spacing8) {
                ForEach(variables, id: \.self) { variable in
                    Button {
                        messageText += variable
                    } label: {
                        Text(variable)
                            .font(.caption)
                            .foregroundStyle(Color.accentPink)
                            .padding(.horizontal, .spacing8)
                            .padding(.vertical, 4)
                            .background(Color.accentPink.opacity(0.1))
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
    NavigationStack { GoodbyeMessageView() }
        .preferredColorScheme(.dark)
}
