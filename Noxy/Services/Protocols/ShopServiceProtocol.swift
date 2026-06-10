import Foundation

protocol ShopServiceProtocol: Sendable {
    // ── ショップ ──
    func fetchShops(guildId: String) async throws -> [Shop]
    func createShop(_ shop: Shop) async throws -> Shop
    func updateShop(_ shop: Shop) async throws -> Shop
    func deleteShop(id: String) async throws
    func deployShop(id: String, channelId: String) async throws -> Shop

    // ── 商品 ──
    func fetchProducts(shopId: String) async throws -> [Product]
    func createProduct(_ product: Product) async throws -> Product
    func updateProduct(_ product: Product) async throws -> Product
    func deleteProduct(id: String) async throws

    // ── 注文 ──
    func fetchOrders(guildId: String, status: OrderStatus?) async throws -> [Order]
    func fetchOrder(id: String) async throws -> Order
    func confirmPayment(orderId: String) async throws -> Order
    func completeOrder(orderId: String, party: String) async throws -> Order
    func archiveOrder(orderId: String) async throws -> Order
}
