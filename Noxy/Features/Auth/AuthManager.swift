import SwiftUI
import Observation

@Observable
@MainActor
final class AuthManager {
    var isLoggedIn: Bool = false
    var currentUser: User? = nil
    var isLoading: Bool = false

    private let services: ServiceContainer

    init(services: ServiceContainer) {
        self.services = services
        restoreSession()
    }

    func login() async throws {
        isLoading = true
        do {
            let user = try await services.auth.login()
            currentUser = user
            isLoggedIn = true
        } catch {
            isLoggedIn = false
            throw error
        }
        isLoading = false
    }

    func logout() {
        Task {
            try? await services.auth.logout()
        }
        currentUser = nil
        isLoggedIn = false
    }

    private func restoreSession() {
        Task {
            // 保存されたトークンがあるか確認 → あればユーザー情報復元
            if let user = try? await services.auth.currentUser() {
                currentUser = user
                isLoggedIn = true
            }
        }
    }
}
