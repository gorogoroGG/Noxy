import Foundation

protocol TicketServiceProtocol: Sendable {
    func fetchAll(guildId: String) async throws -> [Ticket]
    func fetch(id: String) async throws -> Ticket
    func close(id: String) async throws
    func reopen(id: String) async throws
    func updatePriority(id: String, priority: TicketPriority) async throws
    func reply(ticketId: String, message: String) async throws
}
