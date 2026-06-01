-- ============================================================
-- Noxy ショップ機能 v2 マイグレーション
-- Supabase SQL Editor で実行してください
-- ============================================================

-- shops テーブルに新カラム追加
ALTER TABLE shops ADD COLUMN IF NOT EXISTS payment_flow TEXT NOT NULL DEFAULT 'manual';
-- 'manual' = 手動取引, 'url_input' = URL入力モーダル

ALTER TABLE shops ADD COLUMN IF NOT EXISTS auto_deliver BOOLEAN NOT NULL DEFAULT true;
-- true = 支払い確認後自動で対価送信, false = 手動対応

ALTER TABLE shops ADD COLUMN IF NOT EXISTS disabled_message TEXT;
-- ショップが無効のときに表示するメッセージ

-- ウェルカムメッセージ embed 設定
ALTER TABLE shops ADD COLUMN IF NOT EXISTS welcome_image_url TEXT;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS welcome_thumbnail_url TEXT;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS welcome_fields JSONB NOT NULL DEFAULT '[]';
ALTER TABLE shops ADD COLUMN IF NOT EXISTS welcome_footer_text TEXT;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS welcome_footer_icon_url TEXT;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS welcome_show_timestamp BOOLEAN NOT NULL DEFAULT true;

-- 既存の footer_text を welcome_embed_footer_text として保持（互換性のため残す）
-- footer_text カラムはそのまま利用

-- products テーブル: enabled は既存なので追加不要

-- orders テーブル: 支払いURL入力用
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_url TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_submitted_at TIMESTAMPTZ;
