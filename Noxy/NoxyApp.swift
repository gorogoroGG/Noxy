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
    @State private var showSplash = true
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    init() {
        // #3: 旧 UserDefaults トークンを Keychain に移行
        KeychainHelper.migrateFromUserDefaults()

        let svc = ServiceContainer.live()
        _services    = State(initialValue: svc)
        _authManager = State(initialValue: AuthManager(services: svc))
    }

    var body: some View {
        Group {
            if showSplash {
                SplashView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                showSplash = false
                            }
                        }
                    }
            } else if !hasSeenOnboarding {
                OnboardingView()
            } else if !authManager.isLoggedIn {
                LoginView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSplash)
        .animation(.easeInOut(duration: 0.3), value: authManager.isLoggedIn)
        .environment(\.services, services)
        .environment(authManager)
        .environment(appState)
    }
}
