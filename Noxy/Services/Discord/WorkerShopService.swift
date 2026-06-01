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
        struct Body: Encodable {
            let guildId: String
            let name: String
            let description: String
            let enabled: Bool
            let disabledMessage: String?
            let channelId: String
            let orderCategoryId: String?
            let archiveCategoryId: String?
            let supportRoleId: String?
            let timeoutHours: Int?
            let color: Int
            let footerText: String
            let paymentFlow: String
            let autoDeliver: Bool
            let welcomeImageUrl: String?
            let welcomeThumbnailUrl: String?
            let welcomeFields: [EmbedFieldModel]
            let welcomeFooterText: String?
            let welcomeFooterIconUrl: String?
            let welcomeShowTimestamp: Bool
        }
        let body = Body(
            guildId: shop.guildId, name: shop.name, description: shop.description,
            enabled: shop.enabled, disabledMessage: shop.disabledMessage,
            channelId: shop.channelId,
            orderCategoryId: shop.orderCategoryId, archiveCategoryId: shop.archiveCategoryId,
            supportRoleId: shop.supportRoleId, timeoutHours: shop.timeoutHours,
            color: shop.color, footerText: shop.footerText,
            paymentFlow: shop.paymentFlow.rawValue, autoDeliver: shop.autoDeliver,
            welcomeImageUrl: shop.welcomeImageUrl, welcomeThumbnailUrl: shop.welcomeThumbnailUrl,
            welcomeFields: shop.welcomeFields,
            welcomeFooterText: shop.welcomeFooterText, welcomeFooterIconUrl: shop.welcomeFooterIconUrl,
            welcomeShowTimestamp: shop.welcomeShowTimestamp
        )
        let jsonData = try JSONEncoder().encode(body)
        if let jsonStr = String(data: jsonData, encoding: .utf8) {
            print("[ShopService] createShop body: \(jsonStr)")
        }
        return try await postReturning("/bot/shops", body: body)
    }

    func updateShop(_ shop: Shop) async throws -> Shop {
        struct Body: Encodable {
            let name: String
            let description: String
            let enabled: Bool
            let disabledMessage: String?
            let channelId: String
            let orderCategoryId: String?
            let archiveCategoryId: String?
            let supportRoleId: String?
            let timeoutHours: Int?
            let color: Int
            let footerText: String
            let paymentFlow: String
            let autoDeliver: Bool
            let welcomeImageUrl: String?
            let welcomeThumbnailUrl: String?
            let welcomeFields: [EmbedFieldModel]
            let welcomeFooterText: String?
            let welcomeFooterIconUrl: String?
            let welcomeShowTimestamp: Bool
        }
        let body = Body(
            name: shop.name, description: shop.description, enabled: shop.enabled,
            disabledMessage: shop.disabledMessage,
            channelId: shop.channelId, orderCategoryId: shop.orderCategoryId,
            archiveCategoryId: shop.archiveCategoryId, supportRoleId: shop.supportRoleId,
            timeoutHours: shop.timeoutHours, color: shop.color, footerText: shop.footerText,
            paymentFlow: shop.paymentFlow.rawValue, autoDeliver: shop.autoDeliver,
            welcomeImageUrl: shop.welcomeImageUrl, welcomeThumbnailUrl: shop.welcomeThumbnailUrl,
            welcomeFields: shop.welcomeFields,
            welcomeFooterText: shop.welcomeFooterText, welcomeFooterIconUrl: shop.welcomeFooterIconUrl,
            welcomeShowTimestamp: shop.welcomeShowTimestamp
        )
        return try await patchReturning("/bot/shops/\(shop.id)", body: body)
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
        struct Body: Encodable {
            let shopId: String
            let name: String
            let description: String
            let priceDisplay: String
            let imageUrl: String?
            let stock: Int?
            let rewardType: String
            let rewardContent: String?
            let rewardRoleId: String?
            let rewardDmContent: String?
            let position: Int
            let enabled: Bool
        }
        let body = Body(
            shopId: product.shopId, name: product.name, description: product.description,
            priceDisplay: product.priceDisplay, imageUrl: product.imageUrl, stock: product.stock,
            rewardType: product.rewardType.rawValue, rewardContent: product.rewardContent,
            rewardRoleId: product.rewardRoleId, rewardDmContent: product.rewardDmContent,
            position: product.position, enabled: product.enabled
        )
        return try await postReturning("/bot/shops/\(product.shopId)/products", body: body)
    }

    func updateProduct(_ product: Product) async throws -> Product {
        struct Body: Encodable {
            let name: String
            let description: String
            let priceDisplay: String
            let imageUrl: String?
            let stock: Int?
            let rewardType: String
            let rewardContent: String?
            let rewardRoleId: String?
            let rewardDmContent: String?
            let position: Int
            let enabled: Bool
        }
        let body = Body(
            name: product.name, description: product.description, priceDisplay: product.priceDisplay,
            imageUrl: product.imageUrl, stock: product.stock, rewardType: product.rewardType.rawValue,
            rewardContent: product.rewardContent, rewardRoleId: product.rewardRoleId,
            rewardDmContent: product.rewardDmContent, position: product.position, enabled: product.enabled
        )
        return try await patchReturning("/bot/products/\(product.id)", body: body)
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
        guard let http = resp as? HTTPURLResponse else {
            print("[ShopService] postReturning: no HTTP response for \(path)")
            throw ServiceError.networkError
        }
        if !(200..<300).contains(http.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[ShopService] postReturning FAILED: \(path) -> status \(http.statusCode), body: \(errorBody)")
            throw ServiceError.networkError
        }
        print("[ShopService] postReturning OK: \(path) -> status \(http.statusCode)")
        return try Self.decoder.decode(T.self, from: data)
    }
}
