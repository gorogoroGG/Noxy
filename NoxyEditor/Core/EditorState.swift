import Foundation
import SwiftUI

// MARK: - Editor Mode

enum EditorMode {
    case preview   // プレビューモード: ボタン操作・画面遷移が有効
    case edit      // 編集モード: コンポーネント選択・プロパティ編集が有効
}

// MARK: - EditorState

@Observable
final class EditorState {
    static let shared = EditorState()

    var selectedComponentPath: String?
    var editorMode: EditorMode = .edit       // デフォルトは編集モード
    var changes: [ChangeRecord] = []
    var initialSnapshot: [String: String] = [:]
    var isDiffPanelVisible = false
    var lastScreenshotPath: String?

    private init() {}

    func recordChange(componentPath: String, propertyName: String, oldValue: String, newValue: String) {
        // 同一 (componentPath, propertyName) の既存レコードを探す
        if let idx = changes.firstIndex(where: {
            $0.componentPath == componentPath && $0.propertyName == propertyName
        }) {
            let original = changes[idx].oldValue
            if newValue == original {
                // 元の値に戻った → レコードを削除
                changes.remove(at: idx)
            } else {
                // 同じキーの変更を上書き（oldValue は最初の値を保持）
                changes[idx] = ChangeRecord(
                    componentPath: componentPath,
                    propertyName: propertyName,
                    oldValue: original,
                    newValue: newValue
                )
            }
        } else {
            // 新規変更のみ追加（元の値と同じなら無視）
            guard oldValue != newValue else { return }
            changes.append(ChangeRecord(
                componentPath: componentPath,
                propertyName: propertyName,
                oldValue: oldValue,
                newValue: newValue
            ))
        }
    }

    func takeSnapshot(_ snapshot: [String: String]) {
        initialSnapshot = snapshot
    }

    func generateReport() -> DiffReport {
        DiffReport(changes: changes, generatedAt: Date())
    }

    func reset() {
        selectedComponentPath = nil
        changes = []
        initialSnapshot = [:]
        isDiffPanelVisible = false
        lastScreenshotPath = nil
    }
}
