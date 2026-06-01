import SwiftUI

// MARK: - Shop

struct Shop: Identifiable, Codable, Hashable {
    let id: String
    var guildId: String
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
    var paymentFlow: PaymentFlow
    var autoDeliver: Bool
    var welcomeImageUrl: String?
    var welcomeThumbnailUrl: String?
    var welcomeFields: [EmbedFieldModel]
    var welcomeFooterText: String?
    var welcomeFooterIconUrl: String?
    var welcomeShowTimestamp: Bool
    let createdAt: Date

    var isDeployed: Bool { messageId != nil && !(messageId!.isEmpty) }

    static func blank(guildId: String) -> Shop {
        Shop(
            id: UUID().uuidString,
            guildId: guildId,
            name: "ショップ",
            description: "商品を選択して購入してください。",
            enabled: true,
            disabledMessage: nil,
            channelId: "",
            messageId: nil,
            orderCategoryId: nil,
            archiveCategoryId: nil,
            supportRoleId: nil,
            timeoutHours: nil,
            color: 0x6366f1,
            footerText: "",
            paymentFlow: .manual,
            autoDeliver: true,
            welcomeImageUrl: nil,
            welcomeThumbnailUrl: nil,
            welcomeFields: [],
            welcomeFooterText: nil,
            welcomeFooterIconUrl: nil,
            welcomeShowTimestamp: true,
            createdAt: .now
        )
    }
}

// MARK: - PaymentFlow

enum PaymentFlow: String, Codable, CaseIterable {
    case manual = "manual"
    case urlInput = "url_input"

    var label: String {
        switch self {
        case .manual: return "手動取引"
        case .urlInput: return "URL入力"
        }
    }

    var icon: String {
        switch self {
        case .manual: return "hand.tap.fill"
        case .urlInput: return "link.badge.plus"
        }
    }

    var description: String {
        switch self {
        case .manual: return "管理者が直接取引を確認し、対応します。"
        case .urlInput: return "購入者に支払いURLの入力を求め、アプリで確認できます。"
        }
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

    var label: String {
        switch self {
        case .text: return "テキスト"
        case .url: return "URL"
        case .role: return "ロール付与"
        case .dm: return "DM送信"
        }
    }

    var icon: String {
        switch self {
        case .text: return "text.alignleft"
        case .url: return "link"
        case .role: return "shield.fill"
        case .dm: return "message.fill"
        }
    }
}

// MARK: - OrderStatus

enum OrderStatus: String, Codable, CaseIterable {
    case open
    case paid
    case delivered
    case completed
    case cancelled
    case disputed

    var label: String {
        switch self {
        case .open: return "注文受付中"
        case .paid: return "支払い確認済"
        case .delivered: return "商品引渡済"
        case .completed: return "取引完了"
        case .cancelled: return "キャンセル"
        case .disputed: return "異議あり"
        }
    }

    var icon: String {
        switch self {
        case .open: return "cart.fill"
        case .paid: return "creditcard.fill"
        case .delivered: return "shippingbox.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .disputed: return "exclamationmark.triangle.fill"
        }
    }

    var chipColor: Color {
        switch self {
        case .open: return .accentOrange
        case .paid: return .accentIndigo
        case .delivered: return .accentPurple
        case .completed: return .accentGreen
        case .cancelled: return Color.textTertiary
        case .disputed: return .red
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
}


