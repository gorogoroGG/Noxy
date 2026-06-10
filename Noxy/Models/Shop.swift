import SwiftUI

// MARK: - ShopType

enum ShopType: String, Codable, CaseIterable, Sendable {
    case shop = "shop"
    case vendingMachine = "vending_machine"

    var label: String {
        switch self {
        case .shop: return "ショップ"
        case .vendingMachine: return "自販機"
        }
    }

    var icon: String {
        switch self {
        case .shop: return "cart.fill"
        case .vendingMachine: return "storefront.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .shop: return .accentIndigo
        case .vendingMachine: return .accentGreen
        }
    }
}

// MARK: - Shop

struct Shop: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var guildId: String
    var shopType: ShopType
    var name: String
    var description: String
    var enabled: Bool
    var disabledMessage: String?
    var channelId: String
    var messageId: String?
    var orderCategoryId: String?
    var archiveCategoryId: String?
    var supportRoleId: String?
    var timeoutHours: Int?
    var color: Int
    var footerText: String
    var reviewEnabled: Bool
    var reviewChannelId: String?
    var welcomeImageUrl: String?
    var welcomeThumbnailUrl: String?
    var welcomeFields: [EmbedFieldModel]
    var welcomeFooterText: String?
    var welcomeFooterIconUrl: String?
    var welcomeShowTimestamp: Bool
    /// 自販機のみ使用。購入時の支払い入力欄に表示する案内文
    var paymentInputLabel: String?
    var autoDeleteEnabled: Bool
    var autoDeleteDays: Int?
    let createdAt: Date

    var isDeployed: Bool { messageId != nil && !(messageId!.isEmpty) }

    nonisolated static func blank(guildId: String, shopType: ShopType = .shop) -> Shop {
        Shop(
            id: UUID().uuidString,
            guildId: guildId,
            shopType: shopType,
            name: shopType == .vendingMachine ? "自販機" : "ショップ",
            description: shopType == .vendingMachine
                ? "商品を選択し、支払い情報を送信してください。"
                : "商品を選択して購入してください。",
            enabled: true,
            disabledMessage: nil,
            channelId: "",
            messageId: nil,
            orderCategoryId: nil,
            archiveCategoryId: nil,
            supportRoleId: nil,
            timeoutHours: nil,
            color: shopType == .vendingMachine ? 0x10b981 : 0x6366f1,
            footerText: "",
            reviewEnabled: false,
            reviewChannelId: nil,
            welcomeImageUrl: nil,
            welcomeThumbnailUrl: nil,
            welcomeFields: [],
            welcomeFooterText: nil,
            welcomeFooterIconUrl: nil,
            welcomeShowTimestamp: true,
            paymentInputLabel: shopType == .vendingMachine ? "PayPayの受け取りURLを入力してください" : nil,
            autoDeleteEnabled: false,
            autoDeleteDays: nil,
            createdAt: .now
        )
    }
}

// MARK: - Product

struct Product: Identifiable, Codable, Hashable {
    let id: String
    var shopId: String
    var name: String
    var description: String
    var priceDisplay: String
    var imageUrl: String?
    var stock: Int?
    var rewardType: RewardType
    var rewardContent: String?
    var rewardRoleId: String?
    var rewardDmContent: String?
    var position: Int
    var enabled: Bool
    let createdAt: Date

    var isSoldOut: Bool {
        guard let stock else { return false }
        return stock <= 0
    }
}

// MARK: - RewardType

enum RewardType: String, Codable, CaseIterable {
    case text = "text"
    case url = "url"
    case role = "role"
    case dm = "dm"
    case manual = "manual"

    var label: String {
        switch self {
        case .text: return "テキスト"
        case .url: return "URL"
        case .role: return "ロール付与"
        case .dm: return "DM送信"
        case .manual: return "手動配達"
        }
    }

    var icon: String {
        switch self {
        case .text: return "text.alignleft"
        case .url: return "link"
        case .role: return "shield.fill"
        case .dm: return "message.fill"
        case .manual: return "hand.raised.fill"
        }
    }
}

// MARK: - OrderStatus

enum OrderStatus: String, Codable, CaseIterable {
    case open
    case paid
    case completed
    case cancelled
    case disputed
    case archived
    case delivered  // 後方互換性のため保持

    var label: String {
        switch self {
        case .open: return "注文受付中"
        case .paid: return "取引完了"
        case .completed: return "取引完了"
        case .cancelled: return "キャンセル"
        case .disputed: return "異議あり"
        case .archived: return "アーカイブ済"
        case .delivered: return "商品引渡済"
        }
    }

    var icon: String {
        switch self {
        case .open: return "cart.fill"
        case .paid: return "checkmark.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .disputed: return "exclamationmark.triangle.fill"
        case .archived: return "archivebox.fill"
        case .delivered: return "shippingbox.fill"
        }
    }

    var chipColor: Color {
        switch self {
        case .open: return .accentOrange
        case .paid: return .accentGreen
        case .completed: return .accentGreen
        case .cancelled: return Color.textTertiary
        case .disputed: return .red
        case .archived: return Color.textTertiary
        case .delivered: return .accentPurple
        }
    }
}

// MARK: - Order

struct Order: Identifiable, Codable, Hashable {
    let id: String
    let shopId: String
    let productId: String
    let guildId: String
    var channelId: String
    let buyerUserId: String
    let buyerUsername: String
    let productName: String
    let productPriceDisplay: String
    var status: OrderStatus
    var buyerConfirmed: Bool
    var sellerConfirmed: Bool
    var buyerCancelRequested: Bool
    var sellerCancelRequested: Bool
    var paymentUrl: String?
    var paymentSubmittedAt: Date?
    let createdAt: Date
    var paidAt: Date?
    var deliveredAt: Date?
    var completedAt: Date?
    var cancelledAt: Date?
    var archivedAt: Date?
    var autoDeleteAt: Date?
}
