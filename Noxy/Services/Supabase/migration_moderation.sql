-- ============================================================
-- Noxy モデレーション追加マイグレーション
-- Supabase SQL Editor に貼り付けて実行してください
-- ============================================================

-- mod_warnings（警告ログ）
--
-- ・guild_id   … Discord サーバー ID
-- ・user_id    … 警告対象の Discord ユーザー ID
-- ・staff_id   … 警告を発行したスタッフの Discord ユーザー ID
-- ・is_revoked … 取り消し済みフラグ（削除はせず論理フラグで管理）
-- ・auto_action… 警告追加時に自動実行したアクション（記録用）

CREATE TABLE IF NOT EXISTS mod_warnings (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    guild_id     TEXT        NOT NULL,
    user_id      TEXT        NOT NULL,
    username     TEXT        NOT NULL DEFAULT '',
    display_name TEXT        NOT NULL DEFAULT '',
    reason       TEXT        NOT NULL,
    staff_id     TEXT        NOT NULL DEFAULT '',
    staff_name   TEXT        NOT NULL DEFAULT '',
    auto_action  TEXT,                              -- NULL / 'timeout_1h' / 'timeout_24h' / 'ban'
    is_revoked   BOOLEAN     NOT NULL DEFAULT FALSE,
    revoked_at   TIMESTAMPTZ,
    revoked_by   TEXT,                              -- 取り消したスタッフの名前
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- よく使うクエリ向けのインデックス
CREATE INDEX IF NOT EXISTS idx_mod_warnings_guild     ON mod_warnings (guild_id);
CREATE INDEX IF NOT EXISTS idx_mod_warnings_user      ON mod_warnings (guild_id, user_id);
CREATE INDEX IF NOT EXISTS idx_mod_warnings_active    ON mod_warnings (guild_id, is_revoked) WHERE is_revoked = FALSE;
CREATE INDEX IF NOT EXISTS idx_mod_warnings_created   ON mod_warnings (guild_id, created_at DESC);

-- ============================================================
-- Row Level Security（RLS）
-- Worker は service_role キーを使うため RLS をバイパスします。
-- 将来的に anon / authenticated ロールから直接アクセスする場合に備えて設定。
-- ============================================================

ALTER TABLE mod_warnings ENABLE ROW LEVEL SECURITY;

-- service_role は全操作を許可（Worker からのアクセス）
CREATE POLICY "service_role full access" ON mod_warnings
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- ============================================================
-- ビュー: ユーザーごとの有効な警告数サマリー
-- 自動エスカレーション判定に利用
-- ============================================================

CREATE OR REPLACE VIEW mod_warning_counts AS
SELECT
    guild_id,
    user_id,
    username,
    display_name,
    COUNT(*)                                             AS total_warnings,
    COUNT(*) FILTER (WHERE is_revoked = FALSE)           AS active_warnings,
    MAX(created_at)                                      AS last_warned_at
FROM mod_warnings
GROUP BY guild_id, user_id, username, display_name;

-- ============================================================
-- 参考: 自動エスカレーション閾値テーブル（将来的にUI から変更可能にする場合）
-- 現状は Worker / iOS 側でハードコードしているため任意。
-- ============================================================

CREATE TABLE IF NOT EXISTS mod_escalation_rules (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    guild_id    TEXT        NOT NULL,
    threshold   INTEGER     NOT NULL,              -- 警告回数
    action      TEXT        NOT NULL,              -- 'timeout_1h' / 'timeout_24h' / 'ban'
    is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (guild_id, threshold)
);

CREATE INDEX IF NOT EXISTS idx_escalation_guild ON mod_escalation_rules (guild_id);

ALTER TABLE mod_escalation_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role full access" ON mod_escalation_rules
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- デフォルトルールを挿入したい場合は以下を guild_id を変えて実行
-- INSERT INTO mod_escalation_rules (guild_id, threshold, action) VALUES
--     ('YOUR_GUILD_ID', 3, 'timeout_1h'),
--     ('YOUR_GUILD_ID', 5, 'timeout_24h'),
--     ('YOUR_GUILD_ID', 7, 'ban')
-- ON CONFLICT (guild_id, threshold) DO NOTHING;
