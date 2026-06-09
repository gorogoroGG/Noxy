# NoxyEditor 実装プロンプト

## 概要

SwiftUIプロジェクトにUIエディタ（macOSターゲット）を追加するためのプロンプト集。XcodeのInterface BuilderやFigmaのような3ペインレイアウトのエディタを、既存のiOSプロジェクトに統合する。

---

## フェーズ1: プロンプト

```
以下の仕様で、既存のSwiftUI iOSプロジェクトにmacOSエディタを追加してください。

## 要件

### プロジェクト構造
- 既存のXcodeプロジェクト（Noxy.xcodeproj）に新しいmacOSターゲット「NoxyEditor」を追加
- 既存のデザインシステム（Colors.swift, Spacing.swift等）を共有
- ビルドし直すたびに状態がリセットされる（永続化なし）

### エディタUI（3ペインレイアウト）
- 左パネル: コンポーネント階層ツリー（OutlineGroup）
- 中央: iPhoneモックフレーム内のライブプレビュー
- 右パネル: 選択要素のプロパティインスペクター

### 実装ファイル構成
NoxyEditor/
├── NoxyEditorApp.swift          # @main macOSアプリ
├── Core/
│   ├── EditorState.swift        # @Observable グローバル状態
│   └── DiffTracker.swift        # 変更追跡
├── Views/
│   ├── EditorMainWindow.swift   # HSplitView 3ペイン
│   ├── ComponentTree.swift      # ツリー表示
│   ├── PreviewCanvas.swift      # iPhoneモック＋プレビュー
│   ├── PropertyInspector.swift  # 動的フォーム
│   └── DiffOutputPanel.swift    # 差分出力シート
├── Models/
│   ├── ChangeRecord.swift       # 変更レコード
│   └── DiffReport.swift         # JSON/Markdown生成
├── Utilities/
│   ├── ScreenshotManager.swift  # NSViewキャプチャ
│   └── iPhoneMockFrame.swift    # iPhoneフレームUI
└── Design/                      # 共有デザインファイル

### 技術仕様
- macOS 14.0以上ターゲット
- SwiftUI @Observable マクロ使用
- HSplitViewで3ペイン分割
- iPhoneモックは375x812ポイント（iPhone X相当）
- カラースキームはmacOS用にNSColorベースで実装

## 手順
1. NoxyEditor/ ディレクトリとサブディレクトリを作成
2. 各Swiftファイルを実装
3. xcodeproj gemを使用してmacOSターゲットを追加
4. ファイル参照とビルドフェーズを設定
5. ビルド確認

## 注意事項
- UIColorはmacOSで使えないため、NSColorに置き換え
- conditional compilation（#if os(iOS)）で両プラットフォーム対応
- 永続化は一切行わない（UserDefaults等不使用）
```

---

## フェーズ2: プロンプト

```
NoxyEditorの基本構造ができました。以下の機能を追加してください。

## 1. コンポーネントツリー（ComponentTree.swift）

- 階層構造をツリー形式で表示
- 各ノードはComponentTreeNode（Identifiable）
- 展開/折りたたみ可能
- クリックで選択状態を設定
- 選択中はハイライト表示

実装するコンポーネント階層:
RootView
└── MainTabView
    ├── Dashboard
    │   ├── Header
    │   │   ├── WelcomeCard
    │   │   └── ServerSelector
    │   ├── QuickActions
    │   ├── StatsGrid
    │   └── Notifications
    ├── Features
    ├── Automation
    └── Moderation

## 2. プレビューキャンバス（PreviewCanvas.swift）

- iPhoneモックフレーム内にプレビューを表示
- 上部に画面切り替えピッカー（Dashboard/Features/Automation/Moderation）
- ScreenshotボタンでNSViewをキャプチャ
- 各画面のプレビュービューを実装

iPhoneモック仕様:
- 外枠: 375x812、角丸40、黒背景
- 内側: 365x802、角丸36
- ノッチ部分にカプセル形状
- ドロップシャドウ付き

## 3. プロパティインスペクター（PropertyInspector.swift）

- 選択されたコンポーネントのプロパティを動的に表示
- プロパティタイプ:
  - text: TextField
  - number: TextField
  - color: TextField + 色プレビュー矩形
  - boolean: Toggle
  - enum: Picker（segmented）
- 変更時にEditorState.recordChange()を呼ぶ
- コンポーネントごとにプロパティ定義を切り替え

## 4. 状態管理（EditorState.swift）

- @Observableクラス
- selectedComponentPath: String?
- changes: [ChangeRecord]
- initialSnapshot: [String: String]
- isDiffPanelVisible: Bool
- lastScreenshotPath: String?

メソッド:
- recordChange(componentPath:propertyName:oldValue:newValue:)
- takeSnapshot(_:)
- generateReport() -> DiffReport
- reset()
```

---

## フェーズ3: プロンプト

```
差分システムとスクリーンショット機能を実装してください。

## 1. 変更レコード（ChangeRecord.swift）

struct ChangeRecord: Identifiable, Codable {
    let id: UUID
    let componentPath: String    // "RootView/Dashboard/Header/WelcomeCard"
    let propertyName: String     // "welcome_title"
    let oldValue: String
    let newValue: String
    let timestamp: Date
}

## 2. 差分レポート（DiffReport.swift）

struct DiffReport {
    let changes: [ChangeRecord]
    let generatedAt: Date

    // JSON出力（prettyPrinted, sortedKeys）
    func toJSON() -> String

    // Markdown出力
    func toMarkdown() -> String
}

Markdown形式の仕様:
- タイトル: "# UI Edit Diff Report"
- 生成日時
- サマリー（変更数、影響を受けたコンポーネント数）
- コンポーネントごとにグループ化
- 各プロパティのBefore/After
- AI Prompt Templateセクション（日本語）

## 3. 差分出力パネル（DiffOutputPanel.swift）

- シートとして表示
- 形式切り替えピッカー（Markdown/JSON）
- TextEditorで出力表示（monospacedフォント）
- ボタン:
  - Copy to Clipboard（NSPasteboard）
  - Save as File（NoxyEditor/exports/diff_<timestamp>.md or .json）
  - Close（⌘.で閉じる）

## 4. スクリーンショット管理（ScreenshotManager.swift）

@MainActor final class ScreenshotManager {
    func captureView(_ view: NSView) -> String?
}

仕様:
- NSView.bitmapImageRepForCachingDisplayでキャプチャ
- 保存先: ~/Dev/Noxy/NoxyEditor/exports/screenshots/
- ファイル名: screenshot_<timestamp>.png
- PNG形式で保存

## 5. 変更追跡（DiffTracker.swift）

@Observable final class DiffTracker {
    func captureSnapshot(key:value:)
    func detectChange(key:currentValue:) -> ChangeRecord?
    func reset()
}
```

---

## フェーズ4: プロンプト

```
Xcodeプロジェクト設定とビルド構成を行ってください。

## 1. macOSターゲット追加

xcodeproj gemを使用して:
- ターゲット名: NoxyEditor
- プラットフォーム: macOS 14.0
- Bundle ID: Gorogoro.NoxyEditor

## 2. ビルド設定

以下の設定を適用:
- MACOSX_DEPLOYMENT_TARGET = 14.0
- PRODUCT_BUNDLE_IDENTIFIER = Gorogoro.NoxyEditor
- ENABLE_PREVIEWS = YES
- SWIFT_VERSION = 5.0
- DEVELOPMENT_TEAM = L876YJ7J98
- CODE_SIGN_STYLE = Automatic
- PRODUCT_NAME = $(TARGET_NAME)
- SWIFT_APPROACHABLE_CONCURRENCY = YES
- SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
- SWIFT_EMIT_LOC_STRINGS = YES
- SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES
- LD_RUNPATH_SEARCH_PATHS = $(inherited) @executable_path/Frameworks
- GENERATE_INFOPLIST_FILE = YES
- ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon
- ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor
- STRING_CATALOG_GENERATE_SYMBOLS = YES

## 3. ファイル参照

- NoxyEditor/**/*.swift を全てビルドフェーズに追加
- Design/ ディレクトリのファイルも追加
- プロジェクトルートからの相対パスで設定

## 4. カラースキーム対応

macOS用にColors.swiftを修正:
- UIColor → NSColor
- PlatformColor typealiasで両対応
- #if os(iOS) / #else で条件コンパイル

## 5. ビルド確認

xcodebuildでビルド:
xcodebuild -project Noxy.xcodeproj \
  -scheme NoxyEditor \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

---

## フェーズ5: プロンプト

```
README.mdを作成し、使い方をドキュメント化してください。

## 含める内容

1. 概要
2. 起動方法
3. エディタの構成（3ペインの説明）
4. 主要機能:
   - 差分の追跡と出力
   - スクリーンショット撮影
   - リセット
5. 本体コードとの連携
6. ファイル構成
7. 注意点
8. トラブルシューティング

## 出力形式

- Markdown形式
- コードブロックで具体的なコマンドや出力例を示す
- 図はASCIIアートでレイアウトを表現
- 日本語で記述
```

---

## 一括プロンプト（短縮版）

```
既存のSwiftUI iOSプロジェクトに、FigmaのようなUIエディタをmacOSターゲットとして追加してください。

## 仕様
- 3ペインレイアウト（コンポーネントツリー / iPhoneプレビュー / プロパティインスペクター）
- 変更の差分追跡（JSON + Markdown出力）
- スクリーンショット撮影機能
- 永続化なし（ビルドごとにリセット）
- 既存のデザインシステムを共有

## 実装順序
1. NoxyEditor/ ディレクトリ構造と基本ファイル
2. EditorState（@Observable状態管理）
3. 3ペインレイアウト（HSplitView）
4. コンポーネントツリー（OutlineGroup）
5. iPhoneモックフレーム＋プレビュー
6. プロパティインスペクター（動的フォーム）
7. DiffTracker + ChangeRecord + DiffReport
8. DiffOutputPanel（Markdown/JSON出力）
9. ScreenshotManager（NSViewキャプチャ）
10. Xcode macOSターゲット追加
11. ビルド設定・確認
12. README.md作成

## 技術制約
- macOS 14.0+
- SwiftUI @Observable
- NSColorベース（macOS対応）
- xcodeproj gemでプロジェクト設定
```

---

## 使用ツール

- `xcodeproj` gem: Xcodeプロジェクト操作
- `xcodebuild`: ビルド実行
- `mkdir`, `cp`: ファイル操作
- `ruby -e`: プロジェクト設定スクリプト

## 注意点

1. **ファイルパス**: xcodeprojでファイル参照を追加する際、グループのpathとファイルのpathが重複しないよう注意
2. **カラースキーム**: macOSではUIColorが使えないため、NSColorに置き換えが必要
3. **ビルドフェーズ**: ファイル参照を追加した後、source_build_phaseにも追加する必要あり
4. **条件コンパイル**: iOS/macOS両対応にする場合は `#if os(iOS)` を使用