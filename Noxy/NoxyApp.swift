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
    @State private var bootFinished  = false
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

    // 起動直後は常にスプラッシュを最前面に表示する。
    // スプラッシュ表示中に AuthManager がセッション復元（ログイン状態の確認）を行い、
    //   - ログイン済み  → そのままブートを進めてホームへ
    //   - 未ログイン    → スプラッシュ内にログインボタンをふわっと表示
    // という流れにすることで「スプラッシュ前にログイン画面が一瞬出る」問題を防ぐ。
    // ホーム（MainTabView）はログイン済みのときだけ背面に用意し、
    // ブート完了（onFinished）と isAppReady が揃った時点でスプラッシュをフェードアウトする。
    private var mainContent: some View {
        ZStack {
            if authManager.isLoggedIn {
                MainTabView()
            }

            if showSplash {
                SplashView(
                    authManager: authManager,
                    onFinished: {
                        bootFinished = true
                        dismissSplashIfReady()
                    }
                )
                .transition(.opacity)
                .zIndex(999)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: showSplash)
        .onChange(of: appState.isAppReady) { _, ready in
            if ready { dismissSplashIfReady() }
        }
    }

    private func dismissSplashIfReady() {
        guard bootFinished && appState.isAppReady else { return }
        withAnimation(.easeInOut(duration: 0.45)) {
            showSplash = false
        }
    }
}
