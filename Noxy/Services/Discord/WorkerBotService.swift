import Foundation

// MARK: - WorkerBotService
// Worker の /bot/status と /bot/ping を使って Bot 状態を確認する。
// /bot/status が Discord API に依存するため、Rate Limit や一時的なエラーで
// 誤ってオフライン判定になることを防ぐため、/bot/ping によるフォールバックを行う。

struct WorkerBotService: BotServiceProtocol {
    private let client = WorkerClient()

    func fetchStatus() async throws -> BotStatus {
        let workerURL = DiscordConfig.workerURL
        let apiSecret = DiscordConfig.workerAPISecret

        guard let statusURL = URL(string: "\(workerURL)/bot/status") else {
            throw ServiceError.networkError
        }
        var req = URLRequest(url: statusURL, timeoutInterval: 10)
        if !apiSecret.isEmpty {
            req.setValue(apiSecret, forHTTPHeaderField: "X-Bot-Secret")
        }
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
        guard let url = URL(string: DiscordConfig.workerURL + "/bot/restart") else {
            throw ServiceError.networkError
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if !DiscordConfig.workerAPISecret.isEmpty {
            req.setValue(DiscordConfig.workerAPISecret, forHTTPHeaderField: "X-Bot-Secret")
        }
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw ServiceError.networkError
        }
    }

    func fetchCommands() async throws -> [SlashCommand] {
        // Worker には /bot/commands エンドポイントがないため、モックデータを返す
        return []
    }

    func toggleCommand(id: String, enabled: Bool) async throws {
        // Worker には対応エンドポイントがないため何もしない
    }
}
