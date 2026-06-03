import Foundation

// MARK: - SubscriptionStatus

struct SubscriptionStatus: Codable, Hashable {
    let purchasedSlots: Int
    let usedSlots: Int
    let productId: String?
    let expiresAt: Date?
    let activatedGuildIds: [String]

    // nonisolated にして actor / @MainActor 問わず参照可能にする
    nonisolated var availableSlots: Int { max(0, purchasedSlots - usedSlots) }
    nonisolated var isActive: Bool { purchasedSlots > 0 && !isExpired }
    nonisolated var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }

    static let inactive = SubscriptionStatus(
        purchasedSlots: 0, usedSlots: 0,
        productId: nil, expiresAt: nil, activatedGuildIds: []
    )
}

// MARK: - SubscriptionProduct

struct SubscriptionProduct: Identifiable, Hashable {
    let id: String          // App Store 製品 ID
    let slots: Int
    let priceLabel: String  // 表示価格 (StoreKit Product から取得後に上書き)

    static let catalog: [SubscriptionProduct] = [
        SubscriptionProduct(id: "jp.noxyapp.stat.1server", slots: 1, priceLabel: "¥100/月"),
        SubscriptionProduct(id: "jp.noxyapp.stat.2server", slots: 2, priceLabel: "¥200/月"),
        SubscriptionProduct(id: "jp.noxyapp.stat.3server", slots: 3, priceLabel: "¥300/月"),
        SubscriptionProduct(id: "jp.noxyapp.stat.5server", slots: 5, priceLabel: "¥500/月"),
    ]
}
