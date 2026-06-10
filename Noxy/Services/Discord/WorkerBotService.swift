import Foundation

// MARK: - WorkerBotService
// Worker の /bot/status と /bot/ping を使って Bot 状態を確認する。
// /bot/status が Discord API に依存するため、Rate Limit や一時的なエラーで
// 誤ってオフライン判定になることを防ぐため、/bot/ping によるフォールバックを行う。

struct WorkerBotService: BotServiceProtocol {
    private let client = WorkerClient()

    func fetchStatus() async throws -> BotStatus {
        let workerURL = DiscordConfig.workerURL

        guard let statusURL = URL(string: "\(workerURL)/bot/status") else {
            throw ServiceError.networkError
        }
        // /bot/status は認証不要エンドポイント
        let req = URLRequest(url: statusURL, timeoutInterval: 10)
        let start = Date()
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                throw ServiceError.networkError
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let isOnline = json?["isOnline"] as? Bool ?? false

            // /bot/status が offline を返しても、Worker 自体が生きていれば
            // /bot/ping でフォールバック確認する（Discord API の一時的エラー対策）
            if !isOnline {
                if let pingURL = URL(string: "\(workerURL)/bot/ping") {
                    if let (_, pingResp) = try? await URLSession.shared.data(from: pingURL),
                       (pingResp as? HTTPURLResponse)?.statusCode == 200 {
                        return BotStatus(isOnline: true, latency: latency, uptime: 0, activeGuilds: 0, totalCommands: 0)
                    }
                }
            }

            return BotStatus(isOnline: isOnline, latency: latency, uptime: 0, activeGuilds: 0, totalCommands: 0)
        } catch {
            // フォールバック: /bot/ping
            if let pingURL = URL(string: "\(workerURL)/bot/ping") {
                if let (_, pingResp) = try? await URLSession.shared.data(from: pingURL),
                   (pingResp as? HTTPURLResponse)?.statusCode == 200 {
                    return BotStatus(isOnline: true, latency: 0, uptime: 0, activeGuilds: 0, totalCommands: 0)
                }
            }
            throw ServiceError.networkError
        }
    }

    func restart() async throws {
        try await client.post("/bot/restart")
    }

    func fetchCommands() async throws -> [SlashCommand] {
        // Worker には /bot/commands エンドポイントがないため、モックデータを返す
        return []
    }

    func toggleCommand(id: String, enabled: Bool) async throws {
        // Worker には対応エンドポイントがないため何もしない
    }
}
