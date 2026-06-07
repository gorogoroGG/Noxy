import SwiftUI

// MARK: - QuickActionDef

enum QuickActionDef: String, CaseIterable, Identifiable {
    case embedCreate   = "embed_create"
    case tickets       = "tickets"
    case members       = "members"
    case moderation    = "moderation"
    case reactionRoles = "reaction_roles"
    case welcomeMsg    = "welcome_msg"
    case giveaways     = "giveaways"
    case shop          = "shop"
    case analytics     = "analytics"
    case monitor       = "monitor"
    case tempVC        = "temp_vc"
    case statChannels  = "stat_channels"
    case roles         = "roles"
    case auditLog      = "audit_log"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .embedCreate:   "Embed作成"
        case .tickets:       "チケット"
        case .members:       "メンバー"
        case .moderation:    "モデレーション"
        case .reactionRoles: "リアクションロール"
        case .welcomeMsg:    "入退室メッセージ"
        case .giveaways:     "ギブアウェイ"
        case .shop:          "ショップ"
        case .analytics:     "アナリティクス"
        case .monitor:       "モニター"
        case .tempVC:        "一時VC"
        case .statChannels:  "ステータスCH"
        case .roles:         "ロール管理"
        case .auditLog:      "監査ログ"
        }
    }

    var subtitle: String {
        switch self {
        case .embedCreate:   "告知・お知らせ"
        case .tickets:       "サポート対応"
        case .members:       "メンバー管理"
        case .moderation:    "BAN・警告・タイムアウト"
        case .reactionRoles: "スタンプでロール付与"
        case .welcomeMsg:    "参加・退出あいさつ"
        case .giveaways:     "景品プレゼント"
        case .shop:          "商品販売・注文管理"
        case .analytics:     "メンバー統計"
        case .monitor:       "Bot活動ログ"
        case .tempVC:        "自動VC作成"
        case .statChannels:  "カウンター表示"
        case .roles:         "ロール設定"
        case .auditLog:      "操作履歴"
        }
    }

    var icon: String {
        switch self {
        case .embedCreate:   "rectangle.stack.badge.plus"
        case .tickets:       "ticket.fill"
        case .members:       "person.3.fill"
        case .moderation:    "shield.lefthalf.filled"
        case .reactionRoles: "heart.fill"
        case .welcomeMsg:    "hand.wave.fill"
        case .giveaways:     "gift.fill"
        case .shop:          "cart.fill"
        case .analytics:     "chart.bar.fill"
        case .monitor:       "waveform"
        case .tempVC:        "waveform.and.mic"
        case .statChannels:  "chart.bar.xaxis"
        case .roles:         "tag.fill"
        case .auditLog:      "doc.text.magnifyingglass"
        }
    }

    var color: Color {
        switch self {
        case .embedCreate:   .accentIndigo
        case .tickets:       .accentOrange
        case .members:       .accentPink
        case .moderation:    .accentRed
        case .reactionRoles: .accentPink
        case .welcomeMsg:    .accentGreen
        case .giveaways:     .accentPink
        case .shop:          .accentOrange
        case .analytics:     .accentIndigo
        case .monitor:       .accentGreen
        case .tempVC:        .accentIndigo
        case .statChannels:  .accentPurple
        case .roles:         .accentPurple
        case .auditLog:      .accentOrange
        }
    }

    /// 近日公開予定でまだ利用できないアクション
    var isLocked: Bool {
        switch self {
        case .giveaways: return true
        default:         return false
        }
    }

    static let defaultSelection: [QuickActionDef] = [
        .embedCreate, .tickets, .members, .moderation
    ]
}

// MARK: - HomeQuickActionsPrefs

@Observable
final class HomeQuickActionsPrefs {
    static let shared = HomeQuickActionsPrefs()
    static let maxCount = 8
    private let udKey = "home_quick_actions_v1"

    var selected: [QuickActionDef] {
        didSet { save() }
    }

    private init() {
        let saved = UserDefaults.standard.stringArray(forKey: "home_quick_actions_v1") ?? []
        let defs = saved.compactMap { QuickActionDef(rawValue: $0) }
        selected = defs.isEmpty ? QuickActionDef.defaultSelection : defs
    }

    func toggle(_ action: QuickActionDef) {
        guard !action.isLocked else { return }
        if let idx = selected.firstIndex(of: action) {
            selected.remove(at: idx)
        } else if selected.count < HomeQuickActionsPrefs.maxCount {
            selected.append(action)
        }
    }

    func isSelected(_ action: QuickActionDef) -> Bool { selected.contains(action) }
    func canAdd(_ action: QuickActionDef) -> Bool { selected.count < HomeQuickActionsPrefs.maxCount || isSelected(action) }

    private func save() {
        UserDefaults.standard.set(selected.map(\.rawValue), forKey: udKey)
    }
}

// MARK: - HomeNotification

struct HomeNotification: Identifiable {
    let id: String
    let sourceId: String   // 遷移先を特定するための元データID（チケットID等）
    let type: HomeNotifType
    let title: String
    let detail: String
    let createdAt: Date
}

enum HomeNotifType: String, CaseIterable {
    case ticket     = "ticket"
    case order      = "order"
    case moderation = "moderation"
    case giveaway   = "giveaway"

    var label: String {
        switch self {
        case .ticket:     "チケット"
        case .order:      "注文"
        case .moderation: "モデレーション"
        case .giveaway:   "ギブアウェイ"
        }
    }
    var icon: String {
        switch self {
        case .ticket:     "ticket.fill"
        case .order:      "cart.fill"
        case .moderation: "exclamationmark.triangle.fill"
        case .giveaway:   "gift.fill"
        }
    }
    var color: Color {
        switch self {
        case .ticket:     .accentOrange
        case .order:      .accentGreen
        case .moderation: .accentRed
        case .giveaway:   .accentPink
        }
    }
}

// MARK: - HomeNotifSettings

@Observable
final class HomeNotifSettings {
    static let shared = HomeNotifSettings()
    private let udKey = "home_notif_settings_v1"

    var showTickets:    Bool { didSet { save() } }
    var showOrders:     Bool { didSet { save() } }
    var showModeration: Bool { didSet { save() } }
    var showGiveaways:  Bool { didSet { save() } }

    private init() {
        let d = UserDefaults.standard.dictionary(forKey: "home_notif_settings_v1")
        showTickets    = d?["tickets"]    as? Bool ?? true
        showOrders     = d?["orders"]     as? Bool ?? true
        showModeration = d?["moderation"] as? Bool ?? true
        showGiveaways  = d?["giveaways"]  as? Bool ?? false
    }

    var enabledTypes: [HomeNotifType] {
        var result: [HomeNotifType] = []
        if showTickets    { result.append(.ticket) }
        if showOrders     { result.append(.order) }
        if showModeration { result.append(.moderation) }
        if showGiveaways  { result.append(.giveaway) }
        return result
    }

    private func save() {
        UserDefaults.standard.set([
            "tickets":    showTickets,
            "orders":     showOrders,
            "moderation": showModeration,
            "giveaways":  showGiveaways,
        ], forKey: udKey)
    }
}

// MARK: - DismissedNotifsStore

final class DismissedNotifsStore {
    static let shared = DismissedNotifsStore()
    private let udKey = "home_dismissed_notif_ids_v1"

    private init() {}

    private var ids: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: udKey) ?? [])
    }

    func dismiss(_ id: String) {
        var current = ids
        current.insert(id)
        // ArraySlice は UserDefaults に保存できないので必ず [String] に変換する
        let stored: [String] = Array(current).suffix(1000).map { $0 }
        UserDefaults.standard.set(stored, forKey: udKey)
    }

    func isDismissed(_ id: String) -> Bool { ids.contains(id) }

    func filter(_ list: [HomeNotification]) -> [HomeNotification] {
        list.filter { !isDismissed($0.id) }
    }
}
