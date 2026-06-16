import Foundation

struct WorkerVCNotificationService: VCNotificationServiceProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchSettings(guildId: String) async throws -> VCNotificationSettings {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/vc-notification-settings?guild_id=\(guildId)")!
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
        return try JSONDecoder().decode(VCNotificationSettings.self, from: data)
    }

    func saveSettings(_ settings: VCNotificationSettings) async throws -> VCNotificationSettings {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/vc-notification-settings")!
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(settings)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
        return try JSONDecoder().decode(VCNotificationSettings.self, from: data)
    }
}
