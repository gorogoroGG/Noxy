import Foundation

protocol MemberServiceProtocol: Sendable {
    func fetchMembers(guildId: String) async throws -> [Member]
    func kick(memberId: String, guildId: String, reason: String?) async throws
    func ban(memberId: String, guildId: String, reason: String?) async throws
    func addRole(memberId: String, guildId: String, roleId: String) async throws
    func removeRole(memberId: String, guildId: String, roleId: String) async throws
}
