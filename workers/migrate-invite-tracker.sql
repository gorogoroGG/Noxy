-- ════════════════════════════════════════════════════════════════
--  招待トラッカー: テーブル作成マイグレーション
--
--  使い方:
--    Supabase SQL Editor を開いて全文貼り付け → Run
--    https://supabase.com/dashboard/project/byvwidopvpedslzwuksq/sql/new
-- ════════════════════════════════════════════════════════════════

-- ── 1. invite_events（招待イベント記録）────────────────────────

CREATE TABLE IF NOT EXISTS invite_events (
  id                    uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  guild_id              text        NOT NULL,
  inviter_user_id       text        NOT NULL,
  inviter_username      text        NOT NULL DEFAULT '',
  inviter_display_name  text        NOT NULL DEFAULT '',
  invitee_user_id       text        NOT NULL,
  invitee_username      text        NOT NULL,
  invitee_display_name  text        NOT NULL,
  invitee_avatar_url    text,
  invite_code           text,
  joined_at             timestamptz NOT NULL DEFAULT now(),
  left_at               timestamptz,
  is_fake               boolean     NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS invite_events_guild_idx    ON invite_events (guild_id);
CREATE INDEX IF NOT EXISTS invite_events_inviter_idx  ON invite_events (guild_id, inviter_user_id);
CREATE INDEX IF NOT EXISTS invite_events_invitee_idx  ON invite_events (guild_id, invitee_user_id);

ALTER TABLE invite_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service role full access" ON invite_events;
CREATE POLICY "service role full access" ON invite_events FOR ALL USING (true);

-- ── 2. invite_stats（招待統計 — Botが集計して書き込む）─────────

CREATE TABLE IF NOT EXISTS invite_stats (
  user_id         text        NOT NULL,
  guild_id        text        NOT NULL,
  username        text        NOT NULL DEFAULT '',
  display_name    text        NOT NULL DEFAULT '',
  avatar_url      text,
  total_invites   integer     NOT NULL DEFAULT 0,
  valid_invites   integer     NOT NULL DEFAULT 0,
  left_invites    integer     NOT NULL DEFAULT 0,
  fake_invites    integer     NOT NULL DEFAULT 0,
  influence_score integer     NOT NULL DEFAULT 0,
  tree_size       integer     NOT NULL DEFAULT 0,
  retention_rate  float8      NOT NULL DEFAULT 0,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, guild_id)
);

CREATE INDEX IF NOT EXISTS invite_stats_guild_idx ON invite_stats (guild_id, valid_invites DESC);

ALTER TABLE invite_stats ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service role full access" ON invite_stats;
CREATE POLICY "service role full access" ON invite_stats FOR ALL USING (true);

-- ── 3. invite_tracker_settings（ギルドごとの設定）──────────────

CREATE TABLE IF NOT EXISTS invite_tracker_settings (
  guild_id                     text        NOT NULL PRIMARY KEY,
  is_enabled                   boolean     NOT NULL DEFAULT false,
  log_channel_id               text,
  notify_on_join               boolean     NOT NULL DEFAULT true,
  notify_on_leave              boolean     NOT NULL DEFAULT true,
  fake_invite_threshold_hours  integer     NOT NULL DEFAULT 24,
  updated_at                   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE invite_tracker_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service role full access" ON invite_tracker_settings;
CREATE POLICY "service role full access" ON invite_tracker_settings FOR ALL USING (true);

-- ── 4. invite_milestones（招待数マイルストーン）────────────────

CREATE TABLE IF NOT EXISTS invite_milestones (
  id         uuid  DEFAULT gen_random_uuid() PRIMARY KEY,
  guild_id   text  NOT NULL,
  count      integer NOT NULL,
  role_id    text  NOT NULL,
  role_name  text  NOT NULL DEFAULT ''
);

CREATE INDEX IF NOT EXISTS invite_milestones_guild_idx ON invite_milestones (guild_id);

ALTER TABLE invite_milestones ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service role full access" ON invite_milestones;
CREATE POLICY "service role full access" ON invite_milestones FOR ALL USING (true);

-- ── 5. invite_campaigns（招待キャンペーン）─────────────────────

CREATE TABLE IF NOT EXISTS invite_campaigns (
  id             uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  guild_id       text        NOT NULL,
  name           text        NOT NULL,
  description    text,
  invite_code    text,
  target_count   integer,
  current_count  integer     NOT NULL DEFAULT 0,
  starts_at      timestamptz NOT NULL DEFAULT now(),
  ends_at        timestamptz,
  is_active      boolean     NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS invite_campaigns_guild_idx ON invite_campaigns (guild_id);

ALTER TABLE invite_campaigns ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service role full access" ON invite_campaigns;
CREATE POLICY "service role full access" ON invite_campaigns FOR ALL USING (true);

-- ── 6. invite_panels（Discordに設置したパネル一覧）──────────────

CREATE TABLE IF NOT EXISTS invite_panels (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  guild_id     text        NOT NULL,
  channel_id   text        NOT NULL,
  channel_name text,
  message_id   text,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS invite_panels_guild_idx ON invite_panels (guild_id);

ALTER TABLE invite_panels ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service role full access" ON invite_panels;
CREATE POLICY "service role full access" ON invite_panels FOR ALL USING (true);

-- ── 7. personal_invites（ユーザーごとの専用招待リンク）──────────

CREATE TABLE IF NOT EXISTS personal_invites (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  guild_id     text        NOT NULL,
  user_id      text        NOT NULL,
  username     text        NOT NULL DEFAULT '',
  display_name text        NOT NULL DEFAULT '',
  invite_code  text        NOT NULL,
  invite_url   text        NOT NULL,
  channel_id   text        NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (guild_id, user_id)   -- 1人1リンク
);

CREATE INDEX IF NOT EXISTS personal_invites_guild_idx ON personal_invites (guild_id);

ALTER TABLE personal_invites ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service role full access" ON personal_invites;
CREATE POLICY "service role full access" ON personal_invites FOR ALL USING (true);
