import Foundation

protocol TempVCSourceServiceProtocol: Sendable {
    func fetchSources(guildId: String) async throws -> [TempVCSource]
    func createSource(_ source: TempVCSource) async throws -> TempVCSource
    func updateSource(_ source: TempVCSource) async throws -> TempVCSource
    func deleteSource(id: String) async throws
    func createTriggerVc(id: String, guildId: String, triggerVcName: String, vcCategoryId: String) async throws -> TempVCSource
    func hideTriggerVc(id: String, guildId: String, triggerVcId: String) async throws
    func showTriggerVc(id: String, guildId: String, triggerVcId: String) async throws
}

struct WorkerTempVCSourceService: TempVCSourceServiceProtocol {
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

    func fetchSources(guildId: String) async throws -> [TempVCSource] {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/temp-vc-sources?guild_id=\(guildId)")!
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
        return try Self.decoder.decode([TempVCSource].self, from: data)
    }

    func createSource(_ source: TempVCSource) async throws -> TempVCSource {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/temp-vc-sources")!
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(source)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
        return try Self.decoder.decode(TempVCSource.self, from: data)
    }

    func updateSource(_ source: TempVCSource) async throws -> TempVCSource {
        guard let id = source.id else { throw ServiceError.invalidData }
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/temp-vc-sources/\(id)")!
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(source)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
        return try Self.decoder.decode(TempVCSource.self, from: data)
    }

    func deleteSource(id: String) async throws {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/temp-vc-sources/\(id)")!
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "DELETE"
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
    }

    func createTriggerVc(id: String, guildId: String, triggerVcName: String, vcCategoryId: String) async throws -> TempVCSource {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/temp-vc-sources/\(id)/create-trigger-vc")!
        struct Body: Encodable {
            let guildId: String
            let triggerVcName: String
            let vcCategoryId: String
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(Body(guildId: guildId, triggerVcName: triggerVcName, vcCategoryId: vcCategoryId))
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
        return try Self.decoder.decode(TempVCSource.self, from: data)
    }

    func hideTriggerVc(id: String, guildId: String, triggerVcId: String) async throws {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/temp-vc-sources/\(id)/hide-trigger-vc")!
        struct Body: Encodable {
            let guildId: String
            let triggerVcId: String
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(Body(guildId: guildId, triggerVcId: triggerVcId))
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
    }

    func showTriggerVc(id: String, guildId: String, triggerVcId: String) async throws {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/temp-vc-sources/\(id)/show-trigger-vc")!
        struct Body: Encodable {
            let guildId: String
            let triggerVcId: String
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(Body(guildId: guildId, triggerVcId: triggerVcId))
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
    }
}

struct MockTempVCSourceService: TempVCSourceServiceProtocol {
    func fetchSources(guildId: String) async throws -> [TempVCSource] {
        [
            TempVCSource(
                id: "1",
                guildId: guildId,
                triggerVcId: "vc1",
                triggerVcName: "🏠 一時VCを作ろう",
                vcCategoryId: "cat1",
                textChannelCategoryId: "cat2",
                vcNameFormat: "{user-name}のVC",
                channelNameFormat: "{user-name}の部屋",
                userLimit: 0,
                autoDelete: true,
                deleteDelayMinutes: 0,
                joinLeaveNotification: true,
                enabled: true,
                createdAt: Date()
            ),
        ]
    }

    func createSource(_ source: TempVCSource) async throws -> TempVCSource { source }
    func updateSource(_ source: TempVCSource) async throws -> TempVCSource { source }
    func deleteSource(id: String) async throws {}
    func createTriggerVc(id: String, guildId: String, triggerVcName: String, vcCategoryId: String) async throws -> TempVCSource {
        TempVCSource.defaultSource(guildId: guildId)
    }
    func hideTriggerVc(id: String, guildId: String, triggerVcId: String) async throws {}
    func showTriggerVc(id: String, guildId: String, triggerVcId: String) async throws {}
}
