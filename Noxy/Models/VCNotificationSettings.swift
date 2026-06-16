import Foundation

/// VC（ボイスチャンネル）参加通知の設定。
/// 誰かがVCに参加・退出・移動したとき、指定したテキストチャンネルへ通知する。
struct VCNotificationSettings: Identifiable, Codable, Sendable {
    var id: String?
    var guildId: String
    var enabled: Bool

    // 通知先テキストチャンネル
    var notifyChannelId: String
    var notifyChannelName: String

    // 通知するイベント
    var notifyOnJoin: Bool      // 参加
    var notifyOnLeave: Bool     // 退出
    var notifyOnMove: Bool      // 別VCへ移動
    var notifyOnStream: Bool    // 配信・画面共有の開始/終了

    // 対象VC
    var watchAllVcs: Bool
    var watchVcIds: [String]

    // メッセージ
    var joinMessage: String
    var leaveMessage: String
    var useEmbed: Bool          // Embed形式 / プレーンテキスト

    // ノイズ対策
    var onlyFirstJoin: Bool     // 0人→1人になった最初の参加だけ通知
    var excludeBots: Bool       // BOTの入退室を無視

    // ロールメンション（Pro）
    var mentionRoleEnabled: Bool
    var mentionRoleId: String
    var mentionRoleName: String

    var effectiveId: String { id ?? UUID().uuidString }

    nonisolated static func defaultSettings(guildId: String) -> VCNotificationSettings {
        VCNotificationSettings(
            id: nil,
            guildId: guildId,
            enabled: false,
            notifyChannelId: "",
            notifyChannelName: "",
            notifyOnJoin: true,
            notifyOnLeave: false,
            notifyOnMove: false,
            notifyOnStream: false,
            watchAllVcs: true,
            watchVcIds: [],
            joinMessage: "🔊 {user.name} が {vc.name} に参加しました（現在 {vc.count}人）",
            leaveMessage: "👋 {user.name} が {vc.name} から退出しました",
            useEmbed: true,
            onlyFirstJoin: false,
            excludeBots: true,
            mentionRoleEnabled: false,
            mentionRoleId: "",
            mentionRoleName: ""
        )
    }
}
