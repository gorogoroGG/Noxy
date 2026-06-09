import SwiftUI

struct ComponentTreeNode: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    var children: [ComponentTreeNode]
    var icon: String { children.isEmpty ? "square.fill" : "square.3.layers.3d" }
}

struct ComponentTree: View {
    @State private var editorState = EditorState.shared

    private var tree: [ComponentTreeNode] {
        [
            ComponentTreeNode(name: "RootView", path: "RootView", children: [
                ComponentTreeNode(name: "MainTabView", path: "RootView/MainTabView", children: [
                    ComponentTreeNode(name: "Dashboard", path: "RootView/MainTabView/Dashboard", children: [
                        ComponentTreeNode(name: "Header", path: "RootView/MainTabView/Dashboard/Header", children: [
                            ComponentTreeNode(name: "WelcomeCard",    path: "RootView/MainTabView/Dashboard/Header/WelcomeCard", children: []),
                            ComponentTreeNode(name: "ServerSelector", path: "RootView/MainTabView/Dashboard/Header/ServerSelector", children: []),
                        ]),
                        ComponentTreeNode(name: "QuickActions", path: "RootView/MainTabView/Dashboard/QuickActions", children: []),
                        ComponentTreeNode(name: "StatsGrid",    path: "RootView/MainTabView/Dashboard/StatsGrid",    children: []),
                        ComponentTreeNode(name: "Notifications",path: "RootView/MainTabView/Dashboard/Notifications",children: []),
                    ]),
                    ComponentTreeNode(name: "Features",     path: "RootView/MainTabView/Features",     children: []),
                    ComponentTreeNode(name: "Automation",   path: "RootView/MainTabView/Automation",   children: []),
                    ComponentTreeNode(name: "Moderation",   path: "RootView/MainTabView/Moderation",   children: []),
                ]),
            ]),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Label("コンポーネント", systemImage: "square.3.layers.3d")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(tree) { node in
                        TreeNodeView(node: node, selectedPath: $editorState.selectedComponentPath, depth: 0)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .frame(minWidth: 210)
    }
}

// MARK: - TreeNodeView

struct TreeNodeView: View {
    let node: ComponentTreeNode
    @Binding var selectedPath: String?
    let depth: Int
    @State private var isExpanded = true

    private var isSelected: Bool { selectedPath == node.path }
    private var hasChildren: Bool { !node.children.isEmpty }
    private let indent: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ノード行
            HStack(spacing: 0) {
                // インデント
                HStack(spacing: 0) {
                    ForEach(0..<depth, id: \.self) { _ in
                        Color.border.frame(width: 1)
                            .padding(.horizontal, (indent - 1) / 2)
                    }
                }
                .frame(width: CGFloat(depth) * indent)

                // 展開トグル or スペーサー
                if hasChildren {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.textTertiary)
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    // リーフノードのドット
                    Circle()
                        .fill(Color.textTertiary.opacity(0.5))
                        .frame(width: 4, height: 4)
                        .frame(width: 16, height: 16)
                }

                // ノードラベル（選択はここだけ）
                Button {
                    selectedPath = node.path
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: hasChildren ? "square.3.layers.3d" : "square.fill")
                            .font(.system(size: 10))
                            .foregroundColor(isSelected ? .accentIndigo : (hasChildren ? .textSecondary : .textTertiary))

                        Text(node.name)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? .accentIndigo : .textPrimary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(isSelected ? Color.accentIndigo.opacity(0.12) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 6)

            // 子ノード
            if isExpanded && hasChildren {
                ForEach(node.children) { child in
                    TreeNodeView(node: child, selectedPath: $selectedPath, depth: depth + 1)
                }
            }
        }
    }
}
