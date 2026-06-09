# NoxyEditor 使い方ガイド

## 概要

NoxyEditorは、NoxyアプリのUIを視覚的に編集・テストするためのmacOSエディタです。XcodeプロジェクトにmacOSターゲットとして統合されており、本体のコード変更を即座に反映できます。

## 起動方法

1. Xcodeで `Noxy.xcodeproj` を開く
2. スキームセレクターから **NoxyEditor** を選択
3. `⌘R` でビルド＆実行

## エディタの構成

```
┌─────────────────┬──────────────────┬─────────────────┐
│  Components     │   Preview        │  Properties     │
│  (左パネル)      │   (中央)         │  (右パネル)      │
│                 │                  │                 │
│  • RootView     │   ┌──────────┐   │  • Title        │
│    • MainTabView│   │  iPhone  │   │  • Subtitle     │
│      • Dashboard│   │   Mock   │   │  • Color        │
│      • Features │   │          │   │  • Layout       │
│      • ...      │   └──────────┘   │  • ...          │
│                 │                  │                 │
└─────────────────┴──────────────────┴─────────────────┘
```

### 左パネル: コンポーネントツリー

- アプリのUI階層をツリー形式で表示
- クリックして要素を選択
- 矢印アイコンで展開/折りたたみ

### 中央: プレビューキャンバス

- iPhoneモックフレーム内でライブプレビューを表示
- 上部のセグメントで画面を切り替え:
  - Dashboard
  - Features
  - Automation
  - Moderation
- **Screenshot** ボタンで現在のプレビューを撮影

### 右パネル: プロパティインスペクター

- 選択したコンポーネントの編集可能なプロパティを表示
- プロパティタイプに応じた入力フォーム:
  - **テキスト**: TextField
  - **数値**: TextField
  - **カラー**: Hexコード入力 + プレビュー
  - **真偽値**: Toggleスイッチ
  - **列挙型**: セグメントピッカー

## 主要機能

### 1. 差分の追跡と出力

プロパティを変更すると、自動的に変更履歴が記録されます。

**差分パネルの開き方:**
1. ツールバーの **Diff** ボタンをクリック
2. 出力形式を選択:
   - **Markdown**: 人間可読形式（AIへの指示に最適）
   - **JSON**: 構造化データ

**出力内容例（Markdown）:**
```markdown
# UI Edit Diff Report

Generated: June 8, 2026 at 2:30 PM

## Summary

- **Total changes:** 3
- **Components affected:** 2

---

### `RootView/MainTabView/Dashboard/Header/WelcomeCard`

- **Title:**
  - Before: `Welcome back!`
  - After: `こんにちは！`
- **Subtitle:**
  - Before: `My Server`
  - After: `テストサーバー`

---

## AI Prompt Template

```
以下のUI変更を行ってください：

- RootView/MainTabView/Dashboard/Header/WelcomeCardのwelcome_titleを「Welcome back!」から「こんにちは！」に変更
- RootView/MainTabView/Dashboard/Header/WelcomeCardのwelcome_subtitleを「My Server」から「テストサーバー」に変更
```
```

**操作:**
- **Copy to Clipboard**: クリップボードにコピー
- **Save as File**: `NoxyEditor/exports/diff_<timestamp>.md` に保存

### 2. スクリーンショット撮影

1. プレビューキャンバスの **Screenshot** ボタンをクリック
2. 画像が `NoxyEditor/exports/screenshots/screenshot_<timestamp>.png` に保存

### 3. リセット

ツールバーの **Reset** ボタンで:
- 全ての変更履歴をクリア
- 選択状態をリセット
- エディタを初期状態に戻す

## 本体コードとの連携

### 本体のUIコードを変更した場合

1. `Noxy/Design/Colors.swift` などのファイルを編集
2. NoxyEditorを再ビルド（`⌘R`）
3. プレビューに変更が反映される

### エディタに新しいコンポーネントを追加する場合

1. `NoxyEditor/Views/ComponentTree.swift` の `tree` プロパティにノードを追加
2. `NoxyEditor/Views/PropertyInspector.swift` の `updateProperties` にプロパティ定義を追加
3. `NoxyEditor/Views/PreviewCanvas.swift` にプレビュービューを追加

## ファイル構成

```
NoxyEditor/
├── NoxyEditorApp.swift          # エントリーポイント
├── Core/
│   ├── EditorState.swift        # グローバル状態管理
│   └── DiffTracker.swift        # 変更追跡
├── Views/
│   ├── EditorMainWindow.swift   # メインウィンドウ
│   ├── ComponentTree.swift      # コンポーネントツリー
│   ├── PreviewCanvas.swift      # プレビューキャンバス
│   ├── PropertyInspector.swift  # プロパティインスペクター
│   └── DiffOutputPanel.swift    # 差分出力パネル
├── Models/
│   ├── ChangeRecord.swift       # 変更レコード
│   └── DiffReport.swift         # 差分レポート
├── Utilities/
│   ├── ScreenshotManager.swift  # スクリーンショット管理
│   └── iPhoneMockFrame.swift    # iPhoneモックフレーム
└── Design/
    ├── Colors.swift             # カラースキーム
    ├── Spacing.swift            # スペーシング
    └── Typography.swift         # タイポグラフィ
```

## 注意点

- **永続化なし**: 編集内容は保存されません。ビルドし直すたびにリセットされます
- **macOS専用**: このエディタはmacOSアプリとして動作します
- **ダークモード**: 現在macOS用にダークテーマで固定されています

## トラブルシューティング

### ビルドエラーが発生する場合

1. Xcodeを再起動
2. `⌘Shift+K` でクリーンビルド
3. 再度 `⌘R` でビルド

### プレビューが更新されない場合

1. エディタを再起動
2. 本体コードを変更した場合は、必ず再ビルドしてください
