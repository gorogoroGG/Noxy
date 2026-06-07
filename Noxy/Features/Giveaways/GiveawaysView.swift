import SwiftUI

// MARK: - Models ───────────────────────────────────────────────────────────────

enum GiveawayStatus {
    case scheduled, active, ended, cancelled

    var label: String {
        switch self {
        case .scheduled: "開始待ち"
        case .active:    "進行中"
        case .ended:     "終了"
        case .cancelled: "キャンセル"
        }
    }

    var color: Color {
        switch self {
        case .scheduled: .accentOrange
        case .active:    .accentGreen
        case .ended:     Color.gray
        case .cancelled: .accentPink
        }
    }
}

struct GiveawayBonusRole: Identifiable, Equatable {
    var id: String { roleId }
    var roleId: String
    var roleName: String
    var roleColorHex: Int
    var multiplier: Int

    var displayColor: Color {
        roleColorHex == 0
            ? Color.textTertiary
            : Color(uiColor: UIColor(hex: UInt32(roleColorHex)))
    }
}

struct Giveaway: Identifiable {
    var id: String
    var prize: String
    var description: String
    var channelName: String
    var winnerCount: Int
    var startAt: Date?
    var endsAt: Date
    var participants: Int
    var winners: [String]
    var requiredRoleIds: [String]
    var requiredRoleNames: [String]
    var bonusRoles: [GiveawayBonusRole]
    var isCancelled: Bool = false

    var status: GiveawayStatus {
        if isCancelled { return .cancelled }
        if let s = startAt, s > Date() { return .scheduled }
        if endsAt > Date() { return .active }
        return .ended
    }
}

// MARK: - Mock data ────────────────────────────────────────────────────────────

private let kMockRoles: [DiscordRole] = [
    DiscordRole(id: "r1", name: "Nitroブースター", color: 0xFF73FA, position: 10, managed: false),
    DiscordRole(id: "r2", name: "メンバー",         color: 0x99AAB5, position: 2,  managed: false),
    DiscordRole(id: "r3", name: "モデレーター",     color: 0x3498DB, position: 8,  managed: false),
    DiscordRole(id: "r4", name: "VIP",               color: 0xFFD700, position: 9,  managed: false),
    DiscordRole(id: "r5", name: "アクティブ",       color: 0x2ECC71, position: 5,  managed: false),
]

private let sampleGiveaways: [Giveaway] = [
    Giveaway(
        id: "1", prize: "Nitro Classic 1ヶ月",
        description: "月1回のお楽しみ！ブーストのお礼に🎉",
        channelName: "🎁｜giveaway", winnerCount: 1,
        startAt: nil, endsAt: Date().addingTimeInterval(172800),
        participants: 142, winners: [],
        requiredRoleIds: [], requiredRoleNames: [],
        bonusRoles: [
            GiveawayBonusRole(roleId: "r1", roleName: "Nitroブースター", roleColorHex: 0xFF73FA, multiplier: 3),
            GiveawayBonusRole(roleId: "r4", roleName: "VIP",              roleColorHex: 0xFFD700, multiplier: 2),
        ]
    ),
    Giveaway(
        id: "2", prize: "限定スタンプセット",
        description: "VIPメンバー限定プレゼント✨",
        channelName: "🎁｜vip-giveaway", winnerCount: 5,
        startAt: Date().addingTimeInterval(3600),
        endsAt: Date().addingTimeInterval(172800 + 3600),
        participants: 0, winners: [],
        requiredRoleIds: ["r4"], requiredRoleNames: ["VIP"],
        bonusRoles: []
    ),
    Giveaway(
        id: "3", prize: "カスタムロール",
        description: "",
        channelName: "🎁｜giveaway", winnerCount: 3,
        startAt: nil, endsAt: Date().addingTimeInterval(-3600),
        participants: 256, winners: ["GoroGoro", "ShadowX", "TaroYamada"],
        requiredRoleIds: [], requiredRoleNames: [],
        bonusRoles: [
            GiveawayBonusRole(roleId: "r5", roleName: "アクティブ", roleColorHex: 0x2ECC71, multiplier: 2),
        ]
    ),
]

// MARK: - Main View ────────────────────────────────────────────────────────────

struct GiveawaysView: View {
    @Environment(AppState.self) private var appState

    @State private var giveaways: [Giveaway] = sampleGiveaways
    @State private var filter: Filter = .active
    @State private var showCreate = false
    @State private var toast: ToastMessage? = nil

    enum Filter: String, CaseIterable {
        case active = "進行中"
        case all    = "すべて"
        case ended  = "終了"
    }

    private var filtered: [Giveaway] {
        switch filter {
        case .active: giveaways.filter { $0.status == .active || $0.status == .scheduled }
        case .ended:  giveaways.filter { $0.status == .ended  || $0.status == .cancelled }
        case .all:    giveaways
        }
    }

    private func giveawayBinding(for g: Giveaway) -> Binding<Giveaway> {
        Binding(
            get: { self.giveaways.first(where: { $0.id == g.id }) ?? g },
            set: { updated in
                if let i = self.giveaways.firstIndex(where: { $0.id == updated.id }) {
                    self.giveaways[i] = updated
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            GiveawayLockedListView(giveaways: sampleGiveaways)
        }
        .toast($toast)
    }

    private var emptyState: some View {
        VStack(spacing: .spacing16) {
            Image(systemName: "gift")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)
            Text(filter == .active ? "進行中のギブアウェイはありません" : "ギブアウェイはありません")
                .font(.bodyRegular)
                .foregroundStyle(Color.textSecondary)
            if filter != .ended {
                PrimaryButton("作成する", style: .filled, size: .medium, icon: "plus") {
                    showCreate = true
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Giveaway Card ────────────────────────────────────────────────────────

private struct GiveawayCard: View {
    let giveaway: Giveaway

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing10) {
            // Header
            HStack(alignment: .top, spacing: .spacing8) {
                VStack(alignment: .leading, spacing: .spacing4) {
                    Text(giveaway.prize)
                        .font(.titleMedium)
                        .foregroundStyle(Color.textPrimary)
                    if !giveaway.description.isEmpty {
                        Text(giveaway.description)
                            .font(.captionRegular)
                            .foregroundStyle(Color.textTertiary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Badge(text: giveaway.status.label, color: giveaway.status.color)
            }

            // Time
            HStack(spacing: .spacing6) {
                Image(systemName: timeIcon)
                    .font(.captionSmall)
                    .foregroundStyle(giveaway.status.color)
                Text(timeText)
                    .font(.captionRegular)
                    .foregroundStyle(giveaway.status.color)
            }

            // Stats
            HStack(spacing: .spacing16) {
                Label("\(giveaway.participants) 参加者", systemImage: "person.3.fill")
                Label("当選 \(giveaway.winnerCount) 名", systemImage: "trophy.fill")
                Spacer()
                if !giveaway.channelName.isEmpty {
                    Label(giveaway.channelName, systemImage: "number").lineLimit(1)
                }
            }
            .font(.captionRegular)
            .foregroundStyle(Color.textSecondary)

            // Condition chips
            let chips = conditionChips
            if !chips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: .spacing6) {
                        ForEach(chips, id: \.self) { chip in
                            Text(chip)
                                .font(.captionSmall)
                                .padding(.horizontal, .spacing8)
                                .padding(.vertical, 3)
                                .background(Color.accentIndigo.opacity(0.1))
                                .foregroundStyle(Color.accentIndigo)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Winners
            if !giveaway.winners.isEmpty {
                HStack(spacing: .spacing6) {
                    Image(systemName: "trophy.fill")
                        .font(.captionSmall)
                        .foregroundStyle(Color.accentOrange)
                    Text(giveaway.winners.joined(separator: "、"))
                        .font(.captionRegular)
                        .foregroundStyle(Color.accentGreen)
                        .lineLimit(1)
                }
            }
        }
        .padding(.spacing12)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }

    private var timeIcon: String {
        switch giveaway.status {
        case .scheduled: "calendar.badge.clock"
        case .active:    "clock.fill"
        case .ended:     "checkmark.circle.fill"
        case .cancelled: "xmark.circle.fill"
        }
    }

    private var timeText: String {
        switch giveaway.status {
        case .scheduled:
            if let s = giveaway.startAt {
                return s.formatted(.relative(presentation: .named)) + "に開始"
            }
            return "開始予定"
        case .active:
            return "残り " + giveaway.endsAt.formatted(.relative(presentation: .named))
        case .ended:
            return giveaway.endsAt.formatted(date: .abbreviated, time: .shortened) + " に終了"
        case .cancelled:
            return "キャンセル済み"
        }
    }

    private var conditionChips: [String] {
        var result: [String] = []
        result += giveaway.requiredRoleNames.map { "🔑 \($0)" }
        result += giveaway.bonusRoles.map { "✨ \($0.roleName) ×\($0.multiplier)" }
        return result
    }
}

// MARK: - Detail View ──────────────────────────────────────────────────────────

struct GiveawayDetailView: View {
    @Binding var giveaway: Giveaway
    @State private var showRerollConfirm   = false
    @State private var showEndEarlyConfirm = false
    @State private var showCancelConfirm   = false
    @State private var toast: ToastMessage? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing16) {
                headerCard
                if !giveaway.requiredRoleNames.isEmpty { requiredRolesCard }
                if !giveaway.bonusRoles.isEmpty { bonusRolesCard }
                if giveaway.status == .ended && !giveaway.winners.isEmpty { winnersCard }
                actionSection
            }
            .padding()
        }
        .background(Color.bgPrimary)
        .navigationTitle("詳細")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "再抽選しますか？\n現在の当選者は上書きされます",
            isPresented: $showRerollConfirm, titleVisibility: .visible
        ) {
            Button("再抽選する") { performReroll() }
            Button("キャンセル", role: .cancel) {}
        }
        .confirmationDialog(
            "今すぐ終了して抽選しますか？",
            isPresented: $showEndEarlyConfirm, titleVisibility: .visible
        ) {
            Button("今すぐ終了", role: .destructive) { performEndEarly() }
            Button("キャンセル", role: .cancel) {}
        }
        .confirmationDialog(
            "このギブアウェイをキャンセルしますか？\n参加者への通知は行われません",
            isPresented: $showCancelConfirm, titleVisibility: .visible
        ) {
            Button("キャンセルする", role: .destructive) { performCancel() }
            Button("戻る", role: .cancel) {}
        }
        .toast($toast)
    }

    // ── Header card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: .spacing6) {
                    Text(giveaway.prize)
                        .font(.titleLarge)
                        .foregroundStyle(Color.textPrimary)
                    if !giveaway.description.isEmpty {
                        Text(giveaway.description)
                            .font(.bodySmall)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                Spacer()
                Badge(text: giveaway.status.label, color: giveaway.status.color)
            }

            Divider().background(Color.border)

            VStack(spacing: .spacing10) {
                infoRow("trophy.fill",   "当選者数",   "\(giveaway.winnerCount) 名")
                infoRow("person.3.fill", "参加者数",   "\(giveaway.participants) 名")
                infoRow("number",        "チャンネル",  giveaway.channelName)
                if let s = giveaway.startAt {
                    infoRow("play.fill", "開始日時",
                            s.formatted(date: .abbreviated, time: .shortened))
                }
                infoRow(
                    "clock.fill",
                    giveaway.status == .ended ? "終了日時" : "終了予定",
                    giveaway.endsAt.formatted(date: .abbreviated, time: .shortened)
                )
            }
        }
        .padding(.spacing16)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }

    private func infoRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.bodySmall)
                .foregroundStyle(Color.textSecondary)
                .frame(minWidth: 110, alignment: .leading)
            Text(value)
                .font(.bodySmall)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            Spacer()
        }
    }

    // ── Required roles card

    private var requiredRolesCard: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            Label("参加条件", systemImage: "lock.fill")
                .font(.titleMedium)
                .foregroundStyle(Color.textPrimary)
            Text("以下のロールを持つユーザーのみ参加できます")
                .font(.captionRegular)
                .foregroundStyle(Color.textTertiary)
            VStack(alignment: .leading, spacing: .spacing8) {
                ForEach(giveaway.requiredRoleNames, id: \.self) { name in
                    HStack(spacing: .spacing8) {
                        Circle().fill(Color.accentIndigo).frame(width: 8, height: 8)
                        Text(name).font(.bodySmall).foregroundStyle(Color.textPrimary)
                    }
                }
            }
        }
        .padding(.spacing16)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }

    // ── Bonus roles card

    private var bonusRolesCard: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            Label("ボーナスエントリー", systemImage: "star.fill")
                .font(.titleMedium)
                .foregroundStyle(Color.textPrimary)
            Text("以下のロールを持つユーザーは当選確率が上がります")
                .font(.captionRegular)
                .foregroundStyle(Color.textTertiary)
            VStack(spacing: .spacing8) {
                ForEach(giveaway.bonusRoles) { bonus in
                    HStack(spacing: .spacing8) {
                        Circle().fill(bonus.displayColor).frame(width: 8, height: 8)
                        Text(bonus.roleName)
                            .font(.bodySmall)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text("×\(bonus.multiplier)")
                            .font(.captionRegular)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentOrange)
                            .padding(.horizontal, .spacing8)
                            .padding(.vertical, 3)
                            .background(Color.accentOrange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.spacing16)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }

    // ── Winners card

    private var winnersCard: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            Label("当選者", systemImage: "trophy.fill")
                .font(.titleMedium)
                .foregroundStyle(Color.accentOrange)
            VStack(alignment: .leading, spacing: .spacing8) {
                ForEach(giveaway.winners, id: \.self) { winner in
                    HStack(spacing: .spacing8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentGreen)
                            .font(.captionRegular)
                        Text(winner).font(.bodySmall).foregroundStyle(Color.textPrimary)
                    }
                }
            }
        }
        .padding(.spacing16)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }

    // ── Actions

    @ViewBuilder
    private var actionSection: some View {
        switch giveaway.status {
        case .active:
            VStack(spacing: .spacing10) {
                PrimaryButton("今すぐ終了して抽選", style: .outlined, size: .medium, icon: "stop.fill") {
                    showEndEarlyConfirm = true
                }
                destructiveButton("ギブアウェイをキャンセル", icon: "xmark") {
                    showCancelConfirm = true
                }
            }
        case .ended:
            PrimaryButton("再抽選する", style: .outlined, size: .medium, icon: "arrow.clockwise") {
                showRerollConfirm = true
            }
        case .scheduled:
            destructiveButton("ギブアウェイをキャンセル", icon: "xmark") {
                showCancelConfirm = true
            }
        case .cancelled:
            EmptyView()
        }
    }

    private func destructiveButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: .spacing8) {
                Image(systemName: icon).font(.bodySmall)
                Text(title).font(.bodyRegular).fontWeight(.semibold)
            }
            .foregroundStyle(Color.accentPink)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.accentPink.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        }
        .buttonStyle(ScalePressButtonStyle())
    }

    // ── Actions impl

    private func performReroll() {
        let pool = ["GoroGoro", "ShadowX", "TaroYamada", "ProGamer", "CasualUser", "Lurker", "NewMember"]
        giveaway.winners = Array(pool.shuffled().prefix(giveaway.winnerCount))
        toast = ToastMessage(type: .success, message: "再抽選しました 🎉")
    }

    private func performEndEarly() {
        let pool = ["GoroGoro", "ShadowX", "TaroYamada", "ProGamer", "CasualUser"]
        giveaway.winners = Array(pool.shuffled().prefix(giveaway.winnerCount))
        giveaway.endsAt  = .now
        toast = ToastMessage(type: .success, message: "ギブアウェイを終了しました 🏆")
    }

    private func performCancel() {
        giveaway.isCancelled = true
        toast = ToastMessage(type: .info, message: "ギブアウェイをキャンセルしました")
    }
}

// MARK: - Create Sheet ─────────────────────────────────────────────────────────

private struct CreateGiveawaySheet: View {
    @Environment(\.dismiss)     private var dismiss
    @Environment(AppState.self) private var appState
    let onCreate: (Giveaway) -> Void

    @State private var prize       = ""
    @State private var description = ""
    @State private var channelName = ""
    @State private var winnerCount = 1
    @State private var useSchedule = false
    @State private var startAt     = Date().addingTimeInterval(3600)
    @State private var endsAt      = Date().addingTimeInterval(86400)

    @State private var requiredRoles: [DiscordRole]    = []
    @State private var bonusRoles: [GiveawayBonusRole] = []
    @State private var availableRoles: [DiscordRole]   = kMockRoles

    @State private var showRequiredPicker = false
    @State private var showBonusPicker    = false

    private var isValid: Bool { !prize.isEmpty && !channelName.isEmpty }

    var body: some View {
        NavigationStack {
            List {
                // ── 基本情報
                Section("基本情報") {
                    TextField("景品名（必須）", text: $prize)
                    TextField("説明（任意）", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("チャンネル名（必須）", text: $channelName)
                }

                // ── 期間
                Section("期間") {
                    Toggle(isOn: $useSchedule.animation()) {
                        Label("スケジュール開始", systemImage: "calendar.badge.clock")
                    }
                    if useSchedule {
                        DatePicker("開始日時", selection: $startAt,
                                   in: Date()...,
                                   displayedComponents: [.date, .hourAndMinute])
                    }
                    DatePicker(
                        "終了日時", selection: $endsAt,
                        in: (useSchedule ? startAt : Date())...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                // ── 当選者数
                Section("当選者") {
                    Stepper("当選者 \(winnerCount) 名", value: $winnerCount, in: 1...20)
                }

                // ── 参加条件
                Section {
                    ForEach(requiredRoles) { role in
                        HStack(spacing: .spacing8) {
                            Circle().fill(role.swiftUIColor).frame(width: 8, height: 8)
                            Text(role.name).font(.bodySmall).foregroundStyle(Color.textPrimary)
                            Spacer()
                        }
                    }
                    .onDelete { requiredRoles.remove(atOffsets: $0) }

                    Button { showRequiredPicker = true } label: {
                        Label(
                            requiredRoles.isEmpty ? "ロールを設定する" : "ロールを追加",
                            systemImage: "plus.circle"
                        )
                        .foregroundStyle(Color.accentIndigo)
                    }
                } header: {
                    Text("参加条件（任意）")
                } footer: {
                    Text("設定したロールを持つユーザーのみ参加できます。未設定の場合は全員が参加可能です。")
                }

                // ── ボーナスエントリー
                Section {
                    ForEach($bonusRoles) { $bonus in
                        BonusRoleRow(bonus: $bonus) {
                            bonusRoles.removeAll { $0.roleId == bonus.roleId }
                        }
                    }
                    Button { showBonusPicker = true } label: {
                        Label("ボーナスロールを追加", systemImage: "plus.circle")
                            .foregroundStyle(Color.accentIndigo)
                    }
                } header: {
                    Text("ボーナスエントリー（任意）")
                } footer: {
                    Text("設定したロールを持つユーザーは倍率分の票数で参加扱いになります（例：×3 → 3票）")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("ギブアウェイを作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("作成") {
                        onCreate(buildGiveaway())
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showRequiredPicker) {
                RolePickerSheet(
                    title: "参加条件のロール",
                    roles: availableRoles.filter { r in !requiredRoles.contains(where: { $0.id == r.id }) },
                    multiSelect: true
                ) { requiredRoles.append(contentsOf: $0) }
            }
            .sheet(isPresented: $showBonusPicker) {
                RolePickerSheet(
                    title: "ボーナスロールを選択",
                    roles: availableRoles.filter { r in !bonusRoles.contains(where: { $0.roleId == r.id }) },
                    multiSelect: false
                ) { selected in
                    bonusRoles.append(contentsOf: selected.map {
                        GiveawayBonusRole(roleId: $0.id, roleName: $0.name,
                                         roleColorHex: $0.color, multiplier: 2)
                    })
                }
            }
        }
        .task {
            if let roles = try? await DiscordService().fetchRoles(guildId: appState.selectedGuildId),
               !roles.isEmpty {
                availableRoles = roles
                    .filter { !$0.managed && $0.name != "@everyone" }
                    .sorted { $0.position > $1.position }
            }
        }
    }

    private func buildGiveaway() -> Giveaway {
        Giveaway(
            id: UUID().uuidString,
            prize: prize,
            description: description,
            channelName: channelName,
            winnerCount: winnerCount,
            startAt: useSchedule ? startAt : nil,
            endsAt: endsAt,
            participants: 0,
            winners: [],
            requiredRoleIds:   requiredRoles.map(\.id),
            requiredRoleNames: requiredRoles.map(\.name),
            bonusRoles: bonusRoles
        )
    }
}

// MARK: - Role Picker Sheet ────────────────────────────────────────────────────

private struct RolePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let roles: [DiscordRole]
    let multiSelect: Bool
    let onSelect: ([DiscordRole]) -> Void

    @State private var selectedIds: Set<String> = []

    var body: some View {
        NavigationStack {
            Group {
                if roles.isEmpty {
                    VStack(spacing: .spacing12) {
                        Image(systemName: "person.badge.minus")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.textTertiary)
                        Text("追加できるロールがありません")
                            .font(.bodySmall)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(roles) { role in
                        Button {
                            if multiSelect {
                                if selectedIds.contains(role.id) { selectedIds.remove(role.id) }
                                else { selectedIds.insert(role.id) }
                            } else {
                                onSelect([role])
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: .spacing10) {
                                Circle().fill(role.swiftUIColor).frame(width: 10, height: 10)
                                Text(role.name)
                                    .font(.bodySmall)
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                if multiSelect && selectedIds.contains(role.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentIndigo)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                if multiSelect {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("確定 (\(selectedIds.count))") {
                            onSelect(roles.filter { selectedIds.contains($0.id) })
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(selectedIds.isEmpty)
                    }
                }
            }
        }
    }
}

// MARK: - Bonus Role Row ───────────────────────────────────────────────────────

private struct BonusRoleRow: View {
    @Binding var bonus: GiveawayBonusRole
    let onDelete: () -> Void

    private let options = [2, 3, 5, 10]

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            HStack(spacing: .spacing8) {
                Circle().fill(bonus.displayColor).frame(width: 8, height: 8)
                Text(bonus.roleName)
                    .font(.bodySmall)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: .spacing6) {
                Text("当選確率")
                    .font(.captionRegular)
                    .foregroundStyle(Color.textTertiary)
                Spacer()
                ForEach(options, id: \.self) { opt in
                    Button { bonus.multiplier = opt } label: {
                        Text("×\(opt)")
                            .font(.captionRegular)
                            .fontWeight(bonus.multiplier == opt ? .semibold : .regular)
                            .padding(.horizontal, .spacing8)
                            .padding(.vertical, 4)
                            .background(bonus.multiplier == opt ? Color.accentIndigo : Color.bgElevated)
                            .foregroundStyle(bonus.multiplier == opt ? Color.white : Color.textSecondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Locked List ─────────────────────────────────────────────────────────

private struct GiveawayLockedListView: View {
    let giveaways: [Giveaway]

    var body: some View {
        List {
            // 準備中バナー
            Section {
                HStack(spacing: .spacing12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.accentOrange.opacity(0.2), Color.accentPink.opacity(0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 40, height: 40)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(LinearGradient(
                                colors: [Color.accentOrange, Color.accentPink],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("まもなく公開")
                            .font(.bodySmall).fontWeight(.semibold)
                            .foregroundStyle(Color.textPrimary)
                        Text("ギブアウェイ機能は現在準備中です")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                .padding(.vertical, .spacing4)
                .listRowBackground(Color.bgSurface)
            }

            // プレビュー（非タップ）
            Section("プレビュー") {
                ForEach(giveaways) { g in
                    GiveawayCard(giveaway: g)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowSeparator(.hidden)
                        .disabled(true)
                        .allowsHitTesting(false)
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.bgPrimary)
        .navigationTitle("ギブアウェイ")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Upgrade Prompt ──────────────────────────────────────────────────────

private struct GiveawayUpgradeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: .spacing32) {
                Spacer().frame(height: .spacing16)

                // Crown + title
                VStack(spacing: .spacing16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.accentPink.opacity(0.2), Color.accentOrange.opacity(0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 96, height: 96)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(LinearGradient(
                                colors: [Color.accentOrange, Color.accentPink],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    VStack(spacing: .spacing8) {
                        Text("Noxy Proの機能です")
                            .font(.displayMedium).foregroundStyle(Color.textPrimary)
                        Text("ギブアウェイで参加条件・倍率設定・\nスケジュール開始に対応しています")
                            .font(.bodySmall).foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal)

                // Feature preview (blurred sample cards)
                VStack(alignment: .leading, spacing: .spacing8) {
                    Text("プレビュー")
                        .font(.captionRegular).foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, .spacing16)

                    VStack(spacing: .spacing8) {
                        previewCard("🎁 Nitro Classic 1ヶ月", "進行中", "✨ Nitroブースター ×3  ✨ VIP ×2")
                        previewCard("🎁 限定スタンプセット",   "開始待ち", "🔑 VIPのみ参加可能")
                    }
                    .blur(radius: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                            .fill(Color.bgPrimary.opacity(0.4))
                    )
                    .padding(.horizontal, .spacing16)
                }

                // Pro features
                VStack(alignment: .leading, spacing: .spacing8) {
                    Text("Proでできること")
                        .font(.captionRegular).foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, .spacing16)
                    VStack(spacing: 0) {
                        ForEach([
                            ("🎯", "参加条件設定",   "特定ロールを持つユーザーのみに限定"),
                            ("✨", "当選確率倍率",   "ロールごとに2〜10倍に設定"),
                            ("🗓", "スケジュール開始", "未来の日時に自動スタート"),
                            ("🔄", "再抽選",         "当選者をワンタップで再抽選"),
                        ], id: \.0) { emoji, title, desc in
                            HStack(spacing: .spacing12) {
                                Text(emoji).font(.titleMedium).frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title).font(.bodySmall).foregroundStyle(Color.textPrimary)
                                    Text(desc).font(.captionSmall).foregroundStyle(Color.textTertiary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, .spacing16)
                            .padding(.vertical, .spacing12)
                            Divider().padding(.leading, 56)
                        }
                    }
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                    .padding(.horizontal, .spacing16)
                }

                // CTA
                VStack(spacing: .spacing12) {
                    NavigationLink(destination: SubscriptionView()) {
                        HStack(spacing: .spacing8) {
                            Image(systemName: "crown.fill")
                            Text("Noxy Pro を始める")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(LinearGradient(
                            colors: [Color.accentOrange, Color.accentPink],
                            startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                    }
                    .buttonStyle(ScalePressButtonStyle())
                    .padding(.horizontal)

                    Text("月額 ¥480 · いつでも解約可能")
                        .font(.captionRegular).foregroundStyle(Color.textTertiary)
                }

                Spacer().frame(height: .spacing16)
            }
        }
        .background(Color.bgPrimary)
    }

    private func previewCard(_ title: String, _ badge: String, _ chips: String) -> some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            HStack {
                Text(title).font(.titleMedium).foregroundStyle(Color.textPrimary)
                Spacer()
                Badge(text: badge, color: badge == "進行中" ? .accentGreen : .accentOrange)
            }
            Text(chips).font(.captionSmall).foregroundStyle(Color.accentIndigo)
        }
        .padding(.spacing12)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }
}

// MARK: - Preview ──────────────────────────────────────────────────────────────

#Preview {
    GiveawaysView()
        .environment(AppState())
}

#Preview("Upgrade Prompt") {
    NavigationStack { GiveawayUpgradeView() }
        .environment(AppState())
}
