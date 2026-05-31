import SwiftUI

struct MainTabView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var appState = AppState()

    var body: some View {
        ZStack {
            TabView {
                DashboardView()
                    .tabItem { Label("ホーム", systemImage: "house.fill") }

                FeaturesTabView()
                    .tabItem { Label("機能", systemImage: "square.grid.2x2.fill") }

                MonitorView()
                    .tabItem { Label("モニター", systemImage: "waveform") }

                CommunityTabView()
                    .tabItem { Label("サーバー", systemImage: "server.rack") }

                MoreTabView()
                    .tabItem { Label("設定", systemImage: "gearshape.fill") }
            }
            .tint(Color.accentIndigo)
            .mockBanner()
            .environment(appState)

            // サーバー切り替え時の全画面ローディング
            if appState.isSwitchingServer {
                ServerSwitchingOverlay(guildName: appState.switchingToName)
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.isSwitchingServer)
    }
}

// MARK: - Overlay

private struct ServerSwitchingOverlay: View {
    let guildName: String?

    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: .spacing20) {
                // アプリアイコン（SplashView と同じデザイン）
                RoundedRectangle(cornerRadius: .cornerRadiusLarge)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentIndigo, Color.accentPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .overlay {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Color.accentIndigo.opacity(0.4), radius: 20, x: 0, y: 10)
                    .scaleEffect(scale)

                VStack(spacing: .spacing12) {
                    ProgressView()
                        .tint(Color.accentIndigo)

                    if let name = guildName {
                        Text(name)
                            .font(.titleMedium)
                            .foregroundStyle(Color.textPrimary)
                            .opacity(opacity)
                    }

                    Text("サーバーを切り替え中...")
                        .font(.bodySmall)
                        .foregroundStyle(Color.textSecondary)
                        .opacity(opacity)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.4)) {
                scale   = 1.0
                opacity = 1.0
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AuthManager(services: ServiceContainer.live()))
        .environment(\.services, ServiceContainer.live())
        .preferredColorScheme(.dark)
}
