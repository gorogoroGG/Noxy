import Foundation

struct GreetingSettings: Codable, Sendable {
    var guildId: String

    // ── 入室（Welcome） ──────────────────────────────────────
    var welcomeEnabled: Bool
    var welcomeChannelId: String
    var welcomeChannelName: String
    var welcomeMessage: String
    var welcomeDmEnabled: Bool
    var welcomeDmMessage: String
    var welcomeRoleEnabled: Bool
    var welcomeRoleId: String
    var welcomeRoleName: String

    // ── 退室（Goodbye） ──────────────────────────────────────
    var goodbyeEnabled: Bool
    var goodbyeChannelId: String
    var goodbyeChannelName: String
    var goodbyeMessage: String
    var goodbyeDmEnabled: Bool
    var goodbyeDmMessage: String

    // ── デフォルト値 ─────────────────────────────────────────
    static func defaultSettings(guildId: String) -> GreetingSettings {
        GreetingSettings(
            guildId: guildId,
            welcomeEnabled: false,
            welcomeChannelId: "",
            welcomeChannelName: "",
            welcomeMessage: "{user.mention} が {server.name} に参加しました！🎉 メンバー数: {member.count}人",
            welcomeDmEnabled: false,
            welcomeDmMessage: "{server.name} へようこそ！ルールを確認してお楽しみください。",
            welcomeRoleEnabled: false,
            welcomeRoleId: "",
            welcomeRoleName: "",
            goodbyeEnabled: false,
            goodbyeChannelId: "",
            goodbyeChannelName: "",
            goodbyeMessage: "{user.name} が {server.name} から退室しました。👋",
            goodbyeDmEnabled: false,
            goodbyeDmMessage: "{server.name} での参加ありがとうございました。またの機会をお待ちしています！"
        )
    }
}
