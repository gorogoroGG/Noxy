import SwiftUI

@main
struct NoxyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @State private var services: ServiceContainer
    @State private var authManager: AuthManager
    @State private var appState = AppState()
    @State private var showSplash    = true
    @State private var timerElapsed  = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("colorScheme") private var colorSchemePref = "システム"

    private var preferredScheme: ColorScheme? {
        switch colorSchemePref {
        case "ライト": return .light
        case "ダーク":  return .dark
        default:       return nil
        }
    }

    init() {
        // #3: 旧 UserDefaults トークンを Keychain に移行
        KeychainHelper.migrateFromUserDefaults()

        let svc = ServiceContainer.live()
        _services    = State(initialValue: svc)
        _authManager = State(initialValue: AuthManager(services: svc))
    }

    var body: some View {
        Group {
            if !hasSeenOnboarding {
                OnboardingView()
            } else if !authManager.isLoggedIn {
                LoginView()
            } else {
                mainContent
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isLoggedIn)
        .environment(\.services, services)
        .environment(authManager)
        .environment(appState)
        .preferredColorScheme(preferredScheme)
    }

    // MainTabView を先に描画し、SplashView をオーバーレイで重ねる。
    // タイマー（1.2s）と isAppReady の両方が揃った時点でスプラッシュをフェードアウト。
    private var mainContent: some View {
        ZStack {
            MainTabView()

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(999)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            timerElapsed = true
                            dismissSplashIfReady()
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.45), value: showSplash)
        .onChange(of: appState.isAppReady) { _, ready in
            if ready { dismissSplashIfReady() }
        }
    }

    private func dismissSplashIfReady() {
        guard timerElapsed && appState.isAppReady else { return }
        withAnimation(.easeInOut(duration: 0.45)) {
            showSplash = false
        }
    }
}
