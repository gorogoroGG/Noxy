import SwiftUI

// MARK: - VerifyType

enum VerifyType: String, Codable, CaseIterable {
    case captcha  = "captcha"   // Cloudflare Turnstile
    case reaction = "reaction"  // 絵文字リアクション
    case manual   = "manual"    // 管理者が手動承認
    case button   = "button"    // ワンクリック即時

    var label: String {
        switch self {
        case .captcha:  "CAPTCHA"
        case .reaction: "リアクション"
        case .manual:   "手動認証"
        case .button:   "ワンクリック"
        }
    }

    var icon: String {
        switch self {
        case .captcha:  "shield.checkerboard"
        case .reaction: "hand.thumbsup.fill"
        case .manual:   "person.badge.clock.fill"
        case .button:   "cursorarrow.click.fill"
        }
    }

    var description: String {
        switch self {
        case .captcha:  "Webページで CAPTCHA を完了することで認証します。ボット対策として最も強力です。"
        case .reaction: "指定した絵文字にリアクションすることで認証します。操作が簡単でDiscordらしい体験です。"
        case .manual:   "ユーザーの申請を管理者が確認・承認します。完全な制御が可能ですが対応が必要です。"
        case .button:   "ボタンをクリックするだけで即時認証します。最も操作が簡単ですがボット対策はありません。"
        }
    }

    var accentColor: Color {
        switch self {
        case .captcha:  .accentIndigo
        case .reaction: .accentOrange
        case .manual:   .accentPurple
        case .button:   .accentGreen
        }
    }
}

// MARK: - VerifyPanel

struct VerifyPanel: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var guildId: String
    var name: String
    var description: String
    var channelId: String
    var messageId: String?
    var roleId: String
    var color: Int
    var footerText: String
    var buttonLabel: String
    var enabled: Bool
    var verifyType: VerifyType
    var reactionEmoji: String
    var manualChannelId: String?
    let createdAt: Date

    var isDeployed: Bool { messageId != nil && !(messageId?.isEmpty ?? true) }

    nonisolated static func blank(guildId: String) -> VerifyPanel {
        VerifyPanel(
            id: UUID().uuidString,
            guildId: guildId,
            name: "認証",
            description: "下のボタンを押して認証を完了してください。",
            channelId: "",
            messageId: nil,
            roleId: "",
            color: 0x10b981,
            footerText: "",
            buttonLabel: "✅ 認証する",
            enabled: true,
            verifyType: .captcha,
            reactionEmoji: "✅",
            manualChannelId: nil,
            createdAt: .now
        )
    }
}

// MARK: - VerifyRequest（手動認証リクエスト）

enum VerifyRequestStatus: String, Codable {
    case pending  = "pending"
    case approved = "approved"
    case denied   = "denied"

    var label: String {
        switch self {
        case .pending:  "承認待ち"
        case .approved: "承認済"
        case .denied:   "拒否済"
        }
    }

    var color: Color {
        switch self {
        case .pending:  .accentOrange
        case .approved: .accentGreen
        case .denied:   .red
        }
    }
}

struct VerifyRequest: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let panelId: String
    let guildId: String
    let userId: String
    let username: String
    let avatarUrl: String?
    var status: VerifyRequestStatus
    let createdAt: Date
    var resolvedAt: Date?
}
