import Foundation

// MARK: - WorkerTicketService

struct WorkerTicketService: TicketServiceProtocol {
    private let client = WorkerClient()

    // MARK: - Read

    func fetchAll(guildId: String) async throws -> [Ticket] {
        try await client.get("/bot/tickets?guild_id=\(guildId)")
    }

    func fetch(id: String) async throws -> Ticket {
        try await client.get("/bot/tickets/\(id)")
    }

    func fetchMessages(ticketId: String) async throws -> [TicketMessage] {
        try await client.get("/bot/tickets/\(ticketId)/messages")
    }

    // MARK: - Write

    func close(id: String) async throws {
        try await client.post("/bot/tickets/\(id)/close")
    }

    func reopen(id: String) async throws {
        try await client.post("/bot/tickets/\(id)/reopen")
    }

    func setStatus(id: String, status: TicketStatus) async throws {
        struct Body: Encodable { let status: String }
        try await client.postVoid("/bot/tickets/\(id)/status", body: Body(status: status.rawValue))
    }

    func updatePriority(id: String, priority: TicketPriority) async throws {
        struct Body: Encodable { let priority: String }
        try await client.postVoid("/bot/tickets/\(id)/priority", body: Body(priority: priority.rawValue))
    }

    func reply(ticketId: String, message: String) async throws {
        struct Body: Encodable { let content: String }
        try await client.postVoid("/bot/tickets/\(ticketId)/reply", body: Body(content: message))
    }

    func assign(ticketId: String, userId: String) async throws {
        struct Body: Encodable { let userId: String }
        try await client.postVoid("/bot/tickets/\(ticketId)/assign", body: Body(userId: userId))
    }

    func create(guildId: String, subject: String) async throws -> Ticket {
        struct Body: Encodable { let guildId: String; let subject: String }
        return try await client.post("/bot/tickets/create", body: Body(guildId: guildId, subject: subject))
    }

    // MARK: - Panels

    func fetchPanels(guildId: String) async throws -> [TicketPanel] {
        try await client.get("/bot/ticket-panels?guild_id=\(guildId)")
    }

    func createPanel(_ panel: TicketPanel) async throws -> TicketPanel {
        try await client.post("/bot/ticket-panels", body: panel)
    }

    func updatePanel(_ panel: TicketPanel) async throws -> TicketPanel {
        try await client.patch("/bot/ticket-panels/\(panel.id)", body: panel)
    }

    func deletePanel(id: String) async throws {
        try await client.delete("/bot/ticket-panels/\(id)")
    }

    func deployPanel(id: String, channelId: String) async throws -> TicketPanel {
        struct Body: Encodable { let channelId: String }
        return try await client.post("/bot/ticket-panels/\(id)/deploy", body: Body(channelId: channelId))
    }
}
