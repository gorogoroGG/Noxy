import Foundation
import SwiftUI

/// アプリ全体で共有するグローバル状態。
/// MainTabView で @State として保持し、.environment(appState) で全タブに配布する。
@Observable
final class AppState {
    var selectedGuildId: String {
        get { UserDefaults.standard.string(forKey: "selected_guild_id") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "selected_guild_id") }
    }

    /// 現在選択中のギルド（nilなら未ロード）
    var selectedGuild: Guild? = nil

    /// 利用可能なギルド一覧（DashboardView がロード後に書き込む）
    var guilds: [Guild] = []

    /// サーバー切り替え中フラグ（trueのとき全画面ローディングを表示）
    var isSwitchingServer = false

    /// ローディングオーバーレイに表示する「切り替え先」名
    private(set) var switchingToName: String? = nil

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
