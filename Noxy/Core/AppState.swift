import Foundation
import SwiftUI

/// アプリ全体で共有するグローバル状態。
/// MainTabView で @State として保持し、.environment(appState) で全タブに配布する。
@Observable
final class AppState {
    /// ストアドプロパティ → @Observable が変更を追跡できる
    /// didSet で UserDefaults に永続化（アプリ再起動後も最後のサーバーを復元）
    var selectedGuildId: String = UserDefaults.standard.string(forKey: "selected_guild_id") ?? "" {
        didSet { UserDefaults.standard.set(selectedGuildId, forKey: "selected_guild_id") }
    }

    /// 現在選択中のギルド（nilなら未ロード）
    var selectedGuild: Guild? = nil

    /// 利用可能なギルド一覧（DashboardView がロード後に書き込む）
    var guilds: [Guild] = []

    /// サブスクリプション状態（MainTabView がロード後に書き込む）
    var subscriptionStatus: SubscriptionStatus = .inactive

    /// Pro プランが有効かどうか
    var isPro: Bool { subscriptionStatus.isActive }

    /// Bot のオンライン状態（nil = まだ確認中）
    var botStatus: BotStatus? = nil

    /// Bot がオフラインかどうか（nil の間は false = 通常 UI を表示）
    var isBotOffline: Bool { botStatus?.isOnline == false }

    /// アプリ初期化完了フラグ
    var isAppReady = false

    /// Bot が入っているサーバー一覧
    var botGuilds: [Guild] = []

    /// Bot がどのサーバーにも入っていない
    var isBotNotInAnyGuild: Bool { isAppReady && botGuilds.isEmpty }

    /// データ再読み込みトリガー（BotNotInGuildView から切り替え時にトグル）
    var needsReload = false

    /// サーバー切り替え中フラグ（trueのとき全画面ローディングを表示）
    var isSwitchingServer = false

    /// ローディングオーバーレイに表示する「切り替え先」名
    private(set) var switchingToName: String? = nil

    // MARK: - In-Memory Cache（画面遷移時のちらつき防止）

    var cachedEmbeds: [String: [EmbedModel]] = [:]
    var cachedTicketPanels: [String: [TicketPanel]] = [:]
    var cachedTickets: [String: [Ticket]] = [:]
    var cachedShops: [String: [Shop]] = [:]
    var cachedReactionRoles: [String: [ReactionRoleItem]] = [:]

    func cacheEmbeds(_ embeds: [EmbedModel], for guildId: String) {
        cachedEmbeds[guildId] = embeds
    }
    func cacheTicketPanels(_ panels: [TicketPanel], for guildId: String) {
        cachedTicketPanels[guildId] = panels
    }
    func cacheTickets(_ tickets: [Ticket], for guildId: String) {
        cachedTickets[guildId] = tickets
    }
    func cacheShops(_ shops: [Shop], for guildId: String) {
        cachedShops[guildId] = shops
    }
    func cacheReactionRoles(_ items: [ReactionRoleItem], for guildId: String) {
        cachedReactionRoles[guildId] = items
    }

    func clearCache(for guildId: String) {
        cachedEmbeds.removeValue(forKey: guildId)
        cachedTicketPanels.removeValue(forKey: guildId)
        cachedTickets.removeValue(forKey: guildId)
        cachedShops.removeValue(forKey: guildId)
        cachedReactionRoles.removeValue(forKey: guildId)
    }

    /// サーバーを切り替える。同じサーバーを選んだ場合は何もしない。
    @MainActor
    func switchServer(to guild: Guild) async {
        guard guild.id != selectedGuildId else { return }

        switchingToName = guild.name
        withAnimation(.easeOut(duration: 0.2)) {
            isSwitchingServer = true
        }

        // アプリ起動ローディングと同じ尺感
        try? await Task.sleep(for: .milliseconds(1200))

        selectedGuildId = guild.id
        selectedGuild   = guild

        withAnimation(.easeIn(duration: 0.35)) {
            isSwitchingServer = false
        }
        switchingToName = nil
    }
}
