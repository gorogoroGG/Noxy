import SwiftUI

// MARK: - Shop

struct Shop: Identifiable, Codable, Hashable {
    let id: String
    var guildId: String
    var name: String
    var description: String
    var enabled: Bool
    var channelId: String
    var messageId: String?
    var orderCategoryId: String?
    var archiveCategoryId: String?
    var supportRoleId: String?
    var timeoutHours: Int?
    var color: Int
    var footerText: String
    let createdAt: Date

    var isDeployed: Bool { messageId != nil && !(messageId!.isEmpty) }

    static func blank(guildId: String) -> Shop {
        Shop(
            id: UUID().uuidString,
            guildId: guildId,
            name: "ショップ",
            description: "商品を選択して購入してください。",
            enabled: true,
            channelId: "",
            messageId: nil,
            orderCategoryId: nil,
            archiveCategoryId: nil,
            supportRoleId: nil,
            timeoutHours: nil,
            color: 0x6366f1,
            footerText: "本Botは取引の仲介・保証・管理に一切関与しません。取引に関するトラブルはサーバー管理者および取引相手との間で解決してください。",
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
    let createdAt: Date
    var paidAt: Date?
    var deliveredAt: Date?
    var completedAt: Date?
    var cancelledAt: Date?
}
