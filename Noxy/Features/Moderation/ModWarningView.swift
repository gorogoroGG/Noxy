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
        ZStack(alignment: .bottomTrailing) {
            Theme.Color.bg.ignoresSafeArea()
            mainContent
            if let msg = toast {
                ModSuccessToast(message: msg)
                    .padding(.bottom, Theme.Spacing.xl)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            // FAB
            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.Color.accentInk)
                    .frame(width: 56, height: 56)
                    .background(Theme.Color.accent)
                    .clipShape(Circle())
                    .shadow(color: Theme.Color.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .animation(.spring(duration: 0.3), value: toast != nil)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $selectedMember) { member in
            MemberDetailView(member: member, guildId: guildId, allRoles: [], onAction: { _ in })
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
        return VStack(spacing: 0) {
            // 固定ヘッダー（スクロールしない）
            VStack(spacing: Theme.Spacing.sm) {
                escalationCard
                filterControl(warnings)
            }
            .padding(.top, Theme.Spacing.sm)
            .background(Theme.Color.bg)

            Divider().background(Theme.Color.line)

            // スクロール部分
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.md) {
                    Color.clear.frame(height: Theme.Spacing.xs)
                    if groups.isEmpty {
                        ModEmptyView(icon: "checkmark.circle",
                                     title: "警告はありません")
                            .padding(.top, Theme.Spacing.xl)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(groups.enumerated()), id: \.element.userId) { idx, g in
                                UserWarningRow(
                                    userId: g.userId,
                                    displayName: g.displayName,
                                    warnings: g.warnings,
                                    onRevoke: { id in revokeWarning(id) },
                                    onSelectUser: {
                                        selectedMember = memberFromWarning(
                                            userId: g.userId,
                                            username: g.warnings.first?.username ?? g.userId,
                                            displayName: g.displayName
                                        )
                                    }
                                )
                                if idx < groups.count - 1 {
                                    Divider()
                                        .background(Theme.Color.line)
                                        .padding(.leading, 60)
                                }
                            }
                        }
                        .background(Theme.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                    bottomPad
                    Color.clear.frame(height: 80)
                }
                .padding(.top, Theme.Spacing.md)
            }
        }
    }

    private var escalationCard: some View {
        FormSection("自動エスカレーション", icon: "arrow.triangle.2.circlepath") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(EscalationRule.defaults) { rule in
                    HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                        Image(systemName: rule.action.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(rule.action.color)
                            .frame(width: 16)
                            .padding(.top, 1)
                        Text(rule.label)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    private func filterControl(_ warnings: [ModWarning]) -> some View {
        HStack {
            SectionLabel(title: "警告リスト")
            Spacer()
            Button {
                withAnimation { showRevoked.toggle() }
            } label: {
                Label(showRevoked ? "取り消し済みを隠す" : "取り消し済みを表示",
                      systemImage: showRevoked ? "eye.slash" : "eye")
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.accent)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
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

// MARK: - UserWarningRow

private struct UserWarningRow: View {
    let userId: String
    let displayName: String
    let warnings: [ModWarning]
    let onRevoke: (String) -> Void
    let onSelectUser: () -> Void
    @State private var isExpanded = true

    private var activeCount: Int { warnings.filter { !$0.isRevoked }.count }
    private var nextRule: EscalationRule? { EscalationRule.defaults.first { $0.threshold > activeCount } }
    private var accentColor: Color {
        if activeCount >= 7 { return Theme.Color.statusBad }
        if activeCount >= 3 { return Theme.Color.statusWarn }
        return Theme.Color.accent
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.25)) { isExpanded.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    ZStack(alignment: .topTrailing) {
                        Avatar(name: displayName, size: 40, accentColor: accentColor)
                        Text("\(activeCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.Color.accentInk)
                            .padding(4)
                            .background(Theme.Color.accent)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Button(action: onSelectUser) {
                            Text(displayName)
                                .font(Theme.Font.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.Color.textPrimary)
                        }
                        .buttonStyle(.plain)
                        if let rule = nextRule {
                            Label("次: \(rule.label)", systemImage: "arrow.right.circle.fill")
                                .font(Theme.Font.caption2)
                                .foregroundStyle(rule.action.color)
                        } else {
                            Text("BAN閾値に達しています")
                                .font(Theme.Font.caption2)
                                .foregroundStyle(Theme.Color.statusBad)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.sm)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .background(Theme.Color.line)
                    .padding(.horizontal, Theme.Spacing.sm)
                VStack(spacing: 0) {
                    ForEach(Array(warnings.sorted { $0.createdAt > $1.createdAt }.enumerated()), id: \.element.id) { idx, w in
                        WarningRowView(warning: w) { onRevoke(w.id) }
                        if idx < warnings.count - 1 {
                            Divider()
                                .background(Theme.Color.line)
                                .padding(.leading, 40)
                        }
                    }
                }
                .padding(Theme.Spacing.xs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(duration: 0.25), value: isExpanded)
    }
}

private struct WarningRowView: View {
    let warning: ModWarning
    let onRevoke: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: warning.isRevoked ? "checkmark.circle" : "exclamationmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(warning.isRevoked ? Theme.Color.textTertiary : Theme.Color.statusWarn)
            VStack(alignment: .leading, spacing: 2) {
                Text(warning.reason)
                    .font(Theme.Font.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(warning.isRevoked ? Theme.Color.textTertiary : Theme.Color.textPrimary)
                    .strikethrough(warning.isRevoked)
                HStack(spacing: 4) {
                    Text(warning.staffName)
                    Text("·")
                    Text(warning.createdAt.formatted(.relative(presentation: .named)))
                        .monospaced()
                }
                .font(Theme.Font.caption2)
                .foregroundStyle(Theme.Color.textTertiary)
            }
            Spacer()
            if !warning.isRevoked {
                Button("取り消し", action: onRevoke)
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, 3)
                    .background(Theme.Color.surfaceRaised)
                    .clipShape(Capsule())
            } else {
                Text("取り消し済み")
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
            }
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.vertical, Theme.Spacing.xs)
        .background(warning.isRevoked ? Color.clear : Theme.Color.surfaceRaised.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
    }
}

// MARK: - AddWarningSheet

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
            ZStack {
                Theme.Color.bg.ignoresSafeArea()
                form
            }
            .navigationTitle("警告を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSubmitting {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button("追加") { Task { await submit() } }
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.Color.accent)
                            .disabled(selectedMember == nil || reason.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .task { await loadMembers() }
    }

    private var form: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                memberPickerSection
                reasonSection
            }
            .padding(Theme.Spacing.md)
        }
    }

    // MARK: - Member Picker

    private var memberPickerSection: some View {
        FormSection("対象メンバー", icon: "person", isRequired: true) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let m = selectedMember {
                    HStack(spacing: Theme.Spacing.sm) {
                        Avatar(name: m.displayName, size: 36, accentColor: Theme.Color.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.displayName)
                                .font(Theme.Font.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.Color.textPrimary)
                            Text("@\(m.username)")
                                .font(Theme.Font.caption2)
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                        Spacer()
                        Button {
                            withAnimation { selectedMember = nil }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.Color.textTertiary)
                                .font(.system(size: 18))
                        }
                    }
                    .padding(Theme.Spacing.xs)
                    .background(Theme.Color.accentDim)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.button)
                            .stroke(Theme.Color.accent.opacity(0.3), lineWidth: 1)
                    )
                }

                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.Color.textTertiary)
                    TextField("名前で検索", text: $memberSearch)
                        .font(Theme.Font.body)
                    if !memberSearch.isEmpty {
                        Button { memberSearch = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                    }
                }
                .padding(Theme.Spacing.xs)
                .background(Theme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.button)
                        .stroke(Theme.Color.line, lineWidth: 1)
                )

                if isLoadingMembers {
                    HStack { Spacer(); ProgressView().tint(Theme.Color.accent); Spacer() }
                        .padding(Theme.Spacing.md)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredMembers.prefix(30).enumerated()), id: \.element.id) { idx, member in
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
                            if idx < min(filteredMembers.count, 30) - 1 {
                                Divider()
                                    .background(Theme.Color.line)
                                    .padding(.leading, 52)
                            }
                        }
                    }
                    .background(Theme.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.button)
                            .stroke(Theme.Color.line, lineWidth: 1)
                    )

                    if filteredMembers.count > 30 {
                        Text("さらに\(filteredMembers.count - 30)人います。検索で絞り込んでください。")
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.textTertiary)
                            .padding(.top, Theme.Spacing.xs)
                    }
                }
            }
        }
    }

    // MARK: - Reason

    private var reasonSection: some View {
        FormSection("理由", icon: "text.bubble", isRequired: true) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: Theme.Spacing.xs) {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            reason = preset
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text(preset)
                                .font(Theme.Font.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(reason == preset ? Theme.Color.accentInk : Theme.Color.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.xs)
                                .background(reason == preset ? Theme.Color.accent : Theme.Color.surface)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radius.button)
                                        .stroke(Theme.Color.line, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                TextField("詳細・カスタム理由を入力", text: $reason, axis: .vertical)
                    .font(Theme.Font.body)
                    .padding(Theme.Spacing.sm)
                    .lineLimit(2...4)
                    .background(Theme.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.button)
                            .stroke(Theme.Color.line, lineWidth: 1)
                    )

                if let member = selectedMember {
                    escalationPreview(for: member)
                }
            }
        }
    }

    private func escalationPreview(for member: Member) -> some View {
        let rule = EscalationRule.defaults.first
        return Group {
            if let rule {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: rule.action.icon)
                        .foregroundStyle(rule.action.color)
                    Text("この警告で \(rule.label) が自動実行されます")
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .padding(Theme.Spacing.xs)
                .background(rule.action.color.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
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
            HStack(spacing: Theme.Spacing.sm) {
                Avatar(name: member.displayName, size: 32, accentColor: Theme.Color.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(member.displayName)
                        .font(Theme.Font.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text("@\(member.username)")
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Color.accent)
                        .font(.system(size: 18))
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(isSelected ? Theme.Color.accentDim : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
