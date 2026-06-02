import SwiftUI

struct ModWarningView: View {
    @State private var warnings: [ModWarning] = ModWarning.mock
    @State private var showAddSheet = false
    @State private var searchText = ""
    @State private var showRevoked = false

    // ユーザーごとにグルーピング
    private var grouped: [(user: String, displayName: String, warnings: [ModWarning])] {
        var result: [String: (displayName: String, warnings: [ModWarning])] = [:]
        let base = showRevoked ? warnings : warnings.filter { !$0.isRevoked }
        let filtered = searchText.isEmpty ? base : base.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
        for w in filtered {
            if result[w.userId] == nil { result[w.userId] = (w.displayName, []) }
            result[w.userId]!.warnings.append(w)
        }
        return result.map { (user: $0.key, displayName: $0.value.displayName, warnings: $0.value.warnings) }
            .sorted { lhs, rhs in
                let la = lhs.warnings.filter { !$0.isRevoked }.count
                let ra = rhs.warnings.filter { !$0.isRevoked }.count
                return la > ra
            }
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: .spacing12) {
                    escalationRulesCard
                    filterRow

                    if grouped.isEmpty {
                        emptyState
                            .padding(.top, .spacing32)
                    } else {
                        ForEach(grouped, id: \.user) { group in
                            UserWarningCard(
                                displayName: group.displayName,
                                warnings: group.warnings,
                                onRevoke: { id in revokeWarning(id) }
                            )
                        }
                    }

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, .spacing16)
                .padding(.top, .spacing12)
            }
        }
        .searchable(text: $searchText, prompt: "ユーザー名で検索")
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
            AddWarningSheet { newWarning in
                warnings.append(newWarning)
            }
        }
    }

    // MARK: - Escalation Rules Card

    private var escalationRulesCard: some View {
        VStack(alignment: .leading, spacing: .spacing10) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(Color.accentPurple)
                Text("自動エスカレーションルール")
                    .font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                Spacer()
            }
            ForEach(EscalationRule.defaults) { rule in
                HStack(spacing: .spacing8) {
                    Image(systemName: rule.action.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(rule.action.color)
                        .frame(width: 20)
                    Text(rule.label)
                        .font(.captionRegular)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(.spacing12)
        .background(Color.accentPurple.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .overlay(RoundedRectangle(cornerRadius: .cornerRadiusMedium).stroke(Color.accentPurple.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Filter Row

    private var filterRow: some View {
        HStack {
            Text("\(grouped.count)人のユーザーに警告")
                .font(.captionSmall).foregroundStyle(Color.textTertiary)
            Spacer()
            Button {
                withAnimation { showRevoked.toggle() }
            } label: {
                Label(showRevoked ? "取り消し済みを非表示" : "取り消し済みを表示",
                      systemImage: showRevoked ? "eye.slash" : "eye")
                    .font(.captionSmall)
                    .foregroundStyle(Color.accentIndigo)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: .spacing12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40)).foregroundStyle(Color.textTertiary.opacity(0.5))
            Text("警告はありません")
                .font(.titleMedium).foregroundStyle(Color.textPrimary)
        }
    }

    // MARK: - Actions

    private func revokeWarning(_ id: String) {
        if let i = warnings.firstIndex(where: { $0.id == id }) {
            withAnimation { warnings[i].isRevoked = true }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

// MARK: - UserWarningCard

private struct UserWarningCard: View {
    let displayName: String
    let warnings: [ModWarning]
    let onRevoke: (String) -> Void

    @State private var isExpanded = true

    private var activeCount: Int { warnings.filter { !$0.isRevoked }.count }
    private var nextRule: EscalationRule? {
        EscalationRule.defaults.first { $0.threshold > activeCount }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.spring(duration: 0.25)) { isExpanded.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: .spacing12) {
                    // Avatar with warning badge
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(warningColor.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Text(displayName.prefix(1).uppercased())
                            .font(.bodyRegular).fontWeight(.bold)
                            .foregroundStyle(warningColor)

                        Text("\(activeCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(warningColor)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                        if let rule = nextRule {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.captionSmall).foregroundStyle(rule.action.color)
                                Text("次: \(rule.label)")
                                    .font(.captionSmall).foregroundStyle(rule.action.color)
                            }
                        } else {
                            Text("BAN済み または BAN閾値超え")
                                .font(.captionSmall).foregroundStyle(Color(uiColor: UIColor(hex: 0xEF4444)))
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.captionSmall).foregroundStyle(Color.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(.spring(duration: 0.25), value: isExpanded)
                }
                .padding(.spacing12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal, .spacing12)

                VStack(spacing: .spacing4) {
                    ForEach(warnings) { warning in
                        WarningRow(warning: warning, onRevoke: { onRevoke(warning.id) })
                    }
                }
                .padding(.spacing8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(warningColor.opacity(0.3), lineWidth: 1)
        )
        .animation(.spring(duration: 0.25), value: isExpanded)
    }

    private var warningColor: Color {
        if activeCount >= 7 { return Color(uiColor: UIColor(hex: 0xEF4444)) }
        if activeCount >= 5 { return .accentOrange }
        if activeCount >= 3 { return .accentOrange }
        return .accentIndigo
    }
}

// MARK: - WarningRow

private struct WarningRow: View {
    let warning: ModWarning
    let onRevoke: () -> Void

    var body: some View {
        HStack(spacing: .spacing10) {
            Image(systemName: warning.isRevoked ? "xmark.circle" : "exclamationmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(warning.isRevoked ? Color.textTertiary : Color.accentOrange)

            VStack(alignment: .leading, spacing: 2) {
                Text(warning.reason)
                    .font(.captionRegular).fontWeight(.medium)
                    .foregroundStyle(warning.isRevoked ? Color.textTertiary : Color.textPrimary)
                    .strikethrough(warning.isRevoked)
                HStack(spacing: .spacing6) {
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
                    .padding(.horizontal, .spacing8).padding(.vertical, 4)
                    .background(Color.bgElevated)
                    .clipShape(Capsule())
            } else {
                Text("取り消し済み")
                    .font(.captionSmall).foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, .spacing8).padding(.vertical, .spacing6)
        .background(warning.isRevoked ? Color.clear : Color.bgElevated.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
    }
}

// MARK: - AddWarningSheet

private struct AddWarningSheet: View {
    let onAdd: (ModWarning) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedUser: String = "m010"
    @State private var reason = ""
    @State private var customReason = ""
    @FocusState private var reasonFocused: Bool

    private let mockTargets: [(id: String, name: String)] = [
        ("m010", "ShadowX"),
        ("m002", "ProPlayer99"),
        ("m006", "雪ゲーマー"),
        ("m009", "リカちゃん"),
    ]

    private let presetReasons = ["スパム", "暴言", "荒らし", "規約違反", "差別的発言", "その他"]

    var body: some View {
        NavigationView {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: .spacing16) {
                        // User picker
                        VStack(alignment: .leading, spacing: .spacing8) {
                            Text("対象ユーザー")
                                .font(.captionSmall).foregroundStyle(Color.textTertiary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: .spacing8) {
                                    ForEach(mockTargets, id: \.id) { target in
                                        Button {
                                            selectedUser = target.id
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        } label: {
                                            Text(target.name)
                                                .font(.bodySmall).fontWeight(selectedUser == target.id ? .semibold : .regular)
                                                .foregroundStyle(selectedUser == target.id ? .white : Color.textSecondary)
                                                .padding(.horizontal, .spacing12).padding(.vertical, .spacing8)
                                                .background(selectedUser == target.id ? Color.accentIndigo : Color.bgSurface)
                                                .clipShape(Capsule())
                                                .overlay(Capsule().stroke(Color.border, lineWidth: selectedUser == target.id ? 0 : 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // Reason picker
                        VStack(alignment: .leading, spacing: .spacing8) {
                            Text("理由")
                                .font(.captionSmall).foregroundStyle(Color.textTertiary)
                            LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: .spacing8) {
                                ForEach(presetReasons, id: \.self) { preset in
                                    Button {
                                        reason = preset == "その他" ? "" : preset
                                        if preset == "その他" { reasonFocused = true }
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
                                .font(.bodySmall).padding(.spacing12)
                                .background(Color.bgSurface)
                                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
                                .overlay(RoundedRectangle(cornerRadius: .cornerRadiusSmall).stroke(Color.border, lineWidth: 1))
                                .focused($reasonFocused)
                                .lineLimit(2...4)
                        }

                        // Next auto action
                        nextActionPreview
                    }
                    .padding(.spacing16)
                }
            }
            .navigationTitle("警告を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        addWarning()
                    }
                    .fontWeight(.semibold).foregroundStyle(Color.accentOrange)
                    .disabled(reason.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var nextActionPreview: some View {
        let currentCount = ModWarning.mock.filter { $0.userId == selectedUser && !$0.isRevoked }.count
        let nextCount = currentCount + 1
        let rule = EscalationRule.defaults.first { $0.threshold == nextCount }

        return Group {
            if let rule {
                HStack(spacing: .spacing8) {
                    Image(systemName: rule.action.icon)
                        .foregroundStyle(rule.action.color)
                    Text("この警告が\(nextCount)回目のため、\(rule.label)が自動実行されます")
                        .font(.captionRegular).foregroundStyle(Color.textSecondary)
                }
                .padding(.spacing12)
                .background(rule.action.color.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
            }
        }
    }

    private func addWarning() {
        let target = mockTargets.first { $0.id == selectedUser }
        let currentCount = ModWarning.mock.filter { $0.userId == selectedUser && !$0.isRevoked }.count
        let nextCount = currentCount + 1
        let autoAction: String? = {
            guard let rule = EscalationRule.defaults.first(where: { $0.threshold == nextCount }) else { return nil }
            switch rule.action {
            case .timeout(let h): return "timeout_\(h)h"
            case .ban:            return "ban"
            }
        }()

        let warning = ModWarning(
            id: UUID().uuidString,
            userId: selectedUser,
            username: target?.name.lowercased() ?? selectedUser,
            displayName: target?.name ?? selectedUser,
            reason: reason.trimmingCharacters(in: .whitespaces),
            staffName: "Admin",
            createdAt: .now,
            isRevoked: false
        )
        onAdd(warning)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        _ = autoAction  // 実際のAPIではこれを送信する
        dismiss()
    }
}
