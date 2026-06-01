import Foundation

struct WorkerShopService: ShopServiceProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Shops

    func fetchShops(guildId: String) async throws -> [Shop] {
        try await get("/bot/shops?guild_id=\(guildId)")
    }

    func createShop(_ shop: Shop) async throws -> Shop {
        try await postReturning("/bot/shops", body: shop)
    }

    func updateShop(_ shop: Shop) async throws -> Shop {
        try await patchReturning("/bot/shops/\(shop.id)", body: shop)
    }

    func deleteShop(id: String) async throws {
        try await delete("/bot/shops/\(id)")
    }

    func deployShop(id: String, channelId: String) async throws -> Shop {
        struct Body: Encodable { let channelId: String }
        return try await postReturning("/bot/shops/\(id)/deploy", body: Body(channelId: channelId))
    }

    // MARK: - Products

    func fetchProducts(shopId: String) async throws -> [Product] {
        try await get("/bot/shops/\(shopId)/products")
    }

    func createProduct(_ product: Product) async throws -> Product {
        try await postReturning("/bot/shops/\(product.shopId)/products", body: product)
    }

    func updateProduct(_ product: Product) async throws -> Product {
        try await patchReturning("/bot/products/\(product.id)", body: product)
    }

    func deleteProduct(id: String) async throws {
        try await delete("/bot/products/\(id)")
    }

    // MARK: - Orders

    func fetchOrders(guildId: String, status: OrderStatus?) async throws -> [Order] {
        var path = "/bot/orders?guild_id=\(guildId)"
        if let status { path += "&status=\(status.rawValue)" }
        return try await get(path)
    }

    func fetchOrder(id: String) async throws -> Order {
        try await get("/bot/orders/\(id)")
    }

    func confirmPayment(orderId: String) async throws -> Order {
        try await postReturning("/bot/orders/\(orderId)/confirm-payment", body: EmptyBody())
    }

    func completeOrder(orderId: String, party: String) async throws -> Order {
        struct Body: Encodable { let party: String }
        return try await postReturning("/bot/orders/\(orderId)/complete", body: Body(party: party))
    }

    // MARK: - HTTP helpers

    private struct EmptyBody: Encodable {}

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

    private func delete(_ path: String) async throws {
        let url = URL(string: DiscordConfig.workerURL + path)!
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "DELETE"
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
    }

    private func patchReturning<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let url = URL(string: DiscordConfig.workerURL + path)!
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
        return try Self.decoder.decode(T.self, from: data)
    }

    private func postReturning<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let url = URL(string: DiscordConfig.workerURL + path)!
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
        return try Self.decoder.decode(T.self, from: data)
    }
}
