import Foundation

// MARK: - SubscriptionStatus

struct SubscriptionStatus: Codable, Hashable {
    let purchasedSlots: Int
    let usedSlots: Int
    let productId: String?
    let expiresAt: Date?
    let activatedGuildIds: [String]

    nonisolated var isUnlimited: Bool { purchasedSlots >= 99 }
    nonisolated var availableSlots: Int { isUnlimited ? 99 : max(0, purchasedSlots - usedSlots) }
    nonisolated var isActive: Bool { purchasedSlots > 0 && !isExpired }
    nonisolated var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }

    var isPro: Bool { isActive }

    nonisolated static let inactive = SubscriptionStatus(
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
    var isAnnual: Bool = false
    var savingsLabel: String? = nil
    var monthlyEquivalentLabel: String? = nil

    var slotsLabel: String { slots >= 99 ? "無制限" : "\(slots)" }
    var periodSuffix: String { isAnnual ? "/年" : "/月" }

    static let catalog: [SubscriptionProduct] = [
        // 月額
        SubscriptionProduct(id: "jp.noxyapp.stat.starter",
                            slots: 1,  priceLabel: "¥480/月",    planName: "スターター"),
        SubscriptionProduct(id: "jp.noxyapp.stat.standard",
                            slots: 3,  priceLabel: "¥980/月",    planName: "スタンダード",
                            isRecommended: true),
        SubscriptionProduct(id: "jp.noxyapp.stat.pro",
                            slots: 99, priceLabel: "¥1,980/月",  planName: "プロ"),
        // 年額
        SubscriptionProduct(id: "jp.noxyapp.stat.starter.annual",
                            slots: 1,  priceLabel: "¥3,800/年",  planName: "スターター",
                            isAnnual: true, savingsLabel: "34%オフ",
                            monthlyEquivalentLabel: "月あたり約¥317"),
        SubscriptionProduct(id: "jp.noxyapp.stat.standard.annual",
                            slots: 3,  priceLabel: "¥7,800/年",  planName: "スタンダード",
                            isRecommended: true, isAnnual: true, savingsLabel: "34%オフ",
                            monthlyEquivalentLabel: "月あたり約¥650"),
        SubscriptionProduct(id: "jp.noxyapp.stat.pro.annual",
                            slots: 99, priceLabel: "¥14,800/年", planName: "プロ",
                            isAnnual: true, savingsLabel: "38%オフ",
                            monthlyEquivalentLabel: "月あたり約¥1,233"),
    ]

    static var monthly: [SubscriptionProduct] { catalog.filter { !$0.isAnnual } }
    static var annual:  [SubscriptionProduct] { catalog.filter { $0.isAnnual } }
}
