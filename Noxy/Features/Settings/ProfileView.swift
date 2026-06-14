import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var displayName = "GoroGoro"
    @State private var bio = "Discord bot enthusiast 🤖"
    @State private var isEditing = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                avatarSection
                discordSection
                joinDateSection
                statsSection
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.Color.bg)
        .navigationTitle("プロフィール")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "完了" : "編集") {
                    isEditing.toggle()
                }
                .font(Theme.Font.bodyMedium)
                .fontWeight(isEditing ? .semibold : .regular)
                .foregroundStyle(Theme.Color.accent)
            }
        }
    }

    // MARK: - Sections

    private var avatarSection: some View {
        Card {
            HStack {
                Spacer()
                VStack(spacing: Theme.Spacing.sm) {
                    Avatar(name: displayName, size: 80, accentColor: Theme.Color.accent)
                        .onTapGesture { /* mock avatar change */ }

                    if isEditing {
                        TextField("表示名", text: $displayName)
                            .font(Theme.Font.title3)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.Color.textPrimary)
                    } else {
                        Text(displayName)
                            .font(Theme.Font.title3)
                            .foregroundStyle(Theme.Color.textPrimary)
                    }

                    if isEditing {
                        TextField("自己紹介", text: $bio)
                            .font(Theme.Font.bodySmall)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.Color.textSecondary)
                    } else {
                        Text(bio)
                            .font(Theme.Font.bodySmall)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    private var discordSection: some View {
        FormSection("Discord連携", icon: "link") {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(Theme.Color.textSecondary)
                    .frame(width: 28)
                Text("@gorogoroGG")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .monospaced()
                Spacer()
                HStack(spacing: 4) {
                    StatusDot(color: Theme.Color.statusOK)
                    Text("CONNECTED")
                        .font(Theme.Font.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.Color.statusOK)
                }
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    private var joinDateSection: some View {
        FormSection("参加日", icon: "calendar") {
            HStack(spacing: Theme.Spacing.sm) {
                Text("登録日")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textPrimary)
                Spacer()
                Text("2020年9月")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    private var statsSection: some View {
        FormSection("統計", icon: "chart.bar") {
            VStack(spacing: 0) {
                statRow(label: "Embed作成数", value: "42")
                Divider().background(Theme.Color.line)
                statRow(label: "送信メッセージ数", value: "1,892")
                Divider().background(Theme.Color.line)
                statRow(label: "管理サーバー数", value: "6")
            }
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(label)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textPrimary)
            Spacer()
            Text(value)
                .font(Theme.Font.mono)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(.vertical, Theme.Spacing.sm)
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environment(AuthManager(services: ServiceContainer.live()))
}

#Preview("Dark") {
    NavigationStack { ProfileView() }
        .environment(AuthManager(services: ServiceContainer.live()))
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    NavigationStack { ProfileView() }
        .environment(AuthManager(services: ServiceContainer.live()))
        .preferredColorScheme(.light)
}
