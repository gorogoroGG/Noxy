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
CREATE POLICY "Allow all for authenticated users" ON temp_channel_settings   FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON temp_channels            FOR ALL USING (auth.role() = 'authenticated');

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
