import Foundation

// MARK: - WorkerTicketService
// Cloudflare Worker 経由でチケット操作を行うサービス。
// Worker が Supabase の読み書きと Discord API 操作を担う。

struct WorkerTicketService: TicketServiceProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Read

    func fetchAll(guildId: String) async throws -> [Ticket] {
        try await get("/bot/tickets?guild_id=\(guildId)")
    }

    func fetch(id: String) async throws -> Ticket {
        try await get("/bot/tickets/\(id)")
    }

    func fetchMessages(ticketId: String) async throws -> [TicketMessage] {
        try await get("/bot/tickets/\(ticketId)/messages")
    }

    // MARK: - Write (Discord + Supabase)

    func close(id: String) async throws {
        try await post("/bot/tickets/\(id)/close")
    }

    func reopen(id: String) async throws {
        try await post("/bot/tickets/\(id)/reopen")
    }

    func updatePriority(id: String, priority: TicketPriority) async throws {
        struct Body: Encodable { let priority: String }
        try await postBody("/bot/tickets/\(id)/priority", body: Body(priority: priority.rawValue))
    }

    func reply(ticketId: String, message: String) async throws {
        struct Body: Encodable { let content: String }
        try await postBody("/bot/tickets/\(ticketId)/reply", body: Body(content: message))
    }

    func assign(ticketId: String, userId: String) async throws {
        struct Body: Encodable { let userId: String }
        try await postBody("/bot/tickets/\(ticketId)/assign", body: Body(userId: userId))
    }

    // MARK: - HTTP helpers

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fmt.date(from: str) { return date }
            fmt.formatOptions = [.withInternetDateTime]
            if let date = fmt.date(from: str) { return date }
            return Date()
        }
        return d
    }()

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = URL(string: DiscordConfig.workerURL + path)!
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
        return try Self.decoder.decode(T.self, from: data)
    }

    private func post(_ path: String) async throws {
        let url = URL(string: DiscordConfig.workerURL + path)!
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
    }

    private func postBody(_ path: String, body: some Encodable) async throws {
        let url = URL(string: DiscordConfig.workerURL + path)!
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
    }
}
