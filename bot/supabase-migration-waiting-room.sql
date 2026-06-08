-- 待機室認証システム用 DBマイグレーション
-- Supabase の SQL エディタ（https://supabase.com/dashboard）で実行してください。

-- 1. temp_vc_sources テーブルに waiting_room_enabled 列を追加
ALTER TABLE temp_vc_sources
  ADD COLUMN IF NOT EXISTS waiting_room_enabled BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. temp_channels テーブルに waiting_room_vc_id 列を追加
ALTER TABLE temp_channels
  ADD COLUMN IF NOT EXISTS waiting_room_vc_id TEXT;

-- 確認用クエリ
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name IN ('temp_vc_sources', 'temp_channels')
  AND column_name IN ('waiting_room_enabled', 'waiting_room_vc_id')
ORDER BY table_name, column_name;
