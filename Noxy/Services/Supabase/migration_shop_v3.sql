-- ============================================================
-- Noxy ショップ機能 v3 マイグレーション
-- 自販機/ショップ分離対応
-- Supabase SQL Editor で実行してください
-- ============================================================

-- shop_type カラム追加（'shop' または 'vending_machine'）
ALTER TABLE shops ADD COLUMN IF NOT EXISTS shop_type TEXT NOT NULL DEFAULT 'shop';

-- review_enabled / review_channel_id（旧 payment_flow / auto_deliver を置き換え）
ALTER TABLE shops ADD COLUMN IF NOT EXISTS review_enabled BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS review_channel_id TEXT;

-- 自販機専用：支払い案内文
ALTER TABLE shops ADD COLUMN IF NOT EXISTS payment_input_label TEXT;

-- 自動削除設定
ALTER TABLE shops ADD COLUMN IF NOT EXISTS auto_delete_enabled BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS auto_delete_days INT;

-- orders テーブル: キャンセル・アーカイブ日時
ALTER TABLE orders ADD COLUMN IF NOT EXISTS buyer_cancel_requested BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS seller_cancel_requested BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS auto_delete_at TIMESTAMPTZ;
