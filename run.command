#!/bin/bash
# Noxy Bot ビルド・起動 + Worker デプロイ
# ダブルクリックで実行可能

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================="
echo "  Noxy Bot + Worker デプロイスクリプト"
echo "========================================="
echo ""

# ── Bot ビルド ──
echo "🤖 [1/3] Building Bot..."
cd "$SCRIPT_DIR/bot"
npm run build
echo "✅ Bot build successful"
echo ""

# ── Bot 起動（別ターミナル） ──
echo "🚀 [2/3] Starting Bot in new terminal..."
osascript -e "tell application \"Terminal\" to do script \"cd '$SCRIPT_DIR/bot' && npm start\""
echo "✅ Bot started"
echo ""

# ── Worker デプロイ ──
echo "🔧 [3/3] Deploying Worker..."
cd "$SCRIPT_DIR/workers"
npm run deploy
echo ""

echo "========================================="
echo "  ✅ すべて完了しました！"
echo "========================================="
