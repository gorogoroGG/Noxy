import SwiftUI

struct BotSettingsView: View {
    @AppStorage("discord_bot_token")  private var botToken = ""
    @AppStorage("discord_client_id")  private var clientId = ""
    @State private var showToken = false

    var body: some View {
        Form {
            Section {
                TextField("Client ID", text: $clientId)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Discord Application")
            } footer: {
                Text("Discord Developer Portal → OAuth2 → Client ID")
            }

            Section {
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
            } header: {
                Text("Bot Token")
            } footer: {
                Text("Discord Developer Portal → Bot → Token")
            }

            Section {
                Text("Bot 招待URL:")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
                Text(inviteURL)
                    .font(.captionRegular)
                    .foregroundStyle(Color.accentIndigo)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("Bot 設定")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var inviteURL: String {
        guard !clientId.isEmpty else { return "Client ID を入力してください" }
        return "https://discord.com/api/oauth2/authorize?client_id=\(clientId)&permissions=2147485696&scope=bot%20applications.commands"
    }
}

#Preview {
    NavigationStack {
        BotSettingsView()
    }
}
