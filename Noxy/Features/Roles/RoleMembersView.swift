import SwiftUI

// MARK: - RoleMembersView

struct RoleMembersView: View {
    let role: DiscordRole
    let guildId: String

    @Environment(\.services) private var services
    @Environment(\.dismiss)  private var dismiss

    @State private var members: [Member] = []
    @State private var isLoading = true

    // 初期ホルダー（API取得後に確定）
    @State private var initialHolders: Set<String> = []
    // 現在の編集状態
    @State private var pendingState: Set<String> = []

    @State private var searchText = ""
    @State private var applyState: ApplyState = .idle
    @State private var failedIds: Set<String> = []
    @State private var showConfirmAlert = false
    @State private var filterMode: FilterMode = .all

    enum ApplyState { case idle, applying(done: Int, total: Int), done, partial }
    enum FilterMode: String, CaseIterable {
        case all = "全員"
        case hasRole = "付与済み"
        case noRole = "未付与"
    }

    // MARK: - Computed

    private var membersToAdd:    [Member] { members.filter {  pendingState.contains($0.id) && !initialHolders.contains($0.id) } }
    private var membersToRemove: [Member] { members.filter { !pendingState.contains($0.id) &&  initialHolders.contains($0.id) } }
    private var hasChanges: Bool { !membersToAdd.isEmpty || !membersToRemove.isEmpty }

    private var filtered: [Member] {
        var base = members
        if !searchText.isEmpty {
            base = base.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.username.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch filterMode {
        case .all:     break
        case .hasRole: base = base.filter { pendingState.contains($0.id) }
        case .noRole:  base = base.filter { !pendingState.contains($0.id) }
        }
        return base.sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                roleHeaderBar
                filterBar
                memberList
            }
            .background(Color.bgPrimary)

            if hasChanges {
                applyBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: hasChanges)
        .navigationTitle("メンバー管理")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "名前で検索")
        .toolbar { toolbarReset }
        .alert("変更を適用しますか？", isPresented: $showConfirmAlert) {
            Button("適用", role: .destructive) { Task { await applyChanges() } }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(confirmMessage)
        }
        .task { await loadMembers() }
    }

    // MARK: - Role Header Bar

    private var roleHeaderBar: some View {
        HStack(spacing: .spacing12) {
            Circle()
                .fill(role.swiftUIColor)
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(Color.border, lineWidth: role.color == 0 ? 1 : 0))

            Text(role.name)
                .font(.bodySmall)
                .fontWeight(.semibold)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            // カウント
            HStack(spacing: .spacing4) {
                Text("\(pendingState.count)人付与済み")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
                Text("/ \(members.count)人中")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, .spacing16)
        .padding(.vertical, .spacing10)
        .background(Color.bgSurface)
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .spacing8) {
                ForEach(FilterMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { filterMode = mode }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 4) {
                            Text(mode.rawValue)
                                .font(.captionRegular)
                                .fontWeight(filterMode == mode ? .semibold : .regular)
                            if mode == .hasRole {
                                Text("\(pendingState.count)")
                                    .font(.captionSmall)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(.white.opacity(0.25))
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundStyle(filterMode == mode ? .white : Color.textSecondary)
                        .padding(.horizontal, .spacing12)
                        .padding(.vertical, .spacing6)
                        .background(filterMode == mode ? Color.accentIndigo : Color.bgSurface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(filterMode == mode ? Color.clear : Color.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, .spacing16)
            .padding(.vertical, .spacing10)
        }
        .background(Color.bgPrimary)
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Member List

    @ViewBuilder
    private var memberList: some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView().tint(Color.accentIndigo)
                Text("メンバーを読み込み中...")
                    .font(.bodySmall)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top, .spacing8)
                Spacer()
            }
        } else if filtered.isEmpty {
            VStack {
                Spacer()
                Image(systemName: "person.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.bottom, .spacing8)
                Text("該当するメンバーがいません")
                    .font(.bodySmall)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: .spacing4) {
                    // ペンディング差分のヒント
                    if hasChanges {
                        diffHintRow
                            .padding(.horizontal, .spacing16)
                            .padding(.top, .spacing8)
                    }

                    ForEach(filtered) { member in
                        MemberRoleRow(
                            member: member,
                            hasRole: pendingState.contains(member.id),
                            originallyHad: initialHolders.contains(member.id),
                            isFailed: failedIds.contains(member.id),
                            isApplying: {
                                if case .applying = applyState { return true }
                                return false
                            }()
                        ) {
                            toggle(member)
                        }
                        .padding(.horizontal, .spacing16)
                    }

                    Color.clear.frame(height: 88)
                }
                .padding(.top, hasChanges ? 0 : .spacing8)
            }
        }
    }

    // MARK: - Diff Hint

    private var diffHintRow: some View {
        HStack(spacing: .spacing16) {
            if !membersToAdd.isEmpty {
                Label("\(membersToAdd.count)人を追加", systemImage: "plus.circle.fill")
                    .font(.captionSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentGreen)
            }
            if !membersToRemove.isEmpty {
                Label("\(membersToRemove.count)人から削除", systemImage: "minus.circle.fill")
                    .font(.captionSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentRed)
            }
            Spacer()
            Button("リセット") {
                withAnimation { pendingState = initialHolders }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .font(.captionSmall)
            .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, .spacing12)
        .padding(.vertical, .spacing8)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
    }

    // MARK: - Apply Bar

    private var applyBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: .spacing12) {
                // 差分サマリー
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: .spacing8) {
                        if !membersToAdd.isEmpty {
                            Text("+\(membersToAdd.count)")
                                .font(.captionSmall).fontWeight(.bold)
                                .foregroundStyle(Color.accentGreen)
                        }
                        if !membersToRemove.isEmpty {
                            Text("-\(membersToRemove.count)")
                                .font(.captionSmall).fontWeight(.bold)
                                .foregroundStyle(Color.accentRed)
                        }
                    }
                    Text("未保存の変更があります")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()

                // Apply button
                Button {
                    showConfirmAlert = true
                } label: {
                    applyButtonLabel
                }
                .buttonStyle(.plain)
                .disabled({ if case .applying = applyState { return true }; return false }())
            }
            .padding(.horizontal, .spacing16)
            .padding(.vertical, .spacing12)
            .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var applyButtonLabel: some View {
        switch applyState {
        case .idle:
            Text("変更を適用")
                .font(.bodySmall).fontWeight(.semibold).foregroundStyle(.white)
                .padding(.horizontal, .spacing20).frame(height: 44)
                .background(Color.accentIndigo)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))

        case .applying(let done, let total):
            HStack(spacing: .spacing8) {
                ProgressView(value: Double(done), total: Double(total))
                    .tint(.white)
                    .frame(width: 80)
                Text("\(done)/\(total)")
                    .font(.captionSmall).foregroundStyle(.white)
            }
            .padding(.horizontal, .spacing20).frame(height: 44)
            .background(Color.accentIndigo.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))

        case .done:
            Label("適用完了", systemImage: "checkmark")
                .font(.bodySmall).fontWeight(.semibold).foregroundStyle(.white)
                .padding(.horizontal, .spacing20).frame(height: 44)
                .background(Color.accentGreen)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))

        case .partial:
            Label("一部失敗", systemImage: "exclamationmark.triangle")
                .font(.bodySmall).fontWeight(.semibold).foregroundStyle(.white)
                .padding(.horizontal, .spacing20).frame(height: 44)
                .background(Color.accentOrange)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarReset: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    withAnimation { pendingState = Set(members.map(\.id)) }
                } label: {
                    Label("全員に付与", systemImage: "plus.circle")
                }
                Button(role: .destructive) {
                    withAnimation { pendingState = [] }
                } label: {
                    Label("全員から削除", systemImage: "minus.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(Color.accentIndigo)
            }
        }
    }

    // MARK: - Logic

    private func toggle(_ member: Member) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if pendingState.contains(member.id) {
                pendingState.remove(member.id)
            } else {
                pendingState.insert(member.id)
            }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private var confirmMessage: String {
        var parts: [String] = []
        if !membersToAdd.isEmpty    { parts.append("\(membersToAdd.count)人に「\(role.name)」を付与") }
        if !membersToRemove.isEmpty { parts.append("\(membersToRemove.count)人から「\(role.name)」を削除") }
        return parts.joined(separator: "、") + "します。"
    }

    private func applyChanges() async {
        let ops: [(member: Member, add: Bool)] =
            membersToAdd.map { ($0, true) } + membersToRemove.map { ($0, false) }
        let total = ops.count
        guard total > 0 else { return }

        applyState = .applying(done: 0, total: total)
        failedIds = []
        var done = 0
        var failed: Set<String> = []

        await withTaskGroup(of: (String, Bool).self) { group in
            for op in ops {
                group.addTask {
                    do {
                        if op.add {
                            try await services.members.addRole(memberId: op.member.id, guildId: guildId, roleId: role.id)
                        } else {
                            try await services.members.removeRole(memberId: op.member.id, guildId: guildId, roleId: role.id)
                        }
                        return (op.member.id, true)
                    } catch {
                        return (op.member.id, false)
                    }
                }
            }
            for await (id, success) in group {
                done += 1
                if !success { failed.insert(id) }
                await MainActor.run {
                    applyState = .applying(done: done, total: total)
                }
            }
        }

        await MainActor.run {
            failedIds = failed
            // 成功したものだけ initialHolders に反映
            for op in ops where !failed.contains(op.member.id) {
                if op.add { initialHolders.insert(op.member.id) }
                else      { initialHolders.remove(op.member.id) }
            }
            applyState = failed.isEmpty ? .done : .partial
            UINotificationFeedbackGenerator().notificationOccurred(failed.isEmpty ? .success : .warning)
        }

        try? await Task.sleep(for: .seconds(2))
        await MainActor.run {
            applyState = .idle
        }
    }

    private func loadMembers() async {
        isLoading = true
        // 実際のAPI: await services.members.fetchMembers(guildId: guildId)
        try? await Task.sleep(for: .milliseconds(400))
        let loaded = MockData.members
        let holders = Set(loaded.filter { $0.roles.contains(role.name) }.map(\.id))
        await MainActor.run {
            members = loaded
            initialHolders = holders
            pendingState = holders
            isLoading = false
        }
    }
}

// MARK: - MemberRoleRow

private struct MemberRoleRow: View {
    let member: Member
    let hasRole: Bool
    let originallyHad: Bool
    let isFailed: Bool
    let isApplying: Bool
    let onTap: () -> Void

    private var changeIndicator: ChangeIndicator {
        if isFailed { return .failed }
        if hasRole && !originallyHad { return .adding }
        if !hasRole && originallyHad { return .removing }
        return .none
    }

    enum ChangeIndicator { case none, adding, removing, failed }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: .spacing12) {
                // Avatar
                ZStack(alignment: .bottomTrailing) {
                    Avatar(name: member.displayName, size: 40,
                           accentColor: member.isBoosting ? .accentPink : .accentIndigo)
                    Circle()
                        .fill(member.status.color)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.bgSurface, lineWidth: 1.5))
                        .offset(x: 2, y: 2)
                }
                .frame(width: 44, height: 44)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.displayName)
                        .font(.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                    Text("@\(member.username)")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()

                // Change badge
                if changeIndicator != .none {
                    changeBadge
                }

                // Checkbox
                roleIndicator
            }
            .padding(.horizontal, .spacing12)
            .padding(.vertical, .spacing10)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                    .stroke(rowBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isApplying)
    }

    @ViewBuilder
    private var changeBadge: some View {
        switch changeIndicator {
        case .adding:
            Text("追加")
                .font(.captionSmall).fontWeight(.semibold)
                .foregroundStyle(Color.accentGreen)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.accentGreen.opacity(0.12))
                .clipShape(Capsule())
        case .removing:
            Text("削除")
                .font(.captionSmall).fontWeight(.semibold)
                .foregroundStyle(Color.accentRed)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.accentRed.opacity(0.1))
                .clipShape(Capsule())
        case .failed:
            Text("失敗")
                .font(.captionSmall).fontWeight(.semibold)
                .foregroundStyle(Color.accentOrange)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.accentOrange.opacity(0.12))
                .clipShape(Capsule())
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var roleIndicator: some View {
        if isApplying && changeIndicator != .none {
            ProgressView()
                .scaleEffect(0.8)
                .frame(width: 28, height: 28)
        } else {
            Image(systemName: hasRole ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(hasRole ? Color.accentIndigo : Color.border)
                .animation(.spring(duration: 0.2), value: hasRole)
        }
    }

    private var rowBackground: Color {
        switch changeIndicator {
        case .adding:   return Color.accentGreen.opacity(0.05)
        case .removing: return Color.accentRed.opacity(0.05)
        case .failed:   return Color.accentOrange.opacity(0.05)
        case .none:     return Color.bgSurface
        }
    }

    private var rowBorder: Color {
        switch changeIndicator {
        case .adding:   return Color.accentGreen.opacity(0.25)
        case .removing: return Color.accentRed.opacity(0.2)
        case .failed:   return Color.accentOrange.opacity(0.3)
        case .none:     return Color.border
        }
    }
}


#Preview {
    NavigationStack {
        RoleMembersView(role: DiscordRole.mockRoles[1], guildId: "g001")
    }
    .environment(\.services, ServiceContainer.live())
}
