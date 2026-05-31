import SwiftUI

struct ModerationToolsView: View {
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var toast: ToastMessage? = nil

    private let tabs = ["処罰", "警告履歴", "BAN一覧"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(tabs.indices, id: \.self) { index in
                        Text(tabs[index]).tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch selectedTab {
                case 0: PunishmentView(toast: $toast)
                case 1: WarnHistoryView()
                case 2: BanListView()
                default: EmptyView()
                }
            }
            .navigationTitle("モデレーション")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "ユーザーを検索")
        }
        .toast($toast)
    }
}

// MARK: - Punishment View

private struct PunishmentView: View {
    @Binding var toast: ToastMessage?
    @State private var selectedUser = ""
    @State private var reason = ""
    @State private var duration: Int = 60
    @State private var deleteMessageDays = 0

    private let users = ["ShadowX", "NoobPlayer", "TrollUser", "SpamBot", "ToxicGamer"]
    private let reasons = ["スパム", "暴言", "荒らし", "規約違反", "その他"]
    private let durations = [1, 5, 10, 30, 60, 360, 1440, 10080]

    var body: some View {
        List {
            Section("対象ユーザー") {
                Picker("ユーザー", selection: $selectedUser) {
                    Text("選択してください").tag("")
                    ForEach(users, id: \.self) { user in
                        Text(user).tag(user)
                    }
                }
            }

            Section("理由") {
                Picker("理由", selection: $reason) {
                    Text("選択してください").tag("")
                    ForEach(reasons, id: \.self) { reason in
                        Text(reason).tag(reason)
                    }
                }
                TextField("詳細を入力...", text: .constant(""), axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("タイムアウト") {
                Picker("期間", selection: $duration) {
                    Text("1分").tag(1)
                    Text("5分").tag(5)
                    Text("10分").tag(10)
                    Text("30分").tag(30)
                    Text("1時間").tag(60)
                    Text("6時間").tag(360)
                    Text("1日").tag(1440)
                    Text("1週間").tag(10080)
                }
            }

            Section("BANオプション") {
                Picker("メッセージ削除（日）", selection: $deleteMessageDays) {
                    Text("削除しない").tag(0)
                    Text("過去1日分").tag(1)
                    Text("過去2日分").tag(2)
                    Text("過去3日分").tag(3)
                    Text("過去7日分").tag(7)
                }
            }

            Section {
                Button {
                    toast = ToastMessage(type: .success, message: "\(selectedUser) をタイムアウトしました")
                } label: {
                    Label("タイムアウト", systemImage: "clock.badge.exclamationmark.fill")
                        .foregroundStyle(Color.accentOrange)
                }
                .disabled(selectedUser.isEmpty)

                Button {
                    toast = ToastMessage(type: .success, message: "\(selectedUser) をキックしました")
                } label: {
                    Label("キック", systemImage: "person.fill.xmark")
                        .foregroundStyle(Color.accentOrange)
                }
                .disabled(selectedUser.isEmpty)

                Button {
                    toast = ToastMessage(type: .success, message: "\(selectedUser) をBANしました")
                } label: {
                    Label("BAN", systemImage: "xmark.shield.fill")
                        .foregroundStyle(Color(uiColor: UIColor(hex: 0xEF4444)))
                }
                .disabled(selectedUser.isEmpty)
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Warn History

private struct WarnHistoryView: View {
    private let warns = [
        WarnItem(user: "ShadowX", reason: "スパム", issuer: "Admin", date: Date().addingTimeInterval(-3600), count: 1),
        WarnItem(user: "NoobPlayer", reason: "暴言", issuer: "Mod", date: Date().addingTimeInterval(-86400), count: 2),
        WarnItem(user: "TrollUser", reason: "荒らし", issuer: "Admin", date: Date().addingTimeInterval(-172800), count: 3),
        WarnItem(user: "SpamBot", reason: "規約違反", issuer: "System", date: Date().addingTimeInterval(-259200), count: 1),
    ]

    var body: some View {
        List {
            ForEach(warns) { warn in
                WarnRow(warn: warn)
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct WarnItem: Identifiable {
    let id = UUID()
    let user: String
    let reason: String
    let issuer: String
    let date: Date
    let count: Int
}

private struct WarnRow: View {
    let warn: WarnItem

    var body: some View {
        HStack(spacing: .spacing12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: .spacing8) {
                    Text(warn.user)
                        .font(.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                    Badge(text: "Warn #\(warn.count)", color: .accentOrange, style: .outlined)
                }
                Text("理由: \(warn.reason)")
                    .font(.captionRegular)
                    .foregroundStyle(Color.textSecondary)
                Text("実行者: \(warn.issuer) · \(warn.date.formatted(.relative(presentation: .named)))")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()
        }
        .padding(.vertical, .spacing4)
    }
}

// MARK: - Ban List

private struct BanListView: View {
    private let bans = [
        BanItem(user: "ToxicGamer", reason: "暴言", date: Date().addingTimeInterval(-604800)),
        BanItem(user: "SpamBot", reason: "スパム", date: Date().addingTimeInterval(-2592000)),
    ]

    var body: some View {
        List {
            ForEach(bans) { ban in
                BanRow(ban: ban)
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct BanItem: Identifiable {
    let id = UUID()
    let user: String
    let reason: String
    let date: Date
}

private struct BanRow: View {
    let ban: BanItem

    var body: some View {
        HStack(spacing: .spacing12) {
            Avatar(name: ban.user, size: 40, accentColor: Color(uiColor: UIColor(hex: 0xEF4444)))

            VStack(alignment: .leading, spacing: 4) {
                Text(ban.user)
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
                Text("理由: \(ban.reason)")
                    .font(.captionRegular)
                    .foregroundStyle(Color.textSecondary)
                Text("BAN日: \(ban.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer()

            Button("解除") {}
                .font(.captionRegular)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentGreen)
        }
        .padding(.vertical, .spacing4)
    }
}

#Preview {
    NavigationStack { ModerationToolsView() }
        .preferredColorScheme(.dark)
}
