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
        // Discord トークンがある場合はユーザー情報をフェッチ
        if !session.discordAccessToken.isEmpty {
            if let user = try? await fetchDiscordUser(accessToken: session.discordAccessToken) {
                return user
            }
        }
        // フォールバック: Supabase のトークンからユーザー情報を取得
        return try await fetchSupabaseUser(accessToken: session.accessToken)
    }

    func logout() async throws {
        // Supabase セッション失効（可能な場合）
        if let token = KeychainHelper.load(forKey: "supabase_access_token") {
            var req = URLRequest(url: URL(string: "\(SupabaseConfig.baseURL)/auth/v1/logout")!)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            _ = try? await URLSession.shared.data(for: req)
        }
        clearSession()
    }

    func currentUser() async throws -> User? {
        // 保存済みユーザー情報があれば即返却 (#3: Keychain から読み取り)
        if let userId   = KeychainHelper.load(forKey: "discord_user_id"),
           let username = KeychainHelper.load(forKey: "discord_username") {
            if let accessToken = KeychainHelper.load(forKey: "supabase_access_token") {
                let isValid = await isTokenValid(accessToken: accessToken)
                if !isValid {
                    if let refreshed = try? await refreshSession() { return refreshed }
                    clearSession()
                    return nil
                }
            }
            return User(
                id: userId,
                discordId: userId,
                username: username,
                displayName: username,
                avatarUrl: KeychainHelper.load(forKey: "discord_avatar"),
                createdAt: Date()
            )
        }
        return nil
    }
}

// MARK: - Token Management

private func isTokenValid(accessToken: String) async -> Bool {
    var req = URLRequest(url: URL(string: "\(SupabaseConfig.baseURL)/auth/v1/user")!)
    req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
    guard let (_, resp) = try? await URLSession.shared.data(for: req),
          let http = resp as? HTTPURLResponse else { return false }
    return http.statusCode == 200
}

private func refreshSession() async throws -> User? {
    guard let refreshToken = KeychainHelper.load(forKey: "supabase_refresh_token") else {
        return nil
    }
    struct RefreshBody: Encodable { let refresh_token: String }
    var req = URLRequest(url: URL(string: "\(SupabaseConfig.baseURL)/auth/v1/token?grant_type=refresh_token")!)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
    req.httpBody = try JSONEncoder().encode(RefreshBody(refresh_token: refreshToken))
    let (data, response) = try await URLSession.shared.data(for: req)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
    let session = try JSONDecoder().decode(AuthSession.self, from: data)
    saveSession(session)
    if !session.discordAccessToken.isEmpty {
        return try? await fetchDiscordUser(accessToken: session.discordAccessToken)
    }
    return try? await fetchSupabaseUser(accessToken: session.accessToken)
}

private func clearSession() {
    let keys = ["supabase_access_token", "supabase_refresh_token",
                "discord_access_token", "discord_user_id",
                "discord_username", "discord_avatar"]
    keys.forEach { KeychainHelper.delete(forKey: $0) }
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
    // identify スコープ: Discord ユーザー情報取得に必須
    // guilds スコープ: サーバー一覧取得に必須
    let scopes = "identify%20guilds"
    let urlString = "\(SupabaseConfig.baseURL)/auth/v1/authorize?provider=discord&scopes=\(scopes)"
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
        #if canImport(UIKit)
        let scenes = UIApplication.shared.connectedScenes
        if let windowScene = scenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: \.isKeyWindow) {
            return window
        }
        return ASPresentationAnchor()
        #elseif canImport(AppKit)
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
        #endif
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

// MARK: - Session Persistence (#3: Keychain に保存)

private func saveSession(_ session: AuthSession) {
    KeychainHelper.save(session.accessToken,  forKey: "supabase_access_token")
    KeychainHelper.save(session.refreshToken, forKey: "supabase_refresh_token")
    if !session.discordAccessToken.isEmpty {
        KeychainHelper.save(session.discordAccessToken, forKey: "discord_access_token")
    }
}

// MARK: - Supabase User Info (フォールバック)

private struct SupabaseUserResponse: Decodable {
    let id: String
    let email: String?

    struct UserMetadata: Decodable {
        let fullName: String?
        let name: String?
        let preferredUsername: String?
        let avatarUrl: String?
        let providerId: String?  // Discord ID が入っていることが多い
        let sub: String?
    }

    struct Identity: Decodable {
        struct IdentityData: Decodable {
            let sub: String?  // Discord ID
        }
        let identityData: IdentityData?
    }

    let userMetadata: UserMetadata?
    let identities: [Identity]?

    enum CodingKeys: String, CodingKey {
        case id, email, identities
        case userMetadata = "user_metadata"
    }
}

private func fetchSupabaseUser(accessToken: String) async throws -> User {
    let url = URL(string: "\(SupabaseConfig.baseURL)/auth/v1/user")!
    var req = URLRequest(url: url)
    req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
    let (data, resp) = try await URLSession.shared.data(for: req)
    guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
        throw SupabaseError.notConfigured
    }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let supaUser = try decoder.decode(SupabaseUserResponse.self, from: data)
    let username = supaUser.userMetadata?.preferredUsername
                   ?? supaUser.userMetadata?.name
                   ?? supaUser.email
                   ?? supaUser.id
    let avatarUrl = supaUser.userMetadata?.avatarUrl
    // Discord ID の取得優先順位を Worker の verifySupabaseJwt と完全に一致させる
    //   1. user_metadata.provider_id
    //   2. user_metadata.sub
    //   3. identities[0].identity_data.sub  ← Worker と同じパスを追加
    //   Supabase UUID にはフォールバックしない（Worker が見つけられず不一致になるため）
    let discordId = supaUser.userMetadata?.providerId
                    ?? supaUser.userMetadata?.sub
                    ?? supaUser.identities?.first?.identityData?.sub

    if let id = discordId {
        KeychainHelper.save(id, forKey: "discord_user_id")
    }
    // discordId が取れなかった場合は既存の Keychain 値を維持する（fetchDiscordUser で保存済みなら正しい）
    let resolvedId = discordId ?? KeychainHelper.load(forKey: "discord_user_id") ?? supaUser.id
    KeychainHelper.save(username,   forKey: "discord_username")
    if let avatar = avatarUrl {
        KeychainHelper.save(avatar, forKey: "discord_avatar")
    }
    return User(
        id: resolvedId,
        discordId: resolvedId,
        username: username,
        displayName: username,
        avatarUrl: avatarUrl,
        createdAt: Date()
    )
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

    // 永続化 (Keychain に統一)
    KeychainHelper.save(discordUser.id,       forKey: "discord_user_id")
    KeychainHelper.save(discordUser.username, forKey: "discord_username")
    if let avatar = discordUser.avatarUrl {
        KeychainHelper.save(avatar, forKey: "discord_avatar")
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
