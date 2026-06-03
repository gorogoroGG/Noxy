-- ============================================================
-- Noxy Supabase スキーマ
-- Supabase SQL Editor に貼り付けて実行してください
-- ============================================================

-- 1. embeds（埋め込みメッセージテンプレート）
CREATE TABLE IF NOT EXISTS embeds (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL DEFAULT '',
    message_content TEXT,
    title           TEXT,
    embed_url       TEXT,
    description     TEXT,
    color_hex       INTEGER NOT NULL DEFAULT 3957661,  -- 0x3C65F9
    fields          JSONB NOT NULL DEFAULT '[]',
    image_url       TEXT,
    thumbnail_url   TEXT,
    footer_text     TEXT,
    footer_icon_url TEXT,
    show_timestamp  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 既存DB向け: message_content 列を追加（埋め込みの外に出すメッセージ本文。メンションが機能する）
ALTER TABLE embeds ADD COLUMN IF NOT EXISTS message_content TEXT;

-- 2. scheduled_messages（予約投稿 / 定期投稿）
CREATE TABLE IF NOT EXISTS scheduled_messages (
    id              TEXT PRIMARY KEY,
    guild_id        TEXT NOT NULL,
    channel_id      TEXT NOT NULL,
    embed_id        TEXT NOT NULL REFERENCES embeds(id) ON DELETE CASCADE,
    title           TEXT NOT NULL DEFAULT '',
    scheduled_for   TIMESTAMPTZ NOT NULL,
    repeat_rule     TEXT NOT NULL DEFAULT 'none',  -- none / daily / weekly / monthly
    status          TEXT NOT NULL DEFAULT 'pending', -- pending / sent / cancelled
    end_date        TIMESTAMPTZ
);

-- 3. guilds（サーバー）
CREATE TABLE IF NOT EXISTS guilds (
    id              TEXT PRIMARY KEY,
    discord_id      TEXT NOT NULL,
    name            TEXT NOT NULL,
    icon_url        TEXT,
    member_count    INTEGER NOT NULL DEFAULT 0,
    user_role       TEXT NOT NULL DEFAULT '',     -- owner / admin / moderator
    category        TEXT NOT NULL DEFAULT ''      -- gaming / vtuber / support / shop / community
);

-- 4. channels（チャンネル）
CREATE TABLE IF NOT EXISTS channels (
    id              TEXT PRIMARY KEY,
    guild_id        TEXT NOT NULL REFERENCES guilds(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    type            TEXT NOT NULL DEFAULT 'text',   -- text / voice / announcement
    category_name   TEXT,
    bot_can_send    BOOLEAN NOT NULL DEFAULT TRUE
);

-- 5. greeting_settings（入退室メッセージ設定）
CREATE TABLE IF NOT EXISTS greeting_settings (
    guild_id             TEXT PRIMARY KEY,
    -- Welcome
    welcome_enabled      BOOLEAN NOT NULL DEFAULT FALSE,
    welcome_channel_id   TEXT NOT NULL DEFAULT '',
    welcome_channel_name TEXT NOT NULL DEFAULT '',
    welcome_message      TEXT NOT NULL DEFAULT '{user.mention} が {server.name} に参加しました！🎉',
    welcome_dm_enabled   BOOLEAN NOT NULL DEFAULT FALSE,
    welcome_dm_message   TEXT NOT NULL DEFAULT '',
    welcome_role_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    welcome_role_id      TEXT NOT NULL DEFAULT '',
    welcome_role_name    TEXT NOT NULL DEFAULT '',
    -- Goodbye
    goodbye_enabled      BOOLEAN NOT NULL DEFAULT FALSE,
    goodbye_channel_id   TEXT NOT NULL DEFAULT '',
    goodbye_channel_name TEXT NOT NULL DEFAULT '',
    goodbye_message      TEXT NOT NULL DEFAULT '{user.name} が {server.name} から退室しました。👋',
    goodbye_dm_enabled   BOOLEAN NOT NULL DEFAULT FALSE,
    goodbye_dm_message   TEXT NOT NULL DEFAULT '',
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. reaction_roles（リアクションロール設定）
CREATE TABLE IF NOT EXISTS reaction_roles (
    id           TEXT PRIMARY KEY,
    guild_id     TEXT NOT NULL,
    title        TEXT NOT NULL DEFAULT '',
    embed_id     TEXT NOT NULL REFERENCES embeds(id) ON DELETE CASCADE,
    channel_id   TEXT NOT NULL DEFAULT '',
    channel_name TEXT NOT NULL DEFAULT '',
    message_id   TEXT,          -- Discordに送信済みのメッセージID（未送信はNULL）
    pairs        JSONB NOT NULL DEFAULT '[]',
    mode         TEXT NOT NULL DEFAULT '通常',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 既存テーブルに message_id カラムがない場合は追加（べき等）
ALTER TABLE reaction_roles ADD COLUMN IF NOT EXISTS message_id TEXT;

-- 7. ticket_panels（チケットパネル設定）
CREATE TABLE IF NOT EXISTS ticket_panels (
    id                 TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    guild_id           TEXT NOT NULL,
    channel_id         TEXT NOT NULL DEFAULT '',
    message_id         TEXT,
    title              TEXT NOT NULL DEFAULT 'サポートチケット',
    description        TEXT NOT NULL DEFAULT 'ボタンをクリックしてチケットを作成してください。',
    color              INTEGER NOT NULL DEFAULT 6579201,   -- 0x6466F1
    button_label       TEXT NOT NULL DEFAULT 'チケットを作成',
    button_emoji       TEXT NOT NULL DEFAULT '🎫',
    support_role_id    TEXT,
    open_category_id   TEXT,
    closed_category_id TEXT,
    ticket_msg_content TEXT,
    ticket_embed_title TEXT NOT NULL DEFAULT 'チケット',
    ticket_embed_color INTEGER NOT NULL DEFAULT 6579201,
    max_open_per_user  INTEGER NOT NULL DEFAULT 1,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. tickets（チケット）
CREATE TABLE IF NOT EXISTS tickets (
    id                  TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    guild_id            TEXT NOT NULL,
    channel_id          TEXT NOT NULL,
    opened_by_user_id   TEXT NOT NULL,
    subject             TEXT NOT NULL,
    status              TEXT NOT NULL DEFAULT 'open',    -- open / pending / closed
    priority            TEXT NOT NULL DEFAULT 'medium',  -- low / medium / high / urgent
    assigned_to_user_id TEXT,
    panel_id            TEXT REFERENCES ticket_panels(id) ON DELETE SET NULL,
    opened_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at           TIMESTAMPTZ,
    last_message_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    message_count       INTEGER NOT NULL DEFAULT 0
);

-- 9. ticket_messages（チケットメッセージ）
CREATE TABLE IF NOT EXISTS ticket_messages (
    id         TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    ticket_id  TEXT NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    user_id    TEXT NOT NULL,
    username   TEXT NOT NULL DEFAULT '',
    content    TEXT NOT NULL,
    is_staff   BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 10. shops（ショップ）
CREATE TABLE IF NOT EXISTS shops (
    id                  TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    guild_id            TEXT NOT NULL,
    name                TEXT NOT NULL,
    description         TEXT NOT NULL DEFAULT '',
    enabled             BOOLEAN NOT NULL DEFAULT TRUE,
    channel_id          TEXT NOT NULL DEFAULT '',
    message_id          TEXT,
    order_category_id   TEXT,
    archive_category_id TEXT,
    support_role_id     TEXT,
    timeout_hours       INTEGER,               -- NULL=タイムアウトなし
    color               INTEGER NOT NULL DEFAULT 6579201,
    footer_text         TEXT NOT NULL DEFAULT '本Botは取引の仲介・保証・管理に一切関与しません。取引に関するトラブルはサーバー管理者および取引相手との間で解決してください。',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 11. products（商品）
CREATE TABLE IF NOT EXISTS products (
    id                TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    shop_id           TEXT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    name              TEXT NOT NULL,
    description       TEXT NOT NULL DEFAULT '',
    price_display     TEXT NOT NULL DEFAULT '要相談',
    image_url         TEXT,
    stock             INTEGER,                 -- NULL=無制限
    reward_type       TEXT NOT NULL DEFAULT 'text',  -- text/url/role/dm
    reward_content    TEXT,
    reward_role_id    TEXT,
    reward_dm_content TEXT,
    position          INTEGER NOT NULL DEFAULT 0,
    enabled           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 12. orders（注文）
CREATE TABLE IF NOT EXISTS orders (
    id                      TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    shop_id                 TEXT NOT NULL REFERENCES shops(id),
    product_id              TEXT NOT NULL REFERENCES products(id),
    guild_id                TEXT NOT NULL,
    channel_id              TEXT NOT NULL DEFAULT '',
    buyer_user_id           TEXT NOT NULL,
    buyer_username          TEXT NOT NULL,
    product_name            TEXT NOT NULL,
    product_price_display   TEXT NOT NULL DEFAULT '',
    status                  TEXT NOT NULL DEFAULT 'open',  -- open/paid/delivered/completed/cancelled/disputed
    buyer_confirmed         BOOLEAN NOT NULL DEFAULT FALSE,
    seller_confirmed        BOOLEAN NOT NULL DEFAULT FALSE,
    buyer_cancel_requested  BOOLEAN NOT NULL DEFAULT FALSE,
    seller_cancel_requested BOOLEAN NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    paid_at                 TIMESTAMPTZ,
    delivered_at            TIMESTAMPTZ,
    completed_at            TIMESTAMPTZ,
    cancelled_at            TIMESTAMPTZ
);

-- 13. temp_channel_settings（一時チャンネル設定）
CREATE TABLE IF NOT EXISTS temp_channel_settings (
    id                      TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    guild_id                TEXT NOT NULL UNIQUE,
    enabled                 BOOLEAN NOT NULL DEFAULT FALSE,
    category_id             TEXT,
    -- チャンネル名フォーマット: {vc-name} {user-name} {count} が使える
    channel_name_format     TEXT NOT NULL DEFAULT '💬-{vc-name}',
    auto_delete             BOOLEAN NOT NULL DEFAULT TRUE,
    delete_delay_minutes    INTEGER NOT NULL DEFAULT 0,   -- 0=即削除
    join_leave_notification BOOLEAN NOT NULL DEFAULT TRUE,
    watch_all_vcs           BOOLEAN NOT NULL DEFAULT TRUE,
    watch_vc_ids            JSONB NOT NULL DEFAULT '[]',  -- 特定VCのみ監視する場合のID一覧
    min_members             INTEGER NOT NULL DEFAULT 1,   -- 最小参加人数
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 11. temp_channels（アクティブな一時チャンネル）
CREATE TABLE IF NOT EXISTS temp_channels (
    id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    guild_id        TEXT NOT NULL,
    vc_channel_id   TEXT NOT NULL,
    text_channel_id TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 14. temp_vc_sources（一時VC設定）
CREATE TABLE IF NOT EXISTS temp_vc_sources (
    id                      TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    guild_id                TEXT NOT NULL,
    trigger_vc_id           TEXT,                  -- 作成されたトリガーVCのDiscord ID
    trigger_vc_name         TEXT NOT NULL DEFAULT '一時VCを作成', -- トリガーVCの名前
    vc_category_id          TEXT NOT NULL,         -- 一時VCの作成先カテゴリ
    text_channel_category_id TEXT NOT NULL,        -- 一時テキストチャンネルの作成先カテゴリ
    vc_name_format          TEXT NOT NULL DEFAULT '{user-name}のVC',
    channel_name_format     TEXT NOT NULL DEFAULT '{user-name}の部屋',
    user_limit              INTEGER NOT NULL DEFAULT 0,   -- 0=無制限
    auto_delete             BOOLEAN NOT NULL DEFAULT TRUE,
    delete_delay_minutes    INTEGER NOT NULL DEFAULT 0,
    join_leave_notification BOOLEAN NOT NULL DEFAULT TRUE,
    enabled                 BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- temp_channelsにtemp_vc_source_id追加（一時VC用）
ALTER TABLE temp_channels ADD COLUMN IF NOT EXISTS temp_vc_source_id TEXT;

-- 15. automod_settings（AutoMod設定）
CREATE TABLE IF NOT EXISTS automod_settings (
    id                      TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    guild_id                TEXT NOT NULL UNIQUE,
    -- スパム対策
    msg_spam_enabled        BOOLEAN NOT NULL DEFAULT TRUE,
    msg_spam_count          INTEGER NOT NULL DEFAULT 5,
    msg_spam_seconds        INTEGER NOT NULL DEFAULT 5,
    dup_msg_enabled         BOOLEAN NOT NULL DEFAULT FALSE,
    dup_msg_count           INTEGER NOT NULL DEFAULT 3,
    mention_enabled         BOOLEAN NOT NULL DEFAULT TRUE,
    mention_limit           INTEGER NOT NULL DEFAULT 5,
    mass_mention_enabled    BOOLEAN NOT NULL DEFAULT TRUE,
    mass_mention_limit      INTEGER NOT NULL DEFAULT 3,
    emoji_enabled           BOOLEAN NOT NULL DEFAULT FALSE,
    emoji_limit             INTEGER NOT NULL DEFAULT 10,
    caps_enabled            BOOLEAN NOT NULL DEFAULT TRUE,
    caps_percent            INTEGER NOT NULL DEFAULT 70,
    -- コンテンツフィルター
    keyword_enabled         BOOLEAN NOT NULL DEFAULT TRUE,
    blocked_keywords        JSONB NOT NULL DEFAULT '[]',
    regex_enabled           BOOLEAN NOT NULL DEFAULT FALSE,
    blocked_regex           JSONB NOT NULL DEFAULT '[]',
    invite_link_enabled     BOOLEAN NOT NULL DEFAULT TRUE,
    phishing_enabled        BOOLEAN NOT NULL DEFAULT TRUE,
    link_filter_enabled     BOOLEAN NOT NULL DEFAULT FALSE,
    link_mode               TEXT NOT NULL DEFAULT 'allowAll',
    allowed_links           JSONB NOT NULL DEFAULT '[]',
    nsfw_enabled            BOOLEAN NOT NULL DEFAULT FALSE,
    -- アカウント保護
    min_age_enabled         BOOLEAN NOT NULL DEFAULT FALSE,
    min_age_days            INTEGER NOT NULL DEFAULT 7,
    new_member_enabled      BOOLEAN NOT NULL DEFAULT FALSE,
    new_member_mins         INTEGER NOT NULL DEFAULT 10,
    raid_enabled            BOOLEAN NOT NULL DEFAULT FALSE,
    raid_joins              INTEGER NOT NULL DEFAULT 10,
    raid_seconds            INTEGER NOT NULL DEFAULT 30,
    -- アンチヌーク
    anti_nuke_enabled       BOOLEAN NOT NULL DEFAULT FALSE,
    channel_delete_limit    INTEGER NOT NULL DEFAULT 3,
    channel_delete_seconds  INTEGER NOT NULL DEFAULT 10,
    role_delete_limit       INTEGER NOT NULL DEFAULT 3,
    role_delete_seconds     INTEGER NOT NULL DEFAULT 10,
    mass_ban_limit          INTEGER NOT NULL DEFAULT 5,
    mass_ban_seconds        INTEGER NOT NULL DEFAULT 30,
    -- アクション
    default_action          TEXT NOT NULL DEFAULT 'deleteAndWarn',
    timeout_minutes         INTEGER NOT NULL DEFAULT 60,
    escalation_enabled      BOOLEAN NOT NULL DEFAULT TRUE,
    escalation_steps        JSONB NOT NULL DEFAULT '[{"violations":3,"action":{"type":"timeout","minutes":10}},{"violations":5,"action":{"type":"timeout","minutes":60}},{"violations":10,"action":{"type":"kick"}},{"violations":15,"action":{"type":"ban"}}]',
    log_enabled             BOOLEAN NOT NULL DEFAULT TRUE,
    log_channel_id          TEXT NOT NULL DEFAULT '',
    -- 除外
    exempt_roles            JSONB NOT NULL DEFAULT '[]',
    exempt_channels         JSONB NOT NULL DEFAULT '[]',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- インデックス
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_scheduled_status  ON scheduled_messages(status);
CREATE INDEX IF NOT EXISTS idx_scheduled_time    ON scheduled_messages(scheduled_for);
CREATE INDEX IF NOT EXISTS idx_channels_guild    ON channels(guild_id);
CREATE INDEX IF NOT EXISTS idx_rr_guild          ON reaction_roles(guild_id);
CREATE INDEX IF NOT EXISTS idx_tickets_guild     ON tickets(guild_id);
CREATE INDEX IF NOT EXISTS idx_tickets_status    ON tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_channel   ON tickets(channel_id);
CREATE INDEX IF NOT EXISTS idx_ticket_msgs       ON ticket_messages(ticket_id);
CREATE INDEX IF NOT EXISTS idx_shops_guild        ON shops(guild_id);
CREATE INDEX IF NOT EXISTS idx_products_shop      ON products(shop_id);
CREATE INDEX IF NOT EXISTS idx_orders_guild       ON orders(guild_id);
CREATE INDEX IF NOT EXISTS idx_orders_status      ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_shop        ON orders(shop_id);
CREATE INDEX IF NOT EXISTS idx_temp_ch_guild      ON temp_channels(guild_id);
CREATE INDEX IF NOT EXISTS idx_temp_ch_vc        ON temp_channels(vc_channel_id);
CREATE INDEX IF NOT EXISTS idx_temp_vc_guild     ON temp_vc_sources(guild_id);
CREATE INDEX IF NOT EXISTS idx_temp_vc_trigger   ON temp_vc_sources(trigger_vc_id);

-- ============================================================
-- Row Level Security（RLS）: 認証済みの全操作を許可
-- ============================================================
ALTER TABLE embeds             ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE guilds             ENABLE ROW LEVEL SECURITY;
ALTER TABLE channels           ENABLE ROW LEVEL SECURITY;
ALTER TABLE reaction_roles     ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_panels      ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets            ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_messages    ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all for authenticated users" ON embeds             FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON scheduled_messages FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON guilds             FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON channels           FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON reaction_roles     FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON ticket_panels      FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON tickets            FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON ticket_messages         FOR ALL USING (auth.role() = 'authenticated');
ALTER TABLE shops   ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders   ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for authenticated users" ON shops    FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON products FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON orders   FOR ALL USING (auth.role() = 'authenticated');
ALTER TABLE temp_channel_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE temp_channels         ENABLE ROW LEVEL SECURITY;
ALTER TABLE temp_vc_sources       ENABLE ROW LEVEL SECURITY;
ALTER TABLE automod_settings      ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for authenticated users" ON temp_channel_settings   FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON temp_channels            FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON temp_vc_sources          FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON automod_settings         FOR ALL USING (auth.role() = 'authenticated');

-- ============================================================
-- サンプルデータ（初回のみ）
-- ============================================================
INSERT INTO embeds (id, name, title, description, color_hex, fields, footer_text, show_timestamp) VALUES
('e001', 'Welcome Message', 'Welcome to Valorant JP! 🎮', 'Read the rules, have fun!',
 8159469,  -- 0x7C3AED
 '[{"id":"ef001","name":"ルール","value":"#rules","inline":true},{"id":"ef002","name":"サポート","value":"#help","inline":true}]',
 'BotForge', FALSE),
('e002', 'Stream Started', '星宮ルナ is LIVE! 🎤', 'Playing Minecraft tonight!',
 15483033, -- 0xEC4899
 '[]',
 'Twitch · Now', TRUE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO guilds (id, discord_id, name, member_count, user_role, category) VALUES
('g001', '111111111111111111', 'Valorant JP', 1234, 'admin', 'gaming'),
('g002', '222222222222222222', '星宮ルナFanclub', 3892, 'owner', 'vtuber')
ON CONFLICT (id) DO NOTHING;

INSERT INTO channels (id, guild_id, name, type, category_name, bot_can_send) VALUES
('c001', 'g001', 'general',        'text',         'General',     TRUE),
('c002', 'g001', 'announcements',  'announcement', 'General',     TRUE),
('c003', 'g001', 'valorant-tips',  'text',         'Gaming',      TRUE),
('c006', 'g002', 'general',        'text',         'General',     TRUE),
('c007', 'g002', 'luna-fan-art',   'text',         'Fan Content', TRUE),
('c008', 'g002', 'stream-notify',  'announcement', 'General',     TRUE)
ON CONFLICT (id) DO NOTHING;

-- ── ステータスチャンネル ─────────────────────────────────────────
-- stat_type: members | online | boosts | vc_users
CREATE TABLE IF NOT EXISTS stat_channels (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
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

-- ── message_count アトミックインクリメント (#4) ─────────────────
CREATE OR REPLACE FUNCTION increment_ticket_message_count(p_ticket_id uuid)
RETURNS void LANGUAGE sql AS $$
  UPDATE tickets SET message_count = message_count + 1 WHERE id = p_ticket_id;
$$;

-- ── ギルド統計（VC接続人数など）(#2: vc_users 用) ────────────────
CREATE TABLE IF NOT EXISTS guild_stats (
  guild_id      text        PRIMARY KEY,
  vc_user_count integer     NOT NULL DEFAULT 0,
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- ── 課金機能 ──────────────────────────────────────────────────

-- ユーザープロフィール（Supabase auth.users に紐付く）
CREATE TABLE IF NOT EXISTS user_profiles (
  id                        uuid    PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  discord_user_id           text    NOT NULL UNIQUE,
  purchased_slots           integer NOT NULL DEFAULT 0,
  subscription_product_id   text,
  subscription_expires_at   timestamptz,
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_user_profiles_discord ON user_profiles(discord_user_id);

-- 有効化済みサーバー（1サーバー = 1スロット消費）
CREATE TABLE IF NOT EXISTS activated_servers (
  id               uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  discord_user_id  text    NOT NULL,
  guild_id         text    NOT NULL,
  activated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT activated_servers_guild_unique UNIQUE (guild_id),
  CONSTRAINT activated_servers_user_guild   UNIQUE (discord_user_id, guild_id)
);
CREATE INDEX IF NOT EXISTS idx_activated_servers_user  ON activated_servers(discord_user_id);
CREATE INDEX IF NOT EXISTS idx_activated_servers_guild ON activated_servers(guild_id);

-- RLS: Worker (service_role) のみ書き込み可
ALTER TABLE activated_servers ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles     ENABLE ROW LEVEL SECURITY;
CREATE POLICY "service_role_full_activated" ON activated_servers
  USING (auth.role() = 'service_role');
CREATE POLICY "service_role_full_profiles" ON user_profiles
  USING (auth.role() = 'service_role');
