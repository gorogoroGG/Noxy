-- ════════════════════════════════════════════════════════════════
--  災害復旧機能: テーブル作成マイグレーション
--
--  対象: 既存の Noxy データベース
--  使い方:
--    Supabase SQL Editor を開いて全文貼り付け → Run
-- ════════════════════════════════════════════════════════════════

-- ── 1. verify_panels.verify_type に oauth2 を許可（コメント更新）────
-- 既存テーブルにはCHECK制約がないため、コメントのみ更新
COMMENT ON COLUMN verify_panels.verify_type IS 'captcha/reaction/manual/button/oauth2';

-- ── 2. OAuth2認証済みメンバー（自動参加対象）────────────────────
CREATE TABLE IF NOT EXISTS oauth2_verified_members (
  id                     uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  guild_id               text        NOT NULL,
  user_id                text        NOT NULL,
  username               text        NOT NULL DEFAULT '',
  avatar_url             text,
  access_token_encrypted text        NOT NULL,
  refresh_token_encrypted text,
  authorized_at          timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT oauth2_verified_members_guild_user UNIQUE (guild_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_oauth2_verified_members_guild ON oauth2_verified_members(guild_id);
CREATE INDEX IF NOT EXISTS idx_oauth2_verified_members_user  ON oauth2_verified_members(user_id);

ALTER TABLE oauth2_verified_members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_full_oauth2_verified_members" ON oauth2_verified_members;
CREATE POLICY "service_role_full_oauth2_verified_members" ON oauth2_verified_members
  FOR ALL USING (auth.role() = 'service_role');

-- ── 3. 削除されたサーバー記録 ──────────────────────────────────
CREATE TABLE IF NOT EXISTS deleted_guilds (
  guild_id    text        PRIMARY KEY,
  owner_id    text,
  guild_name  text        NOT NULL DEFAULT '',
  deleted_at  timestamptz NOT NULL DEFAULT now(),
  notified    boolean     NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_deleted_guilds_owner ON deleted_guilds(owner_id);

ALTER TABLE deleted_guilds ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_full_deleted_guilds" ON deleted_guilds;
CREATE POLICY "service_role_full_deleted_guilds" ON deleted_guilds
  FOR ALL USING (auth.role() = 'service_role');

-- ── 4. 復旧ジョブ ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS recovery_jobs (
  id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  source_guild_id      text        NOT NULL,
  destination_guild_id text        NOT NULL,
  status               text        NOT NULL DEFAULT 'running', -- running/completed/failed
  total_count          integer     NOT NULL DEFAULT 0,
  success_count        integer     NOT NULL DEFAULT 0,
  fail_count           integer     NOT NULL DEFAULT 0,
  created_at           timestamptz NOT NULL DEFAULT now(),
  completed_at         timestamptz
);

CREATE INDEX IF NOT EXISTS idx_recovery_jobs_source ON recovery_jobs(source_guild_id);

ALTER TABLE recovery_jobs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_full_recovery_jobs" ON recovery_jobs;
CREATE POLICY "service_role_full_recovery_jobs" ON recovery_jobs
  FOR ALL USING (auth.role() = 'service_role');

-- ── 5. 復旧ジョブ詳細 ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS recovery_job_results (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id        uuid        NOT NULL REFERENCES recovery_jobs(id) ON DELETE CASCADE,
  user_id       text        NOT NULL,
  username      text        NOT NULL DEFAULT '',
  status        text        NOT NULL, -- success/failed/skipped
  error_message text,
  attempted_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_recovery_job_results_job ON recovery_job_results(job_id);

ALTER TABLE recovery_job_results ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_full_recovery_job_results" ON recovery_job_results;
CREATE POLICY "service_role_full_recovery_job_results" ON recovery_job_results
  FOR ALL USING (auth.role() = 'service_role');

-- 確認
SELECT 'oauth2_verified_members' AS t, count(*) FROM oauth2_verified_members
UNION ALL SELECT 'deleted_guilds', count(*) FROM deleted_guilds
UNION ALL SELECT 'recovery_jobs', count(*) FROM recovery_jobs
UNION ALL SELECT 'recovery_job_results', count(*) FROM recovery_job_results;
