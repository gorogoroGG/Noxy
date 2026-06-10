import Foundation
import StoreKit

// MARK: - WorkerSubscriptionService
// StoreKit 2 で課金し、Worker の /billing/* エンドポイントでサーバー側と同期する。

struct WorkerSubscriptionService: SubscriptionServiceProtocol {
    private let client = WorkerClient()

    // MARK: - Fetch Status

    func fetchStatus(discordUserId: String) async throws -> SubscriptionStatus {
        guard !discordUserId.isEmpty else { return .inactive }
        return try await client.get("/billing/status?discord_user_id=\(discordUserId)")
    }

    // MARK: - Purchase (StoreKit 2)

    func purchase(productId: String) async throws -> SubscriptionStatus {
        // StoreKit から製品を取得（Shop.Product との曖昧性を回避）
        let products = try await StoreKit.Product.products(for: [productId])
        guard let product = products.first else { throw ServiceError.notFound }

        // 購入を実行
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verification.payloadValue
            defer { Task { await transaction.finish() } }
            return try await syncEntitlement(transaction: transaction)

        case .userCancelled:
            throw SubscriptionError.cancelled

        case .pending:
            throw SubscriptionError.pending

        @unknown default:
            throw ServiceError.networkError
        }
    }

    // MARK: - Restore

    func restore() async throws -> SubscriptionStatus {
        // App Store と同期して最新のエンタイトルメントを確認
        try await AppStore.sync()

        // 有効なエンタイトルメントを走査
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                return try await syncEntitlement(transaction: transaction)
            }
        }
        // 有効なエンタイトルメントなし
        return .inactive
    }

    // MARK: - Server Activation

    func activateServer(guildId: String) async throws {
        struct Body: Encodable {
            let guildId: String
            let discordUserId: String
            let supabaseJwt: String
        }
        let jwt     = KeychainHelper.load(forKey: "supabase_access_token") ?? ""
        let userId  = KeychainHelper.load(forKey: "discord_user_id") ?? ""

        guard let url = URL(string: "\(DiscordConfig.workerURL)/billing/activate") else {
            throw ServiceError.networkError
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !jwt.isEmpty { req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONEncoder().encode(Body(guildId: guildId, discordUserId: userId, supabaseJwt: jwt))

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.networkError
        }
        switch http.statusCode {
        case 200..<300: return
        case 401:
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.unauthorizedWithDetail(msg)
        default:
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.workerError(status: http.statusCode, message: msg)
        }
    }

    // MARK: - Server Deactivation

    func deactivateServer(guildId: String) async throws {
        let userId = KeychainHelper.load(forKey: "discord_user_id") ?? ""
        let jwt    = KeychainHelper.load(forKey: "supabase_access_token") ?? ""
        guard let url = URL(string:
            "\(DiscordConfig.workerURL)/billing/activate/\(guildId)?discord_user_id=\(userId)"
        ) else { throw ServiceError.networkError }

        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "DELETE"
        if !jwt.isEmpty { req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization") }
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
    }

    // MARK: - Internal: Entitlement Sync

    /// StoreKit トランザクションを Worker に通知して user_profiles を更新する
    private func syncEntitlement(transaction: Transaction) async throws -> SubscriptionStatus {
        struct EntitlementBody: Encodable {
            let discordUserId: String
            let productId: String
            let expiresAt: String?
            let jwsToken: String
            let supabaseJwt: String
        }

        let discordUserId = KeychainHelper.load(forKey: "discord_user_id") ?? ""
        let supabaseJwt   = KeychainHelper.load(forKey: "supabase_access_token") ?? ""

        // JWS トークン（Apple 署名済み）を取得
        // StoreKit 2: jsonRepresentation は Data 型
        let jwsToken = String(data: transaction.jsonRepresentation, encoding: .utf8) ?? ""

        let expiresAt = transaction.expirationDate.map {
            ISO8601DateFormatter().string(from: $0)
        }

        let body = EntitlementBody(
            discordUserId: discordUserId,
            productId:     transaction.productID,
            expiresAt:     expiresAt,
            jwsToken:      jwsToken,
            supabaseJwt:   supabaseJwt
        )

        guard let url = URL(string: "\(DiscordConfig.workerURL)/billing/entitlement") else {
            throw ServiceError.networkError
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !supabaseJwt.isEmpty { req.setValue("Bearer \(supabaseJwt)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.networkError
        }
        switch http.statusCode {
        case 200..<300:
            // 最新のステータスを取得して返す
            return try await fetchStatus(discordUserId: discordUserId)
        case 401:
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.unauthorizedWithDetail(msg)
        default:
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.workerError(status: http.statusCode, message: msg)
        }
    }
}

// MARK: - Errors

enum SubscriptionError: LocalizedError {
    case cancelled
    case pending

    var errorDescription: String? {
        switch self {
        case .cancelled: return "購入がキャンセルされました"
        case .pending:   return "購入の承認待ちです"
        }
    }
}
