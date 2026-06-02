import SwiftUI

// MARK: - DiscordRole extensions (struct defined in DiscordService.swift)

extension DiscordRole {
    var swiftUIColor: Color {
        color == 0
            ? Color.textTertiary
            : Color(uiColor: UIColor(hex: UInt32(color)))
    }

    var permissionBits: UInt64 { UInt64(permissions) ?? 0 }

    func has(_ permission: RolePermission) -> Bool {
        let bits = permissionBits
        if bits & RolePermission.administrator.bit != 0 { return true }
        return bits & permission.bit != 0
    }

    func toggling(_ permission: RolePermission, on: Bool) -> String {
        var bits = permissionBits
        if on { bits |= permission.bit } else { bits &= ~permission.bit }
        return String(bits)
    }
}

// MARK: - Permission Definitions

struct RolePermission: Identifiable {
    let id: String
    let displayName: String
    let description: String
    let bit: UInt64
    let category: Category

    enum Category: String, CaseIterable {
        case general     = "一般"
        case text        = "テキスト"
        case voice       = "ボイス"
        case moderation  = "モデレーション"
    }

    static let all: [RolePermission] = [
        // General
        .init(id: "view_channel",       displayName: "チャンネルを見る",       description: "テキスト/ボイスチャンネルを閲覧できる",           bit: 1 << 10, category: .general),
        .init(id: "manage_channels",    displayName: "チャンネルを管理",       description: "チャンネルの作成・編集・削除ができる",           bit: 1 << 4,  category: .general),
        .init(id: "manage_roles",       displayName: "ロールを管理",           description: "自分より低位のロールを作成・編集できる",         bit: 1 << 28, category: .general),
        .init(id: "manage_guild",       displayName: "サーバーを管理",         description: "サーバー設定を変更できる",                       bit: 1 << 5,  category: .general),
        .init(id: "manage_expressions", displayName: "絵文字・スタンプを管理", description: "カスタム絵文字やスタンプを追加・削除できる",     bit: 1 << 30, category: .general),
        .init(id: "manage_webhooks",    displayName: "Webhookを管理",          description: "Webhookを作成・編集・削除できる",               bit: 1 << 29, category: .general),
        .init(id: "create_invite",      displayName: "招待リンクを作成",       description: "サーバーの招待リンクを作成できる",               bit: 1 << 0,  category: .general),
        .init(id: "change_nickname",    displayName: "ニックネームを変更",     description: "自分のニックネームを変更できる",                 bit: 1 << 26, category: .general),
        .init(id: "administrator",      displayName: "管理者",                 description: "すべての権限を持つ（危険）",                     bit: 1 << 3,  category: .general),
        // Text
        .init(id: "send_messages",      displayName: "メッセージを送信",       description: "テキストチャンネルにメッセージを送れる",         bit: 1 << 11, category: .text),
        .init(id: "send_in_threads",    displayName: "スレッドで送信",         description: "スレッド内でメッセージを送れる",                 bit: 1 << 38, category: .text),
        .init(id: "add_reactions",      displayName: "リアクションを追加",     description: "メッセージにリアクションを追加できる",           bit: 1 << 6,  category: .text),
        .init(id: "embed_links",        displayName: "リンクを埋め込む",       description: "URLをプレビュー表示できる",                     bit: 1 << 14, category: .text),
        .init(id: "attach_files",       displayName: "ファイルを添付",         description: "画像やファイルを送信できる",                     bit: 1 << 15, category: .text),
        .init(id: "read_history",       displayName: "メッセージ履歴を読む",   description: "過去のメッセージを遡って読める",                 bit: 1 << 16, category: .text),
        .init(id: "mention_everyone",   displayName: "@everyoneメンション",   description: "@everyone / @here のメンションが通知される",    bit: 1 << 17, category: .text),
        .init(id: "manage_messages",    displayName: "メッセージを管理",       description: "他人のメッセージを削除・ピン留めできる",         bit: 1 << 13, category: .text),
        .init(id: "manage_threads",     displayName: "スレッドを管理",         description: "スレッドの作成・アーカイブ・削除ができる",       bit: 1 << 34, category: .text),
        .init(id: "use_app_commands",   displayName: "スラッシュコマンド",     description: "/コマンドを使用できる",                         bit: 1 << 31, category: .text),
        // Voice
        .init(id: "connect",            displayName: "接続",                   description: "ボイスチャンネルに参加できる",                   bit: 1 << 20, category: .voice),
        .init(id: "speak",              displayName: "発言",                   description: "ボイスチャンネルで話せる",                       bit: 1 << 21, category: .voice),
        .init(id: "stream",             displayName: "ビデオ・配信",           description: "ビデオや画面共有ができる",                       bit: 1 << 9,  category: .voice),
        .init(id: "priority_speaker",   displayName: "プライオリティスピーカー", description: "押し話しで音量が大きくなる",                  bit: 1 << 8,  category: .voice),
        .init(id: "mute_members",       displayName: "メンバーをミュート",     description: "他のメンバーのマイクをミュートできる",           bit: 1 << 22, category: .voice),
        .init(id: "deafen_members",     displayName: "メンバーをスピーカーミュート", description: "他のメンバーの音声を聞こえなくできる",    bit: 1 << 23, category: .voice),
        .init(id: "move_members",       displayName: "メンバーを移動",         description: "VCに参加中のメンバーを別のVCに移動できる",       bit: 1 << 24, category: .voice),
        // Moderation
        .init(id: "kick_members",       displayName: "メンバーをキック",       description: "サーバーからメンバーを追い出せる",               bit: 1 << 1,  category: .moderation),
        .init(id: "ban_members",        displayName: "メンバーをBAN",          description: "サーバーからメンバーを永久追放できる",           bit: 1 << 2,  category: .moderation),
        .init(id: "moderate_members",   displayName: "タイムアウト",           description: "メンバーを一時的にミュート状態にできる",         bit: 1 << 40, category: .moderation),
        .init(id: "manage_nicknames",   displayName: "ニックネームを管理",     description: "他メンバーのニックネームを変更できる",           bit: 1 << 27, category: .moderation),
        .init(id: "view_audit_log",     displayName: "操作ログを見る",         description: "サーバーの操作履歴を閲覧できる",                 bit: 1 << 7,  category: .moderation),
    ]

    static func items(for category: Category) -> [RolePermission] {
        all.filter { $0.category == category }
    }

    // The administrator bit used for "has any" checks
    static let administrator = RolePermission(
        id: "administrator", displayName: "管理者", description: "",
        bit: 1 << 3, category: .general
    )
}

// MARK: - Mock Data

extension DiscordRole {
    static let mockRoles: [DiscordRole] = [
        DiscordRole(id: "1", name: "👑 オーナー",      color: 0xF59E0B, position: 10, managed: false, permissions: "2147483647",   mentionable: false),
        DiscordRole(id: "2", name: "🛡 モデレーター",  color: 0x5865F2, position: 9,  managed: false, permissions: "1099511693315", mentionable: true),
        DiscordRole(id: "3", name: "⭐ VIP",           color: 0xEC4899, position: 8,  managed: false, permissions: "378944",         mentionable: true),
        DiscordRole(id: "4", name: "🤖 Noxy Bot",      color: 0x23A55A, position: 7,  managed: true,  permissions: "8",              mentionable: false),
        DiscordRole(id: "5", name: "💬 メンバー",       color: 0x99AAB5, position: 2,  managed: false, permissions: "104324161",      mentionable: false),
        DiscordRole(id: "6", name: "@everyone",         color: 0,        position: 0,  managed: false, permissions: "104192064",      mentionable: false),
    ]
}

// MARK: - Discord Preset Colors

extension Color {
    /// Discord のロール作成UIに準拠したプリセットカラー（20色 + なし）
    static let discordRoleColors: [(name: String, value: Int)] = [
        // なし
        ("なし",           0),
        // 明るい10色（Discord標準）
        ("ティール",      0x1ABC9C),
        ("グリーン",      0x2ECC71),
        ("ブルー",        0x3498DB),
        ("パープル",      0x9B59B6),
        ("クリムゾン",    0xE91E63),
        ("イエロー",      0xF1C40F),
        ("オレンジ",      0xE67E22),
        ("レッド",        0xE74C3C),
        ("ライトグレー",  0x95A5A6),
        ("グレーブルー",  0x607D8B),
        // 暗い10色（Discord標準）
        ("ダークティール",  0x11806A),
        ("ダークグリーン",  0x1F8B4C),
        ("ダークブルー",    0x206694),
        ("ダークパープル",  0x71368A),
        ("ダーククリムゾン",0xAD1457),
        ("ダークゴールド",  0xC27C0E),
        ("ダークオレンジ",  0xA84300),
        ("ダークレッド",    0x992D22),
        ("グレー",          0x979C9F),
        ("スレート",        0x546E7A),
        // Discord ブランドカラー
        ("Blurple",  0x5865F2),
        ("Fuchsia",  0xEB459E),
    ]
}
