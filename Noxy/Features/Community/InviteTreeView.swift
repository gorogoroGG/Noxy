import SwiftUI

struct InviteTreeView: View {
    let guildId: String
    let rootUserId: String
    let rootName: String

    @Environment(\.services) private var services

    @State private var root: InviteTreeNode?
    @State private var isLoading = true
    @State private var expandedIds: Set<String> = []

    var body: some View {
        Group {
            if isLoading {
                ProgressView("ツリーを読み込み中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let root {
                treeContent(root: root)
            } else {
                ContentUnavailableView(
                    "データなし",
                    systemImage: "person.3.slash",
                    description: Text("招待ツリーを取得できませんでした")
                )
            }
        }
        .navigationTitle("\(rootName)の招待ツリー")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("すべて展開", systemImage: "arrow.down.right.and.arrow.up.left") {
                        expandAll()
                    }
                    Button("すべて折りたたむ", systemImage: "arrow.up.left.and.arrow.down.right") {
                        expandedIds.removeAll()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task { await load() }
    }

    // MARK: - Tree

    private func treeContent(root: InviteTreeNode) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TreeNodeView(
                    node: root,
                    depth: 0,
                    isLast: true,
                    expandedIds: $expandedIds
                )
            }
            .padding(.horizontal, .spacing16)
            .padding(.vertical, .spacing16)
        }
        .overlay(alignment: .bottomTrailing) {
            treeLegend
        }
    }

    // MARK: - Legend

    private var treeLegend: some View {
        VStack(alignment: .leading, spacing: .spacing6) {
            legendItem(color: .accentGreen, label: "在籍中")
            legendItem(color: Color.red.opacity(0.7), label: "退出済み")
        }
        .padding(.horizontal, .spacing12)
        .padding(.vertical, .spacing8)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .padding(.trailing, .spacing16)
        .padding(.bottom, .spacing16)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: .spacing6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 10)).foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Data

    private func load() async {
        if let result = try? await services.inviteTracker.fetchTree(
            guildId: guildId, userId: rootUserId
        ) {
            root = result
            // デフォルトで第1階層まで展開
            expandedIds.insert(result.userId)
        }
        isLoading = false
    }

    private func expandAll() {
        guard let root else { return }
        var ids: Set<String> = []
        func collect(_ node: InviteTreeNode) {
            ids.insert(node.userId)
            node.children.forEach { collect($0) }
        }
        collect(root)
        expandedIds = ids
    }
}

// MARK: - Tree Node View

private struct TreeNodeView: View {
    let node: InviteTreeNode
    let depth: Int
    let isLast: Bool
    @Binding var expandedIds: Set<String>

    private var isExpanded: Bool { expandedIds.contains(node.userId) }
    private var hasChildren: Bool { !node.children.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            nodeRow
            if isExpanded && hasChildren {
                childrenView
            }
        }
    }

    private var nodeRow: some View {
        HStack(spacing: 0) {
            // Depth indent + connector
            if depth > 0 {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: CGFloat(depth) * 20)
                // Vertical line
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Theme.Color.lineStrong.opacity(0.3))
                        .frame(width: 1.5)
                    Rectangle()
                        .fill(Theme.Color.lineStrong.opacity(0.3))
                        .frame(width: 12, height: 1.5)
                }
                .frame(width: 14, height: 36)
            }

            // Expand/collapse toggle
            if hasChildren {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        if isExpanded {
                            expandedIds.remove(node.userId)
                        } else {
                            expandedIds.insert(node.userId)
                        }
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentPurple.opacity(0.7))
                }
                .buttonStyle(.plain)
                .frame(width: 22)
            } else {
                Spacer().frame(width: 22)
            }

            Spacer().frame(width: .spacing8)

            // Avatar + status dot
            ZStack(alignment: .bottomTrailing) {
                AvatarCircle(displayName: node.displayName, size: 32)
                Circle()
                    .fill(node.isCurrentMember ? Color.accentGreen : Color.red.opacity(0.7))
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(Color.bgPrimary, lineWidth: 1.5))
                    .offset(x: 2, y: 2)
            }

            Spacer().frame(width: .spacing8)

            // Name + counts
            VStack(alignment: .leading, spacing: 2) {
                Text(node.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(node.isCurrentMember ? Color.textPrimary : Color.textSecondary)

                HStack(spacing: .spacing8) {
                    if node.directInvites > 0 {
                        Text("直接 \(node.directInvites)")
                            .font(.system(size: 9.5))
                            .foregroundStyle(Color.accentGreen)
                    }
                    if node.totalDescendants > 0 {
                        Text("派生 \(node.totalDescendants)")
                            .font(.system(size: 9.5))
                            .foregroundStyle(Color.accentPurple)
                    }
                    if let date = node.joinedAt {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 9))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }

            Spacer()
        }
        .frame(height: 48)
        .contentShape(Rectangle())
        .onTapGesture {
            if hasChildren {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    if isExpanded { expandedIds.remove(node.userId) }
                    else { expandedIds.insert(node.userId) }
                }
            }
        }
    }

    private var childrenView: some View {
        ForEach(Array(node.children.enumerated()), id: \.element.id) { idx, child in
            TreeNodeView(
                node: child,
                depth: depth + 1,
                isLast: idx == node.children.count - 1,
                expandedIds: $expandedIds
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InviteTreeView(guildId: "g001", rootUserId: "u001", rootName: "太郎")
    }
    .environment(AppState())
    .environment(\.services, ServiceContainer.mock())
}
