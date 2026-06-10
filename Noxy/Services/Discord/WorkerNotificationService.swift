import Foundation

// Worker からオープンチケット・注文をフェッチして AppNotification に変換する。
// guildId は呼び出し側から渡す必要があるが、プロトコルの制約上 UserDefaults から読む。
struct WorkerNotificationService: NotificationServiceProtocol {
    private let client = WorkerClient()

    // 既読・削除は端末ローカルで管理する（UserDefaults）
    private static let readKey    = "notif_read_ids_v1"
    private static let deletedKey = "notif_deleted_ids_v1"

    private func readIds() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.readKey) ?? [])
    }

    private func deletedIds() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.deletedKey) ?? [])
    }

    func fetchAll() async throws -> [AppNotification] {
        let guildId = UserDefaults.standard.string(forKey: "selected_guild_id") ?? ""
        guard !guildId.isEmpty else { return [] }

        async let ticketsTask = fetchTicketNotifs(guildId: guildId)
        async let ordersTask  = fetchOrderNotifs(guildId: guildId)
        let (tickets, orders) = await (ticketsTask, ordersTask)

        let deleted = deletedIds()
        let read    = readIds()
        return (tickets + orders)
            .filter { !deleted.contains($0.id) }
            .sorted { $0.timestamp > $1.timestamp }
            .map { notif in
                AppNotification(
                    id: notif.id, type: notif.type, title: notif.title,
                    body: notif.body, guildId: notif.guildId,
                    read: read.contains(notif.id),
                    timestamp: notif.timestamp
                )
            }
    }

    func markRead(id: String) async throws {
        var ids = readIds()
        ids.insert(id)
        UserDefaults.standard.set(Array(ids), forKey: Self.readKey)
    }

    func markAllRead() async throws {
        let all = (try? await fetchAll()) ?? []
        var ids = readIds()
        all.forEach { ids.insert($0.id) }
        UserDefaults.standard.set(Array(ids), forKey: Self.readKey)
    }

    func delete(id: String) async throws {
        var ids = deletedIds()
        ids.insert(id)
        let stored = Array(ids).suffix(2000)
        UserDefaults.standard.set(Array(stored), forKey: Self.deletedKey)
    }

    // MARK: - Private helpers

    private struct RawNotif {
        let id: String; let type: NotificationType; let title: String
        let body: String; let guildId: String?; let timestamp: Date
    }

    private func fetchTicketNotifs(guildId: String) async -> [RawNotif] {
        struct T: Decodable {
            let id: String; let subject: String; let openedAt: String
            enum CodingKeys: String, CodingKey {
                case id, subject; case openedAt = "opened_at"
            }
        }
        let fmt  = ISO8601DateFormatter()
        let fmt2: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }()
        guard let tickets: [T] = try? await client.get("/bot/tickets?guild_id=\(guildId)&status=open") else { return [] }
        return tickets.map { t in
            let date = fmt2.date(from: t.openedAt) ?? fmt.date(from: t.openedAt) ?? .now
            return RawNotif(id: "ticket_\(t.id)", type: .ticket,
                            title: "チケット: \(t.subject)",
                            body: "新着チケットが開設されました", guildId: guildId, timestamp: date)
        }
    }

    private func fetchOrderNotifs(guildId: String) async -> [RawNotif] {
        struct O: Decodable {
            let id: String; let productName: String; let createdAt: String
            enum CodingKeys: String, CodingKey {
                case id; case productName = "product_name"; case createdAt = "created_at"
            }
        }
        let fmt  = ISO8601DateFormatter()
        let fmt2: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }()
        guard let orders: [O] = try? await client.get("/bot/orders?guild_id=\(guildId)&status=pending") else { return [] }
        return orders.map { o in
            let date = fmt2.date(from: o.createdAt) ?? fmt.date(from: o.createdAt) ?? .now
            return RawNotif(id: "order_\(o.id)", type: .system,
                            title: "注文: \(o.productName)",
                            body: "新規注文が届きました", guildId: guildId, timestamp: date)
        }
    }
}
