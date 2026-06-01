@echo off
chcp 65001 >nul
title Noxy Bot + Worker Deploy
cd /d "%~dp0"

echo =========================================
echo   Noxy Bot + Worker デプロイスクリプト
echo =========================================
echo.

rem ── Bot ビルド ──
echo 🤖 [1/3] Building Bot...
cd bot
call npm run build
if %errorlevel% neq 0 (
    echo ❌ Bot build failed!
    pause
    exit /b 1
)
echo ✅ Bot build successful
echo.

rem ── Bot 起動（別ウィンドウ） ──
echo 🚀 [2/3] Starting Bot in new window...
start "Noxy Bot" cmd /k "cd /d %CD% && npm start"
echo ✅ Bot started
echo.

rem ── Worker デプロイ ──
echo 🔧 [3/3] Deploying Worker...
cd ..\workers
call npm run deploy
echo.

echo =========================================
echo   ✅ すべて完了しました！
echo =========================================
pause
