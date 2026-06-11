import Foundation

struct WorkerShopService: ShopServiceProtocol {
    private let client = WorkerClient()

    // MARK: - Shops

    func fetchShops(guildId: String) async throws -> [Shop] {
        try await client.get("/bot/shops?guild_id=\(guildId)")
    }

    func createShop(_ shop: Shop) async throws -> Shop {
        struct Body: Encodable {
            let guildId: String
            let shopType: String
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
            let reviewEnabled: Bool
            let reviewChannelId: String?
            let welcomeImageUrl: String?
            let welcomeThumbnailUrl: String?
            let welcomeFields: [EmbedFieldModel]
            let welcomeFooterText: String?
            let welcomeFooterIconUrl: String?
            let welcomeShowTimestamp: Bool
            let paymentInputLabel: String?
            let autoDeleteEnabled: Bool
            let autoDeleteDays: Int?
        }
        let body = Body(
            guildId: shop.guildId, shopType: shop.shopType.rawValue,
            name: shop.name, description: shop.description,
            enabled: shop.enabled, disabledMessage: shop.disabledMessage,
            channelId: shop.channelId,
            orderCategoryId: shop.orderCategoryId, archiveCategoryId: shop.archiveCategoryId,
            supportRoleId: shop.supportRoleId, timeoutHours: shop.timeoutHours,
            color: shop.color, footerText: shop.footerText,
            reviewEnabled: shop.reviewEnabled, reviewChannelId: shop.reviewChannelId,
            welcomeImageUrl: shop.welcomeImageUrl, welcomeThumbnailUrl: shop.welcomeThumbnailUrl,
            welcomeFields: shop.welcomeFields,
            welcomeFooterText: shop.welcomeFooterText, welcomeFooterIconUrl: shop.welcomeFooterIconUrl,
            welcomeShowTimestamp: shop.welcomeShowTimestamp,
            paymentInputLabel: shop.paymentInputLabel,
            autoDeleteEnabled: shop.autoDeleteEnabled, autoDeleteDays: shop.autoDeleteDays
        )
        return try await client.post("/bot/shops", body: body)
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
            let reviewEnabled: Bool
            let reviewChannelId: String?
            let welcomeImageUrl: String?
            let welcomeThumbnailUrl: String?
            let welcomeFields: [EmbedFieldModel]
            let welcomeFooterText: String?
            let welcomeFooterIconUrl: String?
            let welcomeShowTimestamp: Bool
            let paymentInputLabel: String?
            let autoDeleteEnabled: Bool
            let autoDeleteDays: Int?
        }
        let body = Body(
            name: shop.name, description: shop.description, enabled: shop.enabled,
            disabledMessage: shop.disabledMessage,
            channelId: shop.channelId, orderCategoryId: shop.orderCategoryId,
            archiveCategoryId: shop.archiveCategoryId, supportRoleId: shop.supportRoleId,
            timeoutHours: shop.timeoutHours, color: shop.color, footerText: shop.footerText,
            reviewEnabled: shop.reviewEnabled, reviewChannelId: shop.reviewChannelId,
            welcomeImageUrl: shop.welcomeImageUrl, welcomeThumbnailUrl: shop.welcomeThumbnailUrl,
            welcomeFields: shop.welcomeFields,
            welcomeFooterText: shop.welcomeFooterText, welcomeFooterIconUrl: shop.welcomeFooterIconUrl,
            welcomeShowTimestamp: shop.welcomeShowTimestamp,
            paymentInputLabel: shop.paymentInputLabel,
            autoDeleteEnabled: shop.autoDeleteEnabled, autoDeleteDays: shop.autoDeleteDays
        )
        return try await client.patch("/bot/shops/\(shop.id)", body: body)
    }

    func deleteShop(id: String) async throws {
        try await client.delete("/bot/shops/\(id)")
    }

    func deployShop(id: String, channelId: String) async throws -> Shop {
        struct Body: Encodable { let channelId: String }
        return try await client.post("/bot/shops/\(id)/deploy", body: Body(channelId: channelId))
    }

    // MARK: - Products

    func fetchProducts(shopId: String) async throws -> [Product] {
        try await client.get("/bot/shops/\(shopId)/products")
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
        return try await client.post("/bot/shops/\(product.shopId)/products", body: body)
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
        return try await client.patch("/bot/products/\(product.id)", body: body)
    }

    func deleteProduct(id: String) async throws {
        try await client.delete("/bot/products/\(id)")
    }

    // MARK: - Orders

    func fetchOrders(guildId: String, status: OrderStatus?) async throws -> [Order] {
        var path = "/bot/orders?guild_id=\(guildId)"
        if let status { path += "&status=\(status.rawValue)" }
        return try await client.get(path)
    }

    func fetchOrder(id: String) async throws -> Order {
        try await client.get("/bot/orders/\(id)")
    }

    func confirmPayment(orderId: String) async throws -> Order {
        struct Empty: Encodable {}
        return try await client.post("/bot/orders/\(orderId)/confirm-payment", body: Empty())
    }

    func completeOrder(orderId: String, party: String) async throws -> Order {
        struct Body: Encodable { let party: String }
        return try await client.post("/bot/orders/\(orderId)/complete", body: Body(party: party))
    }

    func archiveOrder(orderId: String) async throws -> Order {
        struct Empty: Encodable {}
        return try await client.post("/bot/orders/\(orderId)/archive", body: Empty())
    }
}
