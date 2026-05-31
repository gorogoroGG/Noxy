import Foundation
import SwiftUI
import AuthenticationServices

// MARK: - Supabase Auth Service

struct SupabaseAuthService: AuthServiceProtocol {
    @MainActor
    func login() async throws -> User {
        let oauthURL = getOAuthURL()
        let callbackURL = try await authenticateWithDiscord(url: oauthURL)
        let session = try await exchangeCodeForSession(callbackURL: callbackURL)
        saveSession(session)
        return try await fetchDiscordUser(accessToken: session.discordAccessToken)
    }

    func logout() async throws {
        // 保存したセッションを削除
        UserDefaults.standard.removeObject(forKey: "supabase_access_token")
        UserDefaults.standard.removeObject(forKey: "supabase_refresh_token")
        UserDefaults.standard.removeObject(forKey: "discord_access_token")
        UserDefaults.standard.removeObject(forKey: "discord_user_id")
        UserDefaults.standard.removeObject(forKey: "discord_username")
        UserDefaults.standard.removeObject(forKey: "discord_avatar")
    }

    func currentUser() async throws -> User? {
        guard let userId = UserDefaults.standard.string(forKey: "discord_user_id"),
              let username = UserDefaults.standard.string(forKey: "discord_username") else {
            return nil
        }
        return User(
            id: userId,
            discordId: userId,
            username: username,
            displayName: username,
            avatarUrl: UserDefaults.standard.string(forKey: "discord_avatar"),
            createdAt: Date()
        )
    }
}

// MARK: - Internal

private struct AuthSession: Decodable {
    let accessToken: String
    let refreshToken: String
    let discordAccessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case providerToken = "provider_token"
    }

    init(accessToken: String, refreshToken: String, discordAccessToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.discordAccessToken = discordAccessToken
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        discordAccessToken = (try? container.decode(String.self, forKey: .providerToken)) ?? ""
    }
}

private struct DiscordUserResponse: Decodable {
    let id: String
    let username: String
    let avatar: String?

    var avatarUrl: String? {
        guard let avatar else { return nil }
        return "https://cdn.discordapp.com/avatars/\(id)/\(avatar).png"
    }
}

// MARK: - OAuth Flow

private func getOAuthURL() -> URL {
    let urlString = "\(SupabaseConfig.baseURL)/auth/v1/authorize?provider=discord&scopes=guilds"
    return URL(string: urlString)!
}

@MainActor
private func authenticateWithDiscord(url: URL) async throws -> URL {
    return try await withCheckedThrowingContinuation { continuation in
        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "noxy"
        ) { callbackURL, error in
            if let error {
                continuation.resume(throwing: error)
            } else if let callbackURL {
                continuation.resume(returning: callbackURL)
            } else {
                continuation.resume(throwing: SupabaseError.notConfigured)
            }
        }
        session.presentationContextProvider = AuthPresentationContextProvider.shared
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }
}

private class AuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AuthPresentationContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

// MARK: - Token Exchange

private func exchangeCodeForSession(callbackURL: URL) async throws -> AuthSession {
    guard let fragment = callbackURL.fragment else {
        throw SupabaseError.notConfigured
    }
    let params = parseFragment(fragment)

    guard let accessToken = params["access_token"],
          let refreshToken = params["refresh_token"] else {
        throw SupabaseError.notConfigured
    }

    let discordToken = params["provider_token"] ?? ""

    return AuthSession(accessToken: accessToken, refreshToken: refreshToken, discordAccessToken: discordToken)
}

private func parseFragment(_ fragment: String) -> [String: String] {
    var result: [String: String] = [:]
    let pairs = fragment.split(separator: "&")
    for pair in pairs {
        let parts = pair.split(separator: "=", maxSplits: 1)
        if parts.count == 2 {
            result[String(parts[0])] = String(parts[1])
        }
    }
    return result
}

// MARK: - Session Persistence

private func saveSession(_ session: AuthSession) {
    UserDefaults.standard.set(session.accessToken, forKey: "supabase_access_token")
    UserDefaults.standard.set(session.refreshToken, forKey: "supabase_refresh_token")
    if !session.discordAccessToken.isEmpty {
        UserDefaults.standard.set(session.discordAccessToken, forKey: "discord_access_token")
    }
}

// MARK: - Discord User Info

private func fetchDiscordUser(accessToken: String) async throws -> User {
    let url = URL(string: "https://discord.com/api/v10/users/@me")!
    var req = URLRequest(url: url)
    req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, resp) = try await URLSession.shared.data(for: req)
    guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else {
        throw SupabaseError.notConfigured
    }

    let discordUser = try JSONDecoder().decode(DiscordUserResponse.self, from: data)

    // 永続化
    UserDefaults.standard.set(discordUser.id, forKey: "discord_user_id")
    UserDefaults.standard.set(discordUser.username, forKey: "discord_username")
    if let avatar = discordUser.avatarUrl {
        UserDefaults.standard.set(avatar, forKey: "discord_avatar")
    }

    return User(
        id: discordUser.id,
        discordId: discordUser.id,
        username: discordUser.username,
        displayName: discordUser.username,
        avatarUrl: discordUser.avatarUrl,
        createdAt: Date()
    )
}
