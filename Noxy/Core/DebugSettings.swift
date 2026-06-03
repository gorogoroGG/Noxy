import Foundation
import SwiftUI

// MARK: - DebugSettings
// DEBUG ビルドでのみ有効。課金状態を実際の DB を操作して切り替える。
// Pro ON → Worker /billing/debug-setup で user_profiles に 3スロットを UPSERT
// Pro OFF → Worker /billing/debug-setup で user_profiles をリセット & activated_servers 全削除
// サーバー有効化/解除 → 本番と同じ /billing/activate エンドポイントを使用

#if DEBUG

@Observable
final class DebugSettings {
    static let shared = DebugSettings()

    /// UI 表示用: true のときデバッグ Pro モード
    private(set) var isProMode: Bool = UserDefaults.standard.bool(forKey: "__debug_pro_mode")
    private(set) var isWorking: Bool = false
    private(set) var lastError: String? = nil

    // MARK: - Pro モード切り替え（DB 操作付き）

    @MainActor
    func setProMode(_ enabled: Bool) async {
        isWorking = true
        lastError = nil
        do {
            if enabled {
                try await setupDebugProfile(slots: 3)
                isProMode = true
                UserDefaults.standard.set(true, forKey: "__debug_pro_mode")
            } else {
                try await teardownDebugProfile()
                isProMode = false
                UserDefaults.standard.set(false, forKey: "__debug_pro_mode")
            }
        } catch {
            lastError = error.localizedDescription
        }
        isWorking = false
    }

    // MARK: - DB セットアップ

    /// user_profiles に指定スロット数を UPSERT する（StoreKit 不要）
    private func setupDebugProfile(slots: Int) async throws {
        let discordUserId  = KeychainHelper.load(forKey: "discord_user_id") ?? ""
        let supabaseUserId = try await fetchSupabaseUserId()

        guard !discordUserId.isEmpty, !supabaseUserId.isEmpty else {
            throw DebugError.notLoggedIn
        }

        struct Body: Encodable {
            let discordUserId: String
            let supabaseUserId: String
            let purchasedSlots: Int
            let productId: String?
        }

        guard let url = URL(string: "\(DiscordConfig.workerURL)/billing/debug-setup") else {
            throw DebugError.networkError
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(DiscordConfig.workerAPISecret, forHTTPHeaderField: "X-Bot-Secret")
        req.setValue("1", forHTTPHeaderField: "X-Debug")   // デバッグ専用ヘッダー
        req.httpBody = try JSONEncoder().encode(Body(
            discordUserId:  discordUserId,
            supabaseUserId: supabaseUserId,
            purchasedSlots: slots,
            productId:      "jp.noxyapp.stat.\(slots)server"
        ))
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DebugError.networkError
        }
    }

    /// user_profiles をリセット + activated_servers を全削除
    private func teardownDebugProfile() async throws {
        let discordUserId  = KeychainHelper.load(forKey: "discord_user_id") ?? ""
        let supabaseUserId = try await fetchSupabaseUserId()

        guard !discordUserId.isEmpty, !supabaseUserId.isEmpty else { return }

        struct Body: Encodable {
            let discordUserId: String
            let supabaseUserId: String
            let purchasedSlots: Int
            let productId: String?
        }

        guard let url = URL(string: "\(DiscordConfig.workerURL)/billing/debug-setup") else {
            throw DebugError.networkError
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(DiscordConfig.workerAPISecret, forHTTPHeaderField: "X-Bot-Secret")
        req.setValue("1", forHTTPHeaderField: "X-Debug")
        req.httpBody = try JSONEncoder().encode(Body(
            discordUserId:  discordUserId,
            supabaseUserId: supabaseUserId,
            purchasedSlots: 0,
            productId:      nil
        ))
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DebugError.networkError
        }
    }

    // MARK: - Supabase ユーザー ID 取得

    private func fetchSupabaseUserId() async throws -> String {
        let jwt = KeychainHelper.load(forKey: "supabase_access_token") ?? ""
        guard !jwt.isEmpty else { throw DebugError.notLoggedIn }

        let baseURL = SupabaseConfig.baseURL
        guard let url = URL(string: "\(baseURL)/auth/v1/user") else { throw DebugError.networkError }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DebugError.notLoggedIn
        }
        struct UserResp: Decodable { let id: String }
        let userResp = try JSONDecoder().decode(UserResp.self, from: data)
        return userResp.id
    }

    // MARK: - リセット

    func resetAll() {
        Task { @MainActor in
            await setProMode(false)
        }
    }
}

enum DebugError: LocalizedError {
    case notLoggedIn
    case networkError

    var errorDescription: String? {
        switch self {
        case .notLoggedIn: return "Discordにログインしていません"
        case .networkError: return "ネットワークエラー"
        }
    }
}

#else

final class DebugSettings {
    static let shared = DebugSettings()
    var isProMode: Bool { false }
    var isWorking: Bool { false }
    var lastError: String? { nil }
}

#endif
