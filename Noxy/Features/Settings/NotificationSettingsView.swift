import SwiftUI

// MARK: - NotificationSettingsStore

@Observable
final class NotificationSettingsStore {
    static let shared = NotificationSettingsStore()
    private let udKey = "notification_settings_v1"

    // ── アプリレベル ──────────────────────────────────────────────
    var appEnabled:         Bool { didSet { save() } }
    var updateEnabled:      Bool { didSet { save() } }
    var botStatusEnabled:   Bool { didSet { save() } }
    var maintenanceEnabled: Bool { didSet { save() } }

    // ── 機能別 ────────────────────────────────────────────────────
    var ticket:       TicketNotifSettings       { didSet { save() } }
    var shop:         ShopNotifSettings         { didSet { save() } }
    var moderation:   ModerationNotifSettings   { didSet { save() } }
    var welcome:      WelcomeNotifSettings      { didSet { save() } }
    var verify:       VerifyNotifSettings       { didSet { save() } }
    var reactionRole: ReactionRoleNotifSettings { didSet { save() } }
    var tempVC:       TempVCNotifSettings       { didSet { save() } }
    var autoResponse: AutoResponseNotifSettings { didSet { save() } }

    private init() {
        let d = (UserDefaults.standard.data(forKey: "notification_settings_v1")
            .flatMap { try? JSONDecoder().decode(Persisted.self, from: $0) })

        appEnabled         = d?.appEnabled         ?? true
        updateEnabled      = d?.updateEnabled      ?? true
        botStatusEnabled   = d?.botStatusEnabled   ?? true
        maintenanceEnabled = d?.maintenanceEnabled ?? true
        ticket       = d?.ticket       ?? TicketNotifSettings()
        shop         = d?.shop         ?? ShopNotifSettings()
        moderation   = d?.moderation   ?? ModerationNotifSettings()
        welcome      = d?.welcome      ?? WelcomeNotifSettings()
        verify       = d?.verify       ?? VerifyNotifSettings()
        reactionRole = d?.reactionRole ?? ReactionRoleNotifSettings()
        tempVC       = d?.tempVC       ?? TempVCNotifSettings()
        autoResponse = d?.autoResponse ?? AutoResponseNotifSettings()
    }

    private func save() {
        let p = Persisted(
            appEnabled: appEnabled, updateEnabled: updateEnabled,
            botStatusEnabled: botStatusEnabled, maintenanceEnabled: maintenanceEnabled,
            ticket: ticket, shop: shop, moderation: moderation,
            welcome: welcome, verify: verify, reactionRole: reactionRole,
            tempVC: tempVC, autoResponse: autoResponse
        )
        if let data = try? JSONEncoder().encode(p) {
            UserDefaults.standard.set(data, forKey: udKey)
        }
    }

    private struct Persisted: Codable {
        var appEnabled: Bool; var updateEnabled: Bool
        var botStatusEnabled: Bool; var maintenanceEnabled: Bool
        var ticket: TicketNotifSettings; var shop: ShopNotifSettings
        var moderation: ModerationNotifSettings; var welcome: WelcomeNotifSettings
        var verify: VerifyNotifSettings; var reactionRole: ReactionRoleNotifSettings
        var tempVC: TempVCNotifSettings; var autoResponse: AutoResponseNotifSettings
    }
}

// MARK: - 機能別設定モデル

struct TicketNotifSettings: Codable {
    var enabled:      Bool = true
    var newTicket:    Bool = true   // 新規チケット開設
    var reply:        Bool = true   // チケットへの返信
    var closed:       Bool = true   // チケットのクローズ
    var overdue:      Bool = true   // 未対応チケットの期限超え（24h以上）
}

struct ShopNotifSettings: Codable {
    var enabled:      Bool = true
    var newOrder:     Bool = true   // 新規注文
    var orderDone:    Bool = true   // 注文完了
    var orderCancel:  Bool = false  // 注文キャンセル
    var lowStock:     Bool = false  // 在庫少（近日実装予定）
}

struct ModerationNotifSettings: Codable {
    var enabled:      Bool = true
    var warning:      Bool = true   // 警告発行
    var ban:          Bool = true   // BANの実行
    var timeout:      Bool = true   // タイムアウト
    var unban:        Bool = false  // BAN解除
}

struct WelcomeNotifSettings: Codable {
    var enabled:      Bool = false  // デフォルトオフ（頻繁すぎる場合があるため）
    var memberJoin:   Bool = true   // メンバー参加
    var memberLeave:  Bool = false  // メンバー退出
}

struct VerifyNotifSettings: Codable {
    var enabled:      Bool = true
    var manualRequest: Bool = true  // 手動認証リクエスト
    var completed:    Bool = false  // 認証完了
}

struct ReactionRoleNotifSettings: Codable {
    var enabled:      Bool = false  // デフォルトオフ
    var roleAdded:    Bool = true   // ロール付与
    var roleRemoved:  Bool = false  // ロール剥奪
}

struct TempVCNotifSettings: Codable {
    var enabled:      Bool = false  // デフォルトオフ
    var created:      Bool = true   // 一時VC作成
    var deleted:      Bool = false  // 一時VC削除
}

struct AutoResponseNotifSettings: Codable {
    var enabled:      Bool = false
    var triggered:    Bool = true   // 自動応答が発火
}

// MARK: - ルート画面

struct NotificationSettingsView: View {
    private let store = NotificationSettingsStore.shared

    var body: some View {
        List {
            // ── アプリの通知 ──────────────────────────────────────
            Section {
                Toggle(isOn: Binding(get: { store.appEnabled }, set: { store.appEnabled = $0 })) {
                    SettingsNotifRow(icon: "bell.fill", color: .accentIndigo,
                                    title: "アプリ内通知",
                                    description: "すべてのアプリ内通知のマスタースイッチ")
                }
                .tint(Color.accentIndigo)

                if store.appEnabled {
                    Toggle(isOn: Binding(get: { store.updateEnabled }, set: { store.updateEnabled = $0 })) {
                        SettingsNotifRow(icon: "arrow.down.circle.fill", color: .accentGreen,
                                        title: "アップデート通知",
                                        description: "新バージョンのリリース情報")
                    }
                    .tint(Color.accentIndigo)

                    Toggle(isOn: Binding(get: { store.botStatusEnabled }, set: { store.botStatusEnabled = $0 })) {
                        SettingsNotifRow(icon: "bolt.fill", color: .accentOrange,
                                        title: "Bot状態通知",
                                        description: "Botがオフラインになったとき")
                    }
                    .tint(Color.accentIndigo)

                    Toggle(isOn: Binding(get: { store.maintenanceEnabled }, set: { store.maintenanceEnabled = $0 })) {
                        SettingsNotifRow(icon: "wrench.and.screwdriver.fill", color: .accentPurple,
                                        title: "メンテナンス・障害情報",
                                        description: "サービス障害やメンテナンス予定")
                    }
                    .tint(Color.accentIndigo)
                }
            } header: {
                Text("アプリの通知")
            } footer: {
                if !store.appEnabled {
                    Text("マスタースイッチがオフです。すべてのアプリ内通知が無効になっています。")
                        .foregroundStyle(Color.accentRed)
                }
            }

            // ── 機能に関する通知 ──────────────────────────────────
            Section {
                NavigationLink(destination: FeatureNotifListView()) {
                    HStack(spacing: .spacing12) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.captionRegular)
                            .foregroundStyle(Color.accentIndigo)
                            .frame(width: 28, height: 28)
                            .background(Color.accentIndigo.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("機能に関する通知")
                                .font(.bodySmall)
                                .foregroundStyle(Color.textPrimary)
                            Text("チケット・ショップ・モデレーションなど")
                                .font(.captionSmall)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                    .padding(.vertical, .spacing2)
                }
            } header: {
                Text("機能別設定")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("通知設定")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - 機能一覧

struct FeatureNotifListView: View {
    private let store = NotificationSettingsStore.shared

    var body: some View {
        List {
            NavigationLink(destination: TicketNotifSettingsView()) {
                FeatureNotifRow(icon: "ticket.fill", color: .accentOrange,
                                title: "チケット",
                                subtitle: enabledSummary(store.ticket.enabled, store.ticket.newTicket, store.ticket.reply, store.ticket.closed, store.ticket.overdue),
                                enabled: store.ticket.enabled)
            }
            NavigationLink(destination: ShopNotifSettingsView()) {
                FeatureNotifRow(icon: "cart.fill", color: .accentGreen,
                                title: "ショップ・注文",
                                subtitle: enabledSummary(store.shop.enabled, store.shop.newOrder, store.shop.orderDone, store.shop.orderCancel),
                                enabled: store.shop.enabled)
            }
            NavigationLink(destination: ModerationNotifSettingsView()) {
                FeatureNotifRow(icon: "shield.lefthalf.filled", color: .accentRed,
                                title: "モデレーション",
                                subtitle: enabledSummary(store.moderation.enabled, store.moderation.warning, store.moderation.ban, store.moderation.timeout),
                                enabled: store.moderation.enabled)
            }
            NavigationLink(destination: WelcomeNotifSettingsView()) {
                FeatureNotifRow(icon: "hand.wave.fill", color: .accentGreen,
                                title: "入退室メッセージ",
                                subtitle: enabledSummary(store.welcome.enabled, store.welcome.memberJoin, store.welcome.memberLeave),
                                enabled: store.welcome.enabled)
            }
            NavigationLink(destination: VerifyNotifSettingsView()) {
                FeatureNotifRow(icon: "checkmark.seal.fill", color: .accentIndigo,
                                title: "認証",
                                subtitle: enabledSummary(store.verify.enabled, store.verify.manualRequest, store.verify.completed),
                                enabled: store.verify.enabled)
            }
            NavigationLink(destination: ReactionRoleNotifSettingsView()) {
                FeatureNotifRow(icon: "heart.fill", color: .accentPink,
                                title: "リアクションロール",
                                subtitle: enabledSummary(store.reactionRole.enabled, store.reactionRole.roleAdded, store.reactionRole.roleRemoved),
                                enabled: store.reactionRole.enabled)
            }
            NavigationLink(destination: TempVCNotifSettingsView()) {
                FeatureNotifRow(icon: "waveform.and.mic", color: .accentIndigo,
                                title: "一時VC",
                                subtitle: enabledSummary(store.tempVC.enabled, store.tempVC.created, store.tempVC.deleted),
                                enabled: store.tempVC.enabled)
            }
            NavigationLink(destination: AutoResponseNotifSettingsView()) {
                FeatureNotifRow(icon: "bubble.left.and.bubble.right.fill", color: .accentPurple,
                                title: "自動応答",
                                subtitle: enabledSummary(store.autoResponse.enabled, store.autoResponse.triggered),
                                enabled: store.autoResponse.enabled)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("機能に関する通知")
        .navigationBarTitleDisplayMode(.large)
    }

    private func enabledSummary(_ featureEnabled: Bool, _ events: Bool...) -> String {
        guard featureEnabled else { return "オフ" }
        let count = events.filter { $0 }.count
        return count == 0 ? "すべてオフ" : "\(count)件の通知が有効"
    }
}

// MARK: - チケット

struct TicketNotifSettingsView: View {
    private let store = NotificationSettingsStore.shared

    var body: some View {
        FeatureNotifShell(title: "チケット", icon: "ticket.fill", color: .accentOrange,
                          enabled: Binding(get: { store.ticket.enabled }, set: { store.ticket.enabled = $0 })) {
            Section {
                eventToggle("新規チケット開設",
                            description: "Discordでメンバーがチケットを開いたとき",
                            icon: "plus.circle.fill", color: .accentGreen,
                            binding: Binding(get: { store.ticket.newTicket }, set: { store.ticket.newTicket = $0 }))
                eventToggle("チケットへの返信",
                            description: "オープン中のチケットにメッセージが届いたとき",
                            icon: "bubble.left.fill", color: .accentIndigo,
                            binding: Binding(get: { store.ticket.reply }, set: { store.ticket.reply = $0 }))
                eventToggle("チケットのクローズ",
                            description: "チケットがクローズされたとき",
                            icon: "lock.fill", color: .accentOrange,
                            binding: Binding(get: { store.ticket.closed }, set: { store.ticket.closed = $0 }))
                eventToggle("未対応チケットの期限超え",
                            description: "24時間以上対応されていないチケットが存在するとき",
                            icon: "clock.badge.exclamationmark.fill", color: .accentRed,
                            binding: Binding(get: { store.ticket.overdue }, set: { store.ticket.overdue = $0 }))
            } header: { Text("通知イベント") }
        }
    }
}

// MARK: - ショップ

struct ShopNotifSettingsView: View {
    private let store = NotificationSettingsStore.shared

    var body: some View {
        FeatureNotifShell(title: "ショップ・注文", icon: "cart.fill", color: .accentGreen,
                          enabled: Binding(get: { store.shop.enabled }, set: { store.shop.enabled = $0 })) {
            Section {
                eventToggle("新規注文",
                            description: "メンバーが商品を注文したとき",
                            icon: "bag.fill", color: .accentGreen,
                            binding: Binding(get: { store.shop.newOrder }, set: { store.shop.newOrder = $0 }))
                eventToggle("注文完了",
                            description: "注文が完了としてマークされたとき",
                            icon: "checkmark.circle.fill", color: .accentIndigo,
                            binding: Binding(get: { store.shop.orderDone }, set: { store.shop.orderDone = $0 }))
                eventToggle("注文キャンセル",
                            description: "注文がキャンセルされたとき",
                            icon: "xmark.circle.fill", color: .accentRed,
                            binding: Binding(get: { store.shop.orderCancel }, set: { store.shop.orderCancel = $0 }))
            } header: { Text("通知イベント") }
            Section {
                eventToggle("在庫少（近日実装予定）",
                            description: "商品の在庫が少なくなったとき",
                            icon: "exclamationmark.triangle.fill", color: .accentOrange,
                            binding: Binding(get: { store.shop.lowStock }, set: { store.shop.lowStock = $0 }))
                    .disabled(true)
                    .opacity(0.5)
            } header: { Text("近日対応予定") }
        }
    }
}

// MARK: - モデレーション

struct ModerationNotifSettingsView: View {
    private let store = NotificationSettingsStore.shared

    var body: some View {
        FeatureNotifShell(title: "モデレーション", icon: "shield.lefthalf.filled", color: .accentRed,
                          enabled: Binding(get: { store.moderation.enabled }, set: { store.moderation.enabled = $0 })) {
            Section {
                eventToggle("警告発行",
                            description: "メンバーに警告が発行されたとき",
                            icon: "exclamationmark.triangle.fill", color: .accentOrange,
                            binding: Binding(get: { store.moderation.warning }, set: { store.moderation.warning = $0 }))
                eventToggle("BAN実行",
                            description: "メンバーがBANされたとき",
                            icon: "nosign", color: .accentRed,
                            binding: Binding(get: { store.moderation.ban }, set: { store.moderation.ban = $0 }))
                eventToggle("タイムアウト",
                            description: "メンバーにタイムアウトが適用されたとき",
                            icon: "timer", color: .accentPurple,
                            binding: Binding(get: { store.moderation.timeout }, set: { store.moderation.timeout = $0 }))
                eventToggle("BAN解除",
                            description: "メンバーのBANが解除されたとき",
                            icon: "checkmark.shield.fill", color: .accentGreen,
                            binding: Binding(get: { store.moderation.unban }, set: { store.moderation.unban = $0 }))
            } header: { Text("通知イベント") }
        }
    }
}

// MARK: - 入退室

struct WelcomeNotifSettingsView: View {
    private let store = NotificationSettingsStore.shared

    var body: some View {
        FeatureNotifShell(title: "入退室メッセージ", icon: "hand.wave.fill", color: .accentGreen,
                          enabled: Binding(get: { store.welcome.enabled }, set: { store.welcome.enabled = $0 })) {
            Section {
                eventToggle("メンバー参加",
                            description: "新しいメンバーがサーバーに参加したとき",
                            icon: "person.badge.plus", color: .accentGreen,
                            binding: Binding(get: { store.welcome.memberJoin }, set: { store.welcome.memberJoin = $0 }))
                eventToggle("メンバー退出",
                            description: "メンバーがサーバーを退出したとき",
                            icon: "person.badge.minus", color: .accentOrange,
                            binding: Binding(get: { store.welcome.memberLeave }, set: { store.welcome.memberLeave = $0 }))
            } header: { Text("通知イベント") }
            Section {
                Text("メンバーの参加・退出が頻繁なサーバーでは通知が大量に発生する場合があります。")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }
}

// MARK: - 認証

struct VerifyNotifSettingsView: View {
    private let store = NotificationSettingsStore.shared

    var body: some View {
        FeatureNotifShell(title: "認証", icon: "checkmark.seal.fill", color: .accentIndigo,
                          enabled: Binding(get: { store.verify.enabled }, set: { store.verify.enabled = $0 })) {
            Section {
                eventToggle("手動認証リクエスト",
                            description: "メンバーが手動認証を申請したとき（手動認証パネルのみ）",
                            icon: "person.fill.questionmark", color: .accentOrange,
                            binding: Binding(get: { store.verify.manualRequest }, set: { store.verify.manualRequest = $0 }))
                eventToggle("認証完了",
                            description: "メンバーの認証が完了したとき",
                            icon: "person.fill.checkmark", color: .accentGreen,
                            binding: Binding(get: { store.verify.completed }, set: { store.verify.completed = $0 }))
            } header: { Text("通知イベント") }
        }
    }
}

// MARK: - リアクションロール

struct ReactionRoleNotifSettingsView: View {
    private let store = NotificationSettingsStore.shared

    var body: some View {
        FeatureNotifShell(title: "リアクションロール", icon: "heart.fill", color: .accentPink,
                          enabled: Binding(get: { store.reactionRole.enabled }, set: { store.reactionRole.enabled = $0 })) {
            Section {
                eventToggle("ロール付与",
                            description: "メンバーがリアクションロールでロールを受け取ったとき",
                            icon: "tag.fill", color: .accentGreen,
                            binding: Binding(get: { store.reactionRole.roleAdded }, set: { store.reactionRole.roleAdded = $0 }))
                eventToggle("ロール剥奪",
                            description: "メンバーがリアクションロールでロールを外したとき",
                            icon: "tag.slash.fill", color: .accentOrange,
                            binding: Binding(get: { store.reactionRole.roleRemoved }, set: { store.reactionRole.roleRemoved = $0 }))
            } header: { Text("通知イベント") }
            Section {
                Text("リアクションロールの付与・剥奪が頻繁なサーバーでは通知が大量に発生する場合があります。")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }
}

// MARK: - 一時VC

struct TempVCNotifSettingsView: View {
    private let store = NotificationSettingsStore.shared

    var body: some View {
        FeatureNotifShell(title: "一時VC", icon: "waveform.and.mic", color: .accentIndigo,
                          enabled: Binding(get: { store.tempVC.enabled }, set: { store.tempVC.enabled = $0 })) {
            Section {
                eventToggle("一時VC作成",
                            description: "メンバーが一時VCを作成したとき",
                            icon: "mic.fill", color: .accentIndigo,
                            binding: Binding(get: { store.tempVC.created }, set: { store.tempVC.created = $0 }))
                eventToggle("一時VC削除",
                            description: "一時VCが空になり削除されたとき",
                            icon: "mic.slash.fill", color: .accentOrange,
                            binding: Binding(get: { store.tempVC.deleted }, set: { store.tempVC.deleted = $0 }))
            } header: { Text("通知イベント") }
        }
    }
}

// MARK: - 自動応答

struct AutoResponseNotifSettingsView: View {
    private let store = NotificationSettingsStore.shared

    var body: some View {
        FeatureNotifShell(title: "自動応答", icon: "bubble.left.and.bubble.right.fill", color: .accentPurple,
                          enabled: Binding(get: { store.autoResponse.enabled }, set: { store.autoResponse.enabled = $0 })) {
            Section {
                eventToggle("自動応答が発火",
                            description: "設定したキーワードに反応して自動返信したとき",
                            icon: "bolt.fill", color: .accentPurple,
                            binding: Binding(get: { store.autoResponse.triggered }, set: { store.autoResponse.triggered = $0 }))
            } header: { Text("通知イベント") }
        }
    }
}

// MARK: - 共通コンポーネント

private struct FeatureNotifShell<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let enabled: Binding<Bool>
    @ViewBuilder let content: () -> Content

    var body: some View {
        List {
            Section {
                HStack(spacing: .spacing12) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 36, height: 36)
                        .background(color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text("\(title)の通知")
                        .font(.bodySmall)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Toggle("", isOn: enabled).labelsHidden().tint(Color.accentIndigo)
                }
                .padding(.vertical, .spacing4)
            } footer: {
                if !enabled.wrappedValue {
                    Text("この機能の通知はすべてオフになっています。")
                        .foregroundStyle(Color.accentRed)
                }
            }

            if enabled.wrappedValue {
                content()
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .animation(.easeInOut(duration: 0.2), value: enabled.wrappedValue)
    }
}

private func eventToggle(_ title: String, description: String, icon: String, color: Color, binding: Binding<Bool>) -> some View {
    HStack(spacing: .spacing12) {
        Image(systemName: icon)
            .font(.captionRegular)
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 7))
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.bodySmall)
                .foregroundStyle(Color.textPrimary)
            Text(description)
                .font(.captionSmall)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(2)
        }
        Spacer()
        Toggle("", isOn: binding).labelsHidden().tint(Color.accentIndigo)
    }
    .padding(.vertical, .spacing2)
}

private struct SettingsNotifRow: View {
    let icon: String; let color: Color; let title: String; let description: String

    var body: some View {
        HStack(spacing: .spacing12) {
            Image(systemName: icon)
                .font(.captionRegular)
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.bodySmall)
                    .foregroundStyle(Color.textPrimary)
                Text(description)
                    .font(.captionSmall)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.vertical, .spacing2)
    }
}

struct FeatureNotifRow: View {
    let icon: String; let color: Color; let title: String
    let subtitle: String; let enabled: Bool

    var body: some View {
        HStack(spacing: .spacing12) {
            Image(systemName: icon)
                .font(.captionRegular)
                .foregroundStyle(enabled ? color : Color.textTertiary)
                .frame(width: 28, height: 28)
                .background((enabled ? color : Color.textTertiary).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.bodySmall)
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(.captionSmall)
                    .foregroundStyle(enabled ? Color.textSecondary : Color.textTertiary)
            }
            Spacer()
            if !enabled {
                Text("オフ")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, .spacing2)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
