import SwiftUI

struct BotSettingsView: View {
    @AppStorage("discord_bot_token")  private var botToken = ""
    @AppStorage("discord_client_id")  private var clientId = ""
    @State private var showToken = false

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing16) {
                FormSection("Discord Application", icon: "app.badge", footer: "Discord Developer Portal → OAuth2 → Client ID") {
                    FormField.text(label: "Client ID", text: $clientId)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                FormSection("Bot Token", icon: "key", footer: "Discord Developer Portal → Bot → Token") {
                    FormField(label: "Bot Token") {
                        ZStack(alignment: .trailing) {
                            if showToken {
                                TextField("Bot Token", text: $botToken)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            } else {
                                SecureField("Bot Token", text: $botToken)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            }
                            Button {
                                showToken.toggle()
                            } label: {
                                Image(systemName: showToken ? "eye.slash" : "eye")
                                    .foregroundStyle(Color.textTertiary)
                            }
                        }
                        .inputStyle(height: 44)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: .spacing8) {
                        Text("Bot 招待URL:")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                        Text(inviteURL)
                            .font(.captionRegular)
                            .foregroundStyle(Color.accentIndigo)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.spacing16)
            .padding(.bottom, 24)
        }
        .background(Color.bgPrimary)
        .navigationTitle("Bot 設定")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var inviteURL: String {
        guard !clientId.isEmpty else { return "Client ID を入力してください" }
        return "https://discord.com/api/oauth2/authorize?client_id=\(clientId)&permissions=2164262912&scope=bot%20applications.commands"
    }
}

#Preview {
    NavigationStack {
        BotSettingsView()
    }
}
