import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var displayName = "GoroGoro"
    @State private var bio = "Discord bot enthusiast 🤖"
    @State private var isEditing = false

    var body: some View {
        List {
            // Avatar + name header
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: .spacing12) {
                        Avatar(name: displayName, size: 80, accentColor: .accentIndigo)
                            .onTapGesture { /* mock avatar change */ }

                        if isEditing {
                            TextField("表示名", text: $displayName)
                                .font(.displayMedium)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.textPrimary)
                        } else {
                            Text(displayName)
                                .font(.displayMedium)
                                .foregroundStyle(Color.textPrimary)
                        }

                        if isEditing {
                            TextField("自己紹介", text: $bio)
                                .font(.bodySmall)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.textSecondary)
                        } else {
                            Text(bio)
                                .font(.bodySmall)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, .spacing8)
            }

            Section("Discord連携") {
                HStack(spacing: .spacing12) {
                    Image(systemName: "gamecontroller.fill")
                        .foregroundStyle(Color.accentIndigo)
                    Text("@gorogoroGG")
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Badge(text: "CONNECTED", color: .accentGreen)
                }
            }

            Section("参加日") {
                LabeledContent("登録日") {
                    Text("2020年9月")
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Section("統計") {
                LabeledContent("Embed作成数") { Text("42").foregroundStyle(Color.accentIndigo) }
                LabeledContent("送信メッセージ数")  { Text("1,892").foregroundStyle(Color.accentIndigo) }
                LabeledContent("管理サーバー数") { Text("6").foregroundStyle(Color.accentIndigo) }
            }
        }
        .navigationTitle("プロフィール")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "完了" : "編集") {
                    isEditing.toggle()
                }
                .fontWeight(isEditing ? .semibold : .regular)
                .foregroundStyle(Color.accentIndigo)
            }
        }
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environment(AuthManager(services: ServiceContainer.live()))
        .preferredColorScheme(.dark)
}
