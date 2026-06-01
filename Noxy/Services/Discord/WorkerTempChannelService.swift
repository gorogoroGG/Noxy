import Foundation

struct WorkerTempChannelService: TempChannelServiceProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fmt.date(from: str) { return date }
            fmt.formatOptions = [.withInternetDateTime]
            return fmt.date(from: str) ?? Date()
        }
        return d
    }()

    func fetchSettings(guildId: String) async throws -> TempChannelSettings {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/temp-channel-settings?guild_id=\(guildId)")!
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
        return try Self.decoder.decode(TempChannelSettings.self, from: data)
    }

    func saveSettings(_ settings: TempChannelSettings) async throws -> TempChannelSettings {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/temp-channel-settings")!
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(settings)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
        return try Self.decoder.decode(TempChannelSettings.self, from: data)
    }

    func fetchActiveChannels(guildId: String) async throws -> [ActiveTempChannel] {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/temp-channels?guild_id=\(guildId)")!
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
        return try Self.decoder.decode([ActiveTempChannel].self, from: data)
    }
}
