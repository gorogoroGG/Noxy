import SwiftUI

struct DiffOutputPanel: View {
    @State private var editorState = EditorState.shared
    @State private var selectedFormat: DiffFormat = .markdown
    @State private var outputText = ""
    @State private var copyConfirmed = false

    enum DiffFormat: String, CaseIterable {
        case markdown = "Markdown"
        case json = "JSON"
    }

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("差分レポート")
                        .font(.title3.bold())
                    Text("\(editorState.changes.count)件の変更")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Picker("形式", selection: $selectedFormat) {
                    ForEach(DiffFormat.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(20)

            Divider()

            // テキストエディタ
            TextEditor(text: $outputText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color.bgElevated)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // ボタン行
            HStack(spacing: 10) {
                Button(action: copyToClipboard) {
                    Label(copyConfirmed ? "コピー済み ✓" : "クリップボードにコピー",
                          systemImage: copyConfirmed ? "checkmark.circle.fill" : "doc.on.doc")
                }
                .disabled(outputText.isEmpty)

                Button(action: saveToFile) {
                    Label("ファイル保存", systemImage: "arrow.down.circle")
                }
                .disabled(outputText.isEmpty)

                Spacer()

                Button("閉じる") { editorState.isDiffPanelVisible = false }
                    .keyboardShortcut(.escape)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 640, minHeight: 520)
        .background(Color.bgPrimary)
        .onAppear { updateOutput() }
        .onChange(of: selectedFormat) { _, _ in updateOutput() }
    }

    private func updateOutput() {
        let report = editorState.generateReport()
        outputText = selectedFormat == .markdown ? report.toMarkdown() : report.toJSON()
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(outputText, forType: .string)
        withAnimation {
            copyConfirmed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copyConfirmed = false }
        }
    }

    private func saveToFile() {
        let report = editorState.generateReport()
        let exportsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Dev/Noxy/NoxyEditor/exports")
        try? FileManager.default.createDirectory(at: exportsDir, withIntermediateDirectories: true)
        let timestamp = Int(Date().timeIntervalSince1970)
        let ext = selectedFormat == .markdown ? "md" : "json"
        let fileURL = exportsDir.appendingPathComponent("diff_\(timestamp).\(ext)")
        let content = selectedFormat == .markdown ? report.toMarkdown() : report.toJSON()
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
