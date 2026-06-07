protocol VerifyServiceProtocol: Sendable {
    func fetchPanels(guildId: String) async throws -> [VerifyPanel]
    func createPanel(_ panel: VerifyPanel) async throws -> VerifyPanel
    func updatePanel(_ panel: VerifyPanel) async throws -> VerifyPanel
    func deletePanel(id: String) async throws
    func deployPanel(id: String, channelId: String) async throws -> VerifyPanel

    // 手動認証リクエスト
    func fetchRequests(guildId: String, status: VerifyRequestStatus?) async throws -> [VerifyRequest]
    func approveRequest(id: String) async throws -> VerifyRequest
    func denyRequest(id: String) async throws -> VerifyRequest
}
