-- ════════════════════════════════════════════════════════════════
--  App Store スクショ用: 不足テーブルの作成 + シード投入
--
--  対象: auto_responses（未定義）, stat_channels（未適用）, reaction_roles（既存・データ追加）
--  guild_id: 1515731172205002893
--
--  使い方:
--    Supabase SQL Editor を開いて全文貼り付け → Run
--    https://supabase.com/dashboard/project/byvwidopvpedslzwuksq/sql/new
-- ════════════════════════════════════════════════════════════════

-- ── 1. auto_responses（自動応答）テーブル作成 ────────────────────
CREATE TABLE IF NOT EXISTS auto_responses (
  id            uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  guild_id      text        NOT NULL,
  trigger_type  text        NOT NULL DEFAULT 'contains'
                  CHECK (trigger_type IN ('contains','exact','regex','starts_with','ends_with')),
  trigger       text        NOT NULL,
  response      text        NOT NULL,
  is_enabled    boolean     NOT NULL DEFAULT true,
  cooldown_sec  integer     NOT NULL DEFAULT 0,
  channel_ids   text[]      NOT NULL DEFAULT '{}',
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS auto_responses_guild_idx ON auto_responses (guild_id);
ALTER TABLE auto_responses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON auto_responses;
CREATE POLICY "Allow all for authenticated users" ON auto_responses
  FOR ALL USING (auth.role() = 'authenticated');

-- ── 2. stat_channels（統計チャンネル）テーブル作成 ───────────────
CREATE TABLE IF NOT EXISTS stat_channels (
  id               uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  guild_id         text        NOT NULL,
  channel_id       text        NOT NULL UNIQUE,
  stat_type        text        NOT NULL CHECK (stat_type IN ('members','online','boosts','vc_users')),
  is_enabled       boolean     NOT NULL DEFAULT true,
  last_value       integer     NOT NULL DEFAULT -1,
  last_updated_at  timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS stat_channels_guild_idx ON stat_channels (guild_id);
CREATE INDEX IF NOT EXISTS stat_channels_enabled_idx ON stat_channels (is_enabled) WHERE is_enabled = true;
ALTER TABLE stat_channels ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON stat_channels;
CREATE POLICY "Allow all for authenticated users" ON stat_channels
  FOR ALL USING (auth.role() = 'authenticated');

-- ════════════════════════════════════════════════════════════════
--  シードデータ投入
-- ════════════════════════════════════════════════════════════════

-- ── auto_responses（4件）────────────────────────────────────────
INSERT INTO auto_responses (guild_id, trigger_type, trigger, response, is_enabled, cooldown_sec) VALUES
  ('1515731172205002893', 'contains', '料金',   '料金プランはショップをご確認ください！',           true, 5),
  ('1515731172205002893', 'contains', '招待',   '招待リンクはこちら → discord.gg/noxy',             true, 5),
  ('1515731172205002893', 'exact',    'ping',   'pong! 🏓',                                          true, 5),
  ('1515731172205002893', 'contains', 'ルール', 'サーバールールはルールチャンネルをご確認ください📜', true, 5);

-- ── stat_channels（3件）─────────────────────────────────────────
INSERT INTO stat_channels (guild_id, channel_id, stat_type, is_enabled, last_value) VALUES
  ('1515731172205002893', '900000000000000001', 'members', true, 1248),
  ('1515731172205002893', '900000000000000002', 'online',  true, 93),
  ('1515731172205002893', '900000000000000003', 'boosts',  true, 14)
ON CONFLICT (channel_id) DO UPDATE
  SET stat_type = EXCLUDED.stat_type, last_value = EXCLUDED.last_value, is_enabled = true;

-- ── reaction_roles（1件・正しいカラム構成）──────────────────────
INSERT INTO reaction_roles (id, guild_id, channel_id, channel_name, title, mode, pairs, embed_title, embed_description, embed_color)
VALUES (
  gen_random_uuid(),
  '1515731172205002893',
  '000000000000000000',
  '#role-select',
  '🔔 通知ロール',
  'toggle',
  '[{"emoji":"🔔","role_id":"000000000000000001","role_name":"お知らせ"},{"emoji":"🎮","role_id":"000000000000000002","role_name":"ゲーマー"},{"emoji":"🎨","role_id":"000000000000000003","role_name":"クリエイター"}]'::jsonb,
  '🔔 通知ロールを選択',
  'リアクションで好きなロールを受け取れます。',
  5793266
);

-- 確認
SELECT 'auto_responses' AS t, count(*) FROM auto_responses WHERE guild_id = '1515731172205002893'
UNION ALL SELECT 'stat_channels', count(*) FROM stat_channels WHERE guild_id = '1515731172205002893'
UNION ALL SELECT 'reaction_roles', count(*) FROM reaction_roles WHERE guild_id = '1515731172205002893';
