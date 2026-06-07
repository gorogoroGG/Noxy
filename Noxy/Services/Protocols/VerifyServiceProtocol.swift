struct ChannelPermissionInput: Encodable {
    var channelId: String
    var allow: String   // Discord permission bits as string
    var deny: String
}

struct CreatedRole: Decodable {
    let id: String
    let name: String
    let color: Int
}

protocol VerifyServiceProtocol: Sendable {
    func fetchPanels(guildId: String) async throws -> [VerifyPanel]
    func createPanel(_ panel: VerifyPanel) async throws -> VerifyPanel
    func updatePanel(_ panel: VerifyPanel) async throws -> VerifyPanel
    func deletePanel(id: String) async throws
    func deployPanel(id: String, channelId: String) async throws -> VerifyPanel
    func resetPanel(id: String) async throws -> VerifyPanel

    // ロール作成
    func createRole(guildId: String, name: String, color: Int,
                    channelPermissions: [ChannelPermissionInput]) async throws -> CreatedRole

    // 手動認証リクエスト
    func fetchRequests(guildId: String, status: VerifyRequestStatus?) async throws -> [VerifyRequest]
    func approveRequest(id: String) async throws -> VerifyRequest
    func denyRequest(id: String) async throws -> VerifyRequest
}
