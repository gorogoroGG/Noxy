import SwiftUI

struct EditorMainWindow: View {
    @State private var editorState = EditorState.shared
    @State private var showResetAlert = false

    var body: some View {
        HSplitView {
            ComponentTree()
                .frame(minWidth: 210, idealWidth: 230, maxWidth: 320)

            PreviewCanvas()
                .frame(minWidth: 420)

            PropertyInspector()
                .frame(minWidth: 260, idealWidth: 280, maxWidth: 380)
        }
        .frame(minWidth: 1050, minHeight: 720)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // 変更件数バッジ付きDiffボタン
                Button(action: { editorState.isDiffPanelVisible.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.badge.plus")
                        if !editorState.changes.isEmpty {
                            Text("\(editorState.changes.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.accentRed)
                                .clipShape(Capsule())
                        }
                    }
                }
                .help("差分レポートを表示")
                .keyboardShortcut("d", modifiers: .command)

                Divider()

                Button(action: { showResetAlert = true }) {
                    Label("リセット", systemImage: "arrow.counterclockwise")
                }
                .help("すべての変更をリセット")
                .disabled(editorState.changes.isEmpty)
            }
        }
        .sheet(isPresented: $editorState.isDiffPanelVisible) {
            DiffOutputPanel()
        }
        .alert("変更をリセット", isPresented: $showResetAlert) {
            Button("リセット", role: .destructive) { editorState.reset() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(editorState.changes.count)件の変更がすべて削除されます。")
        }
    }
}
