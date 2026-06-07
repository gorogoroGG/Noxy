import SwiftUI

struct ModWarningView: View {
    let guildId: String

    @State private var loadState: LoadState<[ModWarning]> = .loading
    @State private var showAddSheet = false
    @State private var showRevoked = false
    @State private var toast: String? = nil
    @State private var selectedMember: Member? = nil

    private let service = ModerationService()

    private func grouped(_ warnings: [ModWarning]) -> [(userId: String, displayName: String, warnings: [ModWarning])] {
        let base = showRevoked ? warnings : warnings.filter { !$0.isRevoked }
        var dict: [String: (String, [ModWarning])] = [:]
        for w in base {
            if dict[w.userId] == nil { dict[w.userId] = (w.displayName, []) }
            dict[w.userId]!.1.append(w)
        }
        return dict
            .map { (userId: $0.key, displayName: $0.value.0, warnings: $0.value.1) }
            .sorted { lhs, rhs in
                lhs.warnings.filter { !$0.isRevoked }.count >
                rhs.warnings.filter { !$0.isRevoked }.count
            }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgPrimary.ignoresSafeArea()
            mainContent
            if let msg = toast {
                ModSuccessToast(message: msg)
                    .padding(.bottom, .spacing32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: toast != nil)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $selectedMember) { member in
            MemberDetailView(member: member, guildId: guildId, allRoles: [], onAction: { _ in })
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus").foregroundStyle(Color.accentIndigo)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddWarningSheet(guildId: guildId, service: service) { newW in
                if case .loaded(var list) = loadState {
                    list.append(newW)
                    loadState = .loaded(list)
                }
                showToast("\(newW.displayName) に警告を追加しました")
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch loadState {
        case .loading:
            loadingView("警告データを取得中...")
        case .error(let msg):
            ModErrorView(message: msg) { Task { await load() } }
        case .loaded(let warnings):
            warningList(warnings)
        }
    }

    private func warningList(_ warnings: [ModWarning]) -> some View {
        let groups = grouped(warnings)
        return ScrollView {
            LazyVStack(spacing: .spacing12) {
                Color.clear.frame(height: .spacing8)
                escalationCard
                filterControl(warnings)
                if groups.isEmpty {
                    ModEmptyView(icon: "checkmark.circle",
                                 title: "警告はありません").padding(.top, .spacing32)
                } else {
                    ForEach(groups, id: \.userId) { g in
                        UserWarningCard(
                            userId: g.userId, displayName: g.displayName,
                            warnings: g.warnings,
                            onRevoke: { id in revokeWarning(id) },
                            onSelectUser: {
                                selectedMember = memberFromWarning(userId: g.userId,
                                    username: g.warnings.first?.username ?? g.userId,
                                    displayName: g.displayName)
                            }
                        )
                    }
                }
                bottomPad
            }
            .padding(.horizontal, .spacing16)
            .padding(.top, .spacing12)
        }
    }

    private var escalationCard: some View {
        VStack(alignment: .leading, spacing: .spacing10) {
            Label("自動エスカレーション", systemImage: "arrow.triangle.2.circlepath")
                .font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
            ForEach(EscalationRule.defaults) { rule in
                HStack(spacing: .spacing8) {
                    Image(systemName: rule.action.icon)
                        .font(.system(size: 12)).foregroundStyle(rule.action.color).frame(width: 16)
                    Text(rule.label).font(.captionRegular).foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding(.spacing12)
        .background(Color.accentPurple.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .overlay(RoundedRectangle(cornerRadius: .cornerRadiusMedium)
            .stroke(Color.accentPurple.opacity(0.2), lineWidth: 1))
    }

    private func filterControl(_ warnings: [ModWarning]) -> some View {
        HStack {
            sectionHeader(icon: "exclamationmark.triangle.fill", color: .accentOrange,
                          title: "\(grouped(warnings).count)人に警告あり")
            Button {
                withAnimation { showRevoked.toggle() }
            } label: {
                Label(showRevoked ? "取り消し済みを隠す" : "取り消し済みを表示",
                      systemImage: showRevoked ? "eye.slash" : "eye")
                    .font(.captionSmall).foregroundStyle(Color.accentIndigo)
            }
        }
    }

    private func load() async {
        loadState = .loading
        do {
            loadState = .loaded(try await service.fetchWarnings(guildId: guildId))
        } catch {
            loadState = .error("警告データの取得に失敗しました。\n「mod_warnings」テーブルが存在するか確認してください。")
        }
    }

    private func revokeWarning(_ id: String) {
        Task {
            do {
                try await service.revokeWarning(id: id)
                if case .loaded(var list) = loadState,
                   let i = list.firstIndex(where: { $0.id == id }) {
                    list[i].isRevoked = true
                    loadState = .loaded(list)
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } catch {
                showToast("取り消しに失敗しました")
            }
        }
    }

    private func memberFromWarning(userId: String, username: String, displayName: String) -> Member {
        Member(id: userId, guildId: guildId, username: username,
               displayName: displayName, discriminator: "0", globalName: nil,
               nick: nil, avatarUrl: nil, bannerUrl: nil, accentColor: nil,
               publicFlags: 0, isBot: false, roles: [],
               joinedAt: .distantPast, createdAt: .distantPast,
               isBoosting: false, boostSince: nil, isDeaf: false, isMute: false,
               flags: 0, communicationDisabledUntil: nil, status: .offline)
    }

    private func showToast(_ msg: String) {
        withAnimation { toast = msg }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run { withAnimation { toast = nil } }
        }
    }
}

// MARK: - UserWarningCard

private struct UserWarningCard: View {
    let userId: String
    let displayName: String
    let warnings: [ModWarning]
    let onRevoke: (String) -> Void
    let onSelectUser: () -> Void
    @State private var isExpanded = true

    private var activeCount: Int { warnings.filter { !$0.isRevoked }.count }
    private var nextRule: EscalationRule? { EscalationRule.defaults.first { $0.threshold > activeCount } }
    private var accentColor: Color {
        if activeCount >= 7 { return .accentRed }
        if activeCount >= 3 { return .accentOrange }
        return .accentIndigo
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.25)) { isExpanded.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: .spacing12) {
                    ZStack(alignment: .topTrailing) {
                        Avatar(name: displayName, size: 40, accentColor: accentColor)
                        Text("\(activeCount)")
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                            .padding(4).background(accentColor).clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Button(action: onSelectUser) {
                            Text(displayName)
                                .font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                        }
                        .buttonStyle(.plain)
                        if let rule = nextRule {
                            Label("次: \(rule.label)", systemImage: "arrow.right.circle.fill")
                                .font(.captionSmall).foregroundStyle(rule.action.color)
                        } else {
                            Text("BAN閾値に達しています")
                                .font(.captionSmall).foregroundStyle(Color.accentRed)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.captionSmall).foregroundStyle(Color.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(.spacing12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal, .spacing12)
                VStack(spacing: 2) {
                    ForEach(warnings.sorted { $0.createdAt > $1.createdAt }) { w in
                        WarningRowView(warning: w) { onRevoke(w.id) }
                    }
                }
                .padding(.spacing8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .overlay(RoundedRectangle(cornerRadius: .cornerRadiusMedium)
            .stroke(accentColor.opacity(0.25), lineWidth: 1))
        .animation(.spring(duration: 0.25), value: isExpanded)
    }
}

private struct WarningRowView: View {
    let warning: ModWarning
    let onRevoke: () -> Void

    var body: some View {
        HStack(spacing: .spacing8) {
            Image(systemName: warning.isRevoked ? "checkmark.circle" : "exclamationmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(warning.isRevoked ? Color.textTertiary : Color.accentOrange)
            VStack(alignment: .leading, spacing: 2) {
                Text(warning.reason)
                    .font(.captionRegular).fontWeight(.medium)
                    .foregroundStyle(warning.isRevoked ? Color.textTertiary : Color.textPrimary)
                    .strikethrough(warning.isRevoked)
                HStack(spacing: 4) {
                    Text(warning.staffName)
                    Text("·")
                    Text(warning.createdAt.formatted(.relative(presentation: .named)))
                }
                .font(.captionSmall).foregroundStyle(Color.textTertiary)
            }
            Spacer()
            if !warning.isRevoked {
                Button("取り消し", action: onRevoke)
                    .font(.captionSmall).foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, .spacing8).padding(.vertical, 3)
                    .background(Color.bgElevated).clipShape(Capsule())
            } else {
                Text("取り消し済み").font(.captionSmall).foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, .spacing8).padding(.vertical, .spacing6)
        .background(warning.isRevoked ? Color.clear : Color.bgElevated.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
    }
}

// MARK: - AddWarningSheet（メンバー選択式）

struct AddWarningSheet: View {
    let guildId: String
    let service: ModerationService
    let onAdd: (ModWarning) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var members: [Member] = []
    @State private var isLoadingMembers = true
    @State private var memberSearch = ""
    @State private var selectedMember: Member? = nil
    @State private var reason = ""
    @State private var isSubmitting = false

    private let presets = ["スパム", "暴言", "荒らし", "規約違反", "差別的発言"]

    private var filteredMembers: [Member] {
        if memberSearch.isEmpty { return members }
        return members.filter {
            $0.displayName.localizedCaseInsensitiveContains(memberSearch) ||
            $0.username.localizedCaseInsensitiveContains(memberSearch)
        }
    }

    var body: some View {
        NavigationView {
            ZStack { Color.bgPrimary.ignoresSafeArea(); form }
            .navigationTitle("警告を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSubmitting {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button("追加") { Task { await submit() } }
                            .fontWeight(.semibold).foregroundStyle(Color.accentOrange)
                            .disabled(selectedMember == nil || reason.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .task { await loadMembers() }
    }

    private var form: some View {
        ScrollView {
            VStack(spacing: .spacing20) {
                memberPickerSection
                reasonSection
            }
            .padding(.spacing16)
        }
    }

    // MARK: - Member Picker

    private var memberPickerSection: some View {
        VStack(alignment: .leading, spacing: .spacing10) {
            Text("対象メンバー")
                .font(.captionSmall).foregroundStyle(Color.textTertiary)

            // 選択中のメンバー表示
            if let m = selectedMember {
                HStack(spacing: .spacing10) {
                    Avatar(name: m.displayName, size: 36, accentColor: .accentIndigo)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.displayName).font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                        Text("@\(m.username)").font(.captionSmall).foregroundStyle(Color.textTertiary)
                    }
                    Spacer()
                    Button {
                        withAnimation { selectedMember = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.textTertiary).font(.system(size: 18))
                    }
                }
                .padding(.spacing10)
                .background(Color.accentIndigo.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
                .overlay(RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                    .stroke(Color.accentIndigo.opacity(0.3), lineWidth: 1))
            }

            // 検索フィールド
            HStack(spacing: .spacing8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.textTertiary)
                TextField("名前で検索", text: $memberSearch)
                    .font(.bodySmall)
                if !memberSearch.isEmpty {
                    Button { memberSearch = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Color.textTertiary)
                    }
                }
            }
            .padding(.spacing10)
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
            .overlay(RoundedRectangle(cornerRadius: .cornerRadiusSmall).stroke(Color.border, lineWidth: 1))

            // メンバーリスト
            if isLoadingMembers {
                HStack { Spacer(); ProgressView().tint(Color.accentIndigo); Spacer() }
                    .padding(.spacing16)
            } else {
                VStack(spacing: 2) {
                    ForEach(filteredMembers.prefix(30)) { member in
                        MemberPickerRow(
                            member: member,
                            isSelected: selectedMember?.id == member.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedMember = member
                                memberSearch = ""
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                    if filteredMembers.count > 30 {
                        Text("さらに\(filteredMembers.count - 30)人います。検索で絞り込んでください。")
                            .font(.captionSmall).foregroundStyle(Color.textTertiary)
                            .padding(.top, .spacing6)
                    }
                }
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
                .overlay(RoundedRectangle(cornerRadius: .cornerRadiusSmall).stroke(Color.border, lineWidth: 1))
            }
        }
    }

    // MARK: - Reason

    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: .spacing10) {
            Text("理由")
                .font(.captionSmall).foregroundStyle(Color.textTertiary)

            LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: .spacing8) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        reason = preset
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(preset)
                            .font(.captionRegular).fontWeight(.medium)
                            .foregroundStyle(reason == preset ? .white : Color.textSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, .spacing8)
                            .background(reason == preset ? Color.accentOrange : Color.bgSurface)
                            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
                            .overlay(RoundedRectangle(cornerRadius: .cornerRadiusSmall).stroke(Color.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("詳細・カスタム理由を入力", text: $reason, axis: .vertical)
                .font(.bodySmall).padding(.spacing12).lineLimit(2...4)
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
                .overlay(RoundedRectangle(cornerRadius: .cornerRadiusSmall).stroke(Color.border, lineWidth: 1))

            // 次のエスカレーションプレビュー
            if let member = selectedMember {
                escalationPreview(for: member)
            }
        }
    }

    private func escalationPreview(for member: Member) -> some View {
        // モックでは常にルール1が次になる（実際はDBから現在の警告数を取得）
        let rule = EscalationRule.defaults.first
        return Group {
            if let rule {
                HStack(spacing: .spacing8) {
                    Image(systemName: rule.action.icon).foregroundStyle(rule.action.color)
                    Text("この警告で \(rule.label) が自動実行されます")
                        .font(.captionSmall).foregroundStyle(Color.textSecondary)
                }
                .padding(.spacing10)
                .background(rule.action.color.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
            }
        }
    }

    // MARK: - Actions

    private func loadMembers() async {
        isLoadingMembers = true
        if let fetched = try? await DiscordMemberService().fetchMembers(guildId: guildId) {
            members = fetched
        }
        isLoadingMembers = false
    }

    private func submit() async {
        guard let member = selectedMember else { return }
        isSubmitting = true
        let rsn = reason.trimmingCharacters(in: .whitespaces)
        do {
            let w = try await service.addWarning(
                guildId: guildId, userId: member.id,
                username: member.username, displayName: member.displayName,
                reason: rsn.isEmpty ? "理由なし" : rsn,
                staffId: "app-staff", staffName: "Staff (App)", autoAction: nil
            )
            onAdd(w)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        isSubmitting = false
    }
}

// MARK: - MemberPickerRow

private struct MemberPickerRow: View {
    let member: Member
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: .spacing10) {
                Avatar(name: member.displayName, size: 32, accentColor: .accentIndigo)
                VStack(alignment: .leading, spacing: 1) {
                    Text(member.displayName)
                        .font(.bodySmall).fontWeight(.medium).foregroundStyle(Color.textPrimary)
                    Text("@\(member.username)")
                        .font(.captionSmall).foregroundStyle(Color.textTertiary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentIndigo).font(.system(size: 18))
                }
            }
            .padding(.horizontal, .spacing10).padding(.vertical, .spacing8)
            .background(isSelected ? Color.accentIndigo.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
