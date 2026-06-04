import Foundation

// MARK: - SubscriptionStatus

struct SubscriptionStatus: Codable, Hashable {
    let purchasedSlots: Int
    let usedSlots: Int
    let productId: String?
    let expiresAt: Date?
    let activatedGuildIds: [String]

    nonisolated var availableSlots: Int { max(0, purchasedSlots - usedSlots) }
    nonisolated var isActive: Bool { purchasedSlots > 0 && !isExpired }
    nonisolated var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }

    var isPro: Bool { isActive }

    static let inactive = SubscriptionStatus(
        purchasedSlots: 0, usedSlots: 0,
        productId: nil, expiresAt: nil, activatedGuildIds: []
    )
}

// MARK: - SubscriptionProduct

struct SubscriptionProduct: Identifiable, Hashable {
    let id: String
    let slots: Int
    let priceLabel: String
    let planName: String
    var isRecommended: Bool = false

    static let catalog: [SubscriptionProduct] = [
        SubscriptionProduct(id: "jp.noxyapp.stat.starter",  slots: 1, priceLabel: "$1.99/mo", planName: "スターター"),
        SubscriptionProduct(id: "jp.noxyapp.stat.standard", slots: 3, priceLabel: "$4.99/mo", planName: "スタンダード", isRecommended: true),
        SubscriptionProduct(id: "jp.noxyapp.stat.pro",      slots: 5, priceLabel: "$7.99/mo", planName: "プロ"),
    ]
}
