import Foundation

protocol TicketServiceProtocol: Sendable {
    // ── チケット ──
    func fetchAll(guildId: String) async throws -> [Ticket]
    func fetch(id: String) async throws -> Ticket
    func create(guildId: String, subject: String) async throws -> Ticket
    func close(id: String) async throws
    func reopen(id: String) async throws
    func updatePriority(id: String, priority: TicketPriority) async throws
    func fetchMessages(ticketId: String) async throws -> [TicketMessage]
    func reply(ticketId: String, message: String) async throws
    func assign(ticketId: String, userId: String) async throws

    // ── チケットパネル ──
    func fetchPanels(guildId: String) async throws -> [TicketPanel]
    func createPanel(_ panel: TicketPanel) async throws -> TicketPanel
    func updatePanel(_ panel: TicketPanel) async throws -> TicketPanel
    func deletePanel(id: String) async throws
    func deployPanel(id: String) async throws -> TicketPanel
}
