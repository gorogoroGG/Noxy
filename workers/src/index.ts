// ── チケット型定義 ───────────────────────────────────────────

interface TicketRow {
  id: string;
  guild_id: string;
  channel_id: string;
  opened_by_user_id: string;
  subject: string;
  status: string;
  priority: string;
  assigned_to_user_id: string | null;
  panel_id: string | null;
  opened_at: string;
  closed_at: string | null;
  last_message_at: string;
  message_count: number;
}

interface TicketMessageRow {
  id: string;
  ticket_id: string;
  user_id: string;
  username: string;
  content: string;
  is_staff: boolean;
  created_at: string;
}

function mapTicket(t: TicketRow) {
  return {
    id:               t.id,
    guildId:          t.guild_id,
    channelId:        t.channel_id,
    openedBy:         t.opened_by_user_id,
    subject:          t.subject,
    status:           t.status,
    priority:         t.priority,
    assignedToUserId: t.assigned_to_user_id ?? null,
    panelId:          t.panel_id ?? null,
    openedAt:         t.opened_at,
    closedAt:         t.closed_at ?? null,
    lastMessageAt:    t.last_message_at,
    messageCount:     t.message_count,
  };
}

function mapTicketMessage(m: TicketMessageRow) {
  return {
    id:        m.id,
    ticketId:  m.ticket_id,
    userId:    m.user_id,
    username:  m.username,
    content:   m.content,
    isStaff:   m.is_staff,
    createdAt: m.created_at,
  };
}

// ── 認証型定義 ───────────────────────────────────────────────

interface VerifyPanelRow {
  id: string; guild_id: string; name: string; description: string;
  channel_id: string; message_id: string | null; role_id: string;
  color: number; footer_text: string; button_label: string; enabled: boolean;
  verify_type: string; reaction_emoji: string; manual_channel_id: string | null;
  created_at: string;
}
interface VerifyRequestRow {
  id: string; panel_id: string; guild_id: string; user_id: string;
  username: string; avatar_url: string | null; status: string;
  created_at: string; resolved_at: string | null;
}

function mapVerifyPanel(r: VerifyPanelRow) {
  return { id: r.id, guildId: r.guild_id, name: r.name, description: r.description,
    channelId: r.channel_id, messageId: r.message_id, roleId: r.role_id,
    color: r.color, footerText: r.footer_text, buttonLabel: r.button_label,
    enabled: r.enabled, verifyType: r.verify_type, reactionEmoji: r.reaction_emoji,
    manualChannelId: r.manual_channel_id, createdAt: r.created_at };
}
function mapVerifyRequest(r: VerifyRequestRow) {
  return { id: r.id, panelId: r.panel_id, guildId: r.guild_id, userId: r.user_id,
    username: r.username, avatarUrl: r.avatar_url, status: r.status,
    createdAt: r.created_at, resolvedAt: r.resolved_at };
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
  });
}

async function hmacSign(message: string, secret: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
  );
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(message));
  return Array.from(new Uint8Array(sig)).map(b => b.toString(16).padStart(2, '0')).join('');
}

function verifyHtml(panelId: string, u: string, g: string, exp: string, sig: string, panelName: string, color: number, siteKey: string): string {
  const hex = '#' + color.toString(16).padStart(6, '0');
  return `<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${panelName} - 認証</title>
  <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#1a1b2e;min-height:100vh;display:flex;align-items:center;justify-content:center;padding:16px}
    .card{background:#2a2b3d;border-radius:16px;padding:32px 28px;max-width:400px;width:100%;box-shadow:0 8px 32px rgba(0,0,0,0.4);border:1px solid rgba(255,255,255,0.06)}
    .accent{width:100%;height:3px;border-radius:2px;background:${hex};margin-bottom:24px}
    .icon{width:56px;height:56px;border-radius:14px;background:${hex}22;display:flex;align-items:center;justify-content:center;margin:0 auto 16px;font-size:24px}
    h1{color:#fff;font-size:20px;font-weight:700;text-align:center;margin-bottom:8px}
    p{color:#9ca3af;font-size:14px;text-align:center;line-height:1.6;margin-bottom:24px}
    .turnstile-wrap{display:flex;justify-content:center;margin-bottom:20px}
    button{width:100%;padding:14px;background:${hex};color:#fff;border:none;border-radius:10px;font-size:15px;font-weight:600;cursor:pointer;transition:opacity 0.2s}
    button:disabled{opacity:0.5;cursor:not-allowed}
    .status{margin-top:16px;padding:12px;border-radius:8px;font-size:13px;text-align:center;display:none}
    .status.success{background:#10b98122;color:#10b981;display:block}
    .status.error{background:#ef444422;color:#ef4444;display:block}
  </style>
</head>
<body>
  <div class="card">
    <div class="accent"></div>
    <div class="icon">🛡️</div>
    <h1>${panelName}</h1>
    <p>下の認証ウィジェットを完了してください。<br>認証が完了するとロールが自動で付与されます。</p>
    <div class="turnstile-wrap">
      <div class="cf-turnstile" data-sitekey="${siteKey || '1x00000000000000000000AA'}" data-theme="dark" data-callback="onTurnstileSuccess"></div>
    </div>
    <button id="btn" disabled onclick="submitVerify()">認証する</button>
    <div id="status" class="status"></div>
  </div>
  <script>
    let turnstileToken = '';
    function onTurnstileSuccess(token) { turnstileToken = token; document.getElementById('btn').disabled = false; }
    async function submitVerify() {
      const btn = document.getElementById('btn');
      const status = document.getElementById('status');
      btn.disabled = true; btn.textContent = '認証中...'; status.className = 'status';
      try {
        const res = await fetch('/verify/${panelId}/complete', {
          method: 'POST', headers: {'Content-Type':'application/json'},
          body: JSON.stringify({ u:'${u}', g:'${g}', exp:'${exp}', sig:'${sig}', token: turnstileToken })
        });
        const data = await res.json();
        if (data.ok) {
          status.className = 'status success'; status.textContent = '✅ 認証完了！ロールが付与されました。このページを閉じてDiscordにお戻りください。';
          btn.textContent = '認証完了'; btn.style.background = '#10b981';
        } else {
          status.className = 'status error'; status.textContent = '❌ ' + (data.error || '認証に失敗しました');
          btn.disabled = false; btn.textContent = '再試行';
        }
      } catch(e) {
        status.className = 'status error'; status.textContent = '❌ 通信エラーが発生しました。';
        btn.disabled = false; btn.textContent = '再試行';
      }
    }
  </script>
</body>
</html>`;
}

function verifyErrorPage(message: string): Response {
  return new Response(`<!DOCTYPE html><html lang="ja"><head><meta charset="UTF-8"><title>エラー</title>
<style>body{font-family:-apple-system,sans-serif;background:#1a1b2e;min-height:100vh;display:flex;align-items:center;justify-content:center}
.card{background:#2a2b3d;border-radius:16px;padding:32px;max-width:380px;text-align:center;color:#fff}
.icon{font-size:40px;margin-bottom:16px}.msg{color:#9ca3af;font-size:14px;line-height:1.6}</style></head>
<body><div class="card"><div class="icon">⚠️</div><h2>エラー</h2><p class="msg">${message}</p></div></body></html>`,
    { headers: { 'Content-Type': 'text/html; charset=utf-8' } });
}

// ── ショップ型定義 ────────────────────────────────────────────

interface ShopRow {
  id: string; guild_id: string; shop_type: string; name: string; description: string; enabled: boolean;
  disabled_message: string | null;
  channel_id: string; message_id: string | null;
  order_category_id: string | null; archive_category_id: string | null;
  support_role_id: string | null; timeout_hours: number | null;
  color: number; footer_text: string;
  review_enabled: boolean; review_channel_id: string | null;
  welcome_image_url: string | null; welcome_thumbnail_url: string | null;
  welcome_fields: Array<{name: string; value: string; inline: boolean}>;
  welcome_footer_text: string | null; welcome_footer_icon_url: string | null;
  welcome_show_timestamp: boolean;
  payment_input_label: string | null;
  auto_delete_enabled: boolean; auto_delete_days: number | null;
  created_at: string;
}

function mapShop(s: ShopRow) {
  return { id: s.id, guildId: s.guild_id, shopType: s.shop_type ?? 'shop',
    name: s.name, description: s.description,
    enabled: s.enabled, disabledMessage: s.disabled_message,
    channelId: s.channel_id, messageId: s.message_id,
    orderCategoryId: s.order_category_id, archiveCategoryId: s.archive_category_id,
    supportRoleId: s.support_role_id, timeoutHours: s.timeout_hours,
    color: s.color, footerText: s.footer_text,
    reviewEnabled: s.review_enabled ?? false, reviewChannelId: s.review_channel_id ?? null,
    welcomeImageUrl: s.welcome_image_url, welcomeThumbnailUrl: s.welcome_thumbnail_url,
    welcomeFields: s.welcome_fields ?? [],
    welcomeFooterText: s.welcome_footer_text, welcomeFooterIconUrl: s.welcome_footer_icon_url,
    welcomeShowTimestamp: s.welcome_show_timestamp,
    paymentInputLabel: s.payment_input_label ?? null,
    autoDeleteEnabled: s.auto_delete_enabled ?? false, autoDeleteDays: s.auto_delete_days ?? null,
    createdAt: s.created_at };
}
interface ProductRow {
  id: string; shop_id: string; name: string; description: string;
  price_display: string; image_url: string | null; stock: number | null;
  reward_type: string; reward_content: string | null;
  reward_role_id: string | null; reward_dm_content: string | null;
  position: number; enabled: boolean; created_at: string;
}
interface OrderRow {
  id: string; shop_id: string; product_id: string; guild_id: string;
  channel_id: string; buyer_user_id: string; buyer_username: string;
  product_name: string; product_price_display: string; status: string;
  buyer_confirmed: boolean; seller_confirmed: boolean;
  buyer_cancel_requested: boolean; seller_cancel_requested: boolean;
  payment_url: string | null; payment_submitted_at: string | null;
  created_at: string; paid_at: string | null; delivered_at: string | null;
  completed_at: string | null; cancelled_at: string | null;
}

function mapProduct(p: ProductRow) {
  return { id: p.id, shopId: p.shop_id, name: p.name, description: p.description,
    priceDisplay: p.price_display, imageUrl: p.image_url, stock: p.stock,
    rewardType: p.reward_type, rewardContent: p.reward_content,
    rewardRoleId: p.reward_role_id, rewardDmContent: p.reward_dm_content,
    position: p.position, enabled: p.enabled, createdAt: p.created_at };
}
function mapOrder(o: OrderRow) {
  return { id: o.id, shopId: o.shop_id, productId: o.product_id,
    guildId: o.guild_id, channelId: o.channel_id,
    buyerUserId: o.buyer_user_id, buyerUsername: o.buyer_username,
    productName: o.product_name, productPriceDisplay: o.product_price_display,
    status: o.status, buyerConfirmed: o.buyer_confirmed, sellerConfirmed: o.seller_confirmed,
    buyerCancelRequested: o.buyer_cancel_requested, sellerCancelRequested: o.seller_cancel_requested,
    paymentUrl: o.payment_url, paymentSubmittedAt: o.payment_submitted_at,
    createdAt: o.created_at, paidAt: o.paid_at, deliveredAt: o.delivered_at,
    completedAt: o.completed_at, cancelledAt: o.cancelled_at };
}

// ショップ: 対価の送信（confirm-payment から呼ぶ）
async function deliverReward(order: OrderRow, product: ProductRow, shop: ShopRow, env: Env): Promise<void> {
  const { reward_type: type, reward_content, reward_role_id, reward_dm_content } = product;
  const channelId   = order.channel_id;
  const buyerUserId = order.buyer_user_id;
  const guildId     = order.guild_id;
  const token       = env.DISCORD_BOT_TOKEN;

  const embedBase = {
    color:  shop.color,
    footer: { text: shop.footer_text },
    timestamp: new Date().toISOString(),
  };

  switch (type) {
    case 'text':
    case 'url':
      await fetch(`https://discord.com/api/v10/channels/${channelId}/messages`, {
        method: 'POST', headers: { Authorization: `Bot ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ embeds: [{ ...embedBase, title: '📦 商品を受け取りました',
          description: reward_content ?? '（対価なし）' }] }),
      });
      break;
    case 'role':
      if (reward_role_id) {
        await fetch(`https://discord.com/api/v10/guilds/${guildId}/members/${buyerUserId}/roles/${reward_role_id}`, {
          method: 'PUT', headers: { Authorization: `Bot ${token}` },
        });
        await fetch(`https://discord.com/api/v10/channels/${channelId}/messages`, {
          method: 'POST', headers: { Authorization: `Bot ${token}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ embeds: [{ ...embedBase, title: '🎭 ロールを付与しました',
            description: `<@&${reward_role_id}> を付与しました。` }] }),
        });
      }
      break;
    case 'dm': {
      const dmCh = await fetch('https://discord.com/api/v10/users/@me/channels', {
        method: 'POST', headers: { Authorization: `Bot ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ recipient_id: buyerUserId }),
      });
      if (dmCh.ok) {
        const { id: dmId } = await dmCh.json() as { id: string };
        await fetch(`https://discord.com/api/v10/channels/${dmId}/messages`, {
          method: 'POST', headers: { Authorization: `Bot ${token}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ embeds: [{ ...embedBase, title: '📦 商品のお届け',
            description: reward_dm_content ?? '（内容なし）' }] }),
        });
        await fetch(`https://discord.com/api/v10/channels/${channelId}/messages`, {
          method: 'POST', headers: { Authorization: `Bot ${token}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ embeds: [{ ...embedBase, title: '📩 DMで商品をお届けしました' }] }),
        });
      }
      break;
    }
  }
}

// ショップ: チャンネルのアーカイブ（購入者の権限を剥奪して移動）
async function archiveOrderChannel(channelId: string, buyerUserId: string, archiveCategoryId: string | null, env: Env): Promise<void> {
  const token = env.DISCORD_BOT_TOKEN;
  await fetch(`https://discord.com/api/v10/channels/${channelId}/permissions/${buyerUserId}`, {
    method: 'PUT', headers: { Authorization: `Bot ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ deny: '1024', type: 1 }),
  });
  if (archiveCategoryId) {
    await fetch(`https://discord.com/api/v10/channels/${channelId}`, {
      method: 'PATCH', headers: { Authorization: `Bot ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ parent_id: archiveCategoryId }),
    });
  }
}

// ── チケットパネル型定義 ─────────────────────────────────────

interface TicketPanelRow {
  id: string;
  guild_id: string;
  channel_id: string;
  message_id: string | null;
  title: string;
  description: string;
  color: number;
  button_label: string;
  button_emoji: string;
  support_role_id: string | null;
  open_category_id: string | null;
  closed_category_id: string | null;
  ticket_msg_content: string | null;
  ticket_embed_title: string;
  ticket_embed_color: number;
  max_open_per_user: number;
  created_at: string;
}

function mapPanel(p: TicketPanelRow) {
  return {
    id:               p.id,
    guildId:          p.guild_id,
    channelId:        p.channel_id,
    messageId:        p.message_id ?? null,
    title:            p.title,
    description:      p.description,
    color:            p.color,
    buttonLabel:      p.button_label,
    buttonEmoji:      p.button_emoji,
    supportRoleId:    p.support_role_id ?? null,
    openCategoryId:   p.open_category_id ?? null,
    closedCategoryId: p.closed_category_id ?? null,
    ticketMsgContent: p.ticket_msg_content ?? null,
    ticketEmbedTitle: p.ticket_embed_title,
    ticketEmbedColor: p.ticket_embed_color,
    maxOpenPerUser:   p.max_open_per_user,
    createdAt:        p.created_at,
  };
}

// ── 自動応答型定義 ─────────────────────────────────────────────

interface AutoResponseRow {
  id: string;
  guild_id: string;
  trigger_type: string;
  trigger: string;
  response: string;
  is_enabled: boolean;
  cooldown_sec: number;
  channel_ids: string[];
  created_at: string;
}

const triggerTypeToDB: Record<string, string> = {
  contains:   'contains',
  exact:      'exact',
  regex:      'regex',
  startsWith: 'starts_with',
  endsWith:   'ends_with',
};
const triggerTypeToiOS: Record<string, string> = {
  contains:   'contains',
  exact:      'exact',
  regex:      'regex',
  starts_with: 'startsWith',
  ends_with:  'contains',
};

function mapAutoResponse(r: AutoResponseRow) {
  return {
    id:              r.id,
    guildId:         r.guild_id,
    trigger:         r.trigger,
    response:        r.response,
    matchType:       triggerTypeToiOS[r.trigger_type] ?? 'contains',
    enabled:         r.is_enabled,
    cooldownSeconds: r.cooldown_sec,
    channelIds:      r.channel_ids ?? [],
  };
}

// ── 埋め込み型定義 ───────────────────────────────────────────

interface Embed {
  id: string;
  name: string;
  message_content: string | null;
  title: string | null;
  description: string | null;
  color_hex: number;
  fields: Array<{ name: string; value: string; inline: boolean }>;
  image_url: string | null;
  thumbnail_url: string | null;
  footer_text: string | null;
  footer_icon_url: string | null;
  show_timestamp: boolean;
}

// ── ステータスチャンネル型定義 ──────────────────────────────────

type StatType = 'members' | 'online' | 'boosts' | 'vc_users';

interface StatChannelRow {
  id: string;
  guild_id: string;
  channel_id: string;
  stat_type: StatType;
  is_enabled: boolean;
  last_value: number;
  last_updated_at: string | null;
  created_at: string;
}

function mapStatChannel(r: StatChannelRow) {
  return {
    id:            r.id,
    guildId:       r.guild_id,
    channelId:     r.channel_id,
    statType:      r.stat_type,
    isEnabled:     r.is_enabled,
    lastValue:     r.last_value,
    lastUpdatedAt: r.last_updated_at ?? null,
  };
}

// stat_type ごとのラベル生成（Discord チャンネル名は32文字以内）
function statChannelLabel(type: StatType, value: number): string {
  switch (type) {
    case 'members':  return `👥 メンバー: ${value.toLocaleString('ja-JP')}`;
    case 'online':   return `🟢 オンライン: ${value.toLocaleString('ja-JP')}`;
    case 'boosts':   return `🚀 Boost: ${value}`;
    case 'vc_users': return `🎙️ VC中: ${value}人`;
  }
}

// 1チャンネルの値を取得
async function fetchStatValue(type: StatType, guildId: string, token: string, sbFetch: typeof supabaseFetch): Promise<number> {
  switch (type) {
    case 'members': {
      const r = await fetch(`https://discord.com/api/v10/guilds/${guildId}?with_counts=true`, {
        headers: { Authorization: `Bot ${token}` },
      });
      if (!r.ok) return -1;
      const g = await r.json() as any;
      return g.approximate_member_count ?? g.member_count ?? -1;
    }
    case 'online': {
      const r = await fetch(`https://discord.com/api/v10/guilds/${guildId}?with_counts=true`, {
        headers: { Authorization: `Bot ${token}` },
      });
      if (!r.ok) return -1;
      const g = await r.json() as any;
      return g.approximate_presence_count ?? -1;
    }
    case 'boosts': {
      const r = await fetch(`https://discord.com/api/v10/guilds/${guildId}`, {
        headers: { Authorization: `Bot ${token}` },
      });
      if (!r.ok) return -1;
      const g = await r.json() as any;
      return g.premium_subscription_count ?? 0;
    }
    case 'vc_users': {
      // Bot がイベントで更新する guild_stats テーブルから取得 (#2: /voice-states は存在しないため)
      const r = await sbFetch(`/guild_stats?guild_id=eq.${guildId}&select=vc_user_count`);
      if (!r.ok) return 0;
      const rows = await r.json() as any[];
      return rows[0]?.vc_user_count ?? 0;
    }
  }
}

async function updateSingleStatChannel(row: StatChannelRow, env: Env): Promise<void> {
  const sbLocal = makeSupabaseFetch(env);
  const newValue = await fetchStatValue(row.stat_type, row.guild_id, env.DISCORD_BOT_TOKEN, supabaseFetch);
  if (newValue === -1) return; // 取得失敗
  if (newValue === row.last_value) return; // 変化なし → API コール不要

  const newName = statChannelLabel(row.stat_type, newValue);

  const patchResp = await fetch(`https://discord.com/api/v10/channels/${row.channel_id}`, {
    method: 'PATCH',
    headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: newName }),
  });

  if (patchResp.ok) {
    await sbLocal(`/stat_channels?id=eq.${row.id}`, {
      method: 'PATCH',
      body: JSON.stringify({ last_value: newValue, last_updated_at: new Date().toISOString() }),
    });
    console.log(`[StatChannel] ${row.stat_type} → ${newValue} (ch: ${row.channel_id})`);
  } else {
    const errText = await patchResp.text();
    console.error(`[StatChannel] チャンネル更新失敗 (${row.channel_id}): ${patchResp.status} ${errText}`);
  }
}

async function processStatChannels(env: Env): Promise<void> {
  const sbLocal = makeSupabaseFetch(env);
  const BATCH_LIMIT   = 24;
  const RATE_LIMIT_MS = 60 * 60 * 1000; // 1時間に1回
  const now           = Date.now();
  const cutoffISO     = new Date(now - RATE_LIMIT_MS).toISOString();

  // Step 1: 課金済みサーバーを取得（0件なら即終了 → Discord API コール 0回）
  const activatedResp = await sbLocal('/activated_servers?select=guild_id');
  if (!activatedResp.ok) { console.error('[StatChannel] activated_servers取得失敗'); return; }
  const activatedRows: { guild_id: string }[] = await activatedResp.json();
  if (activatedRows.length === 0) {
    console.log('[StatChannel] 課金サーバーなし、スキップ');
    return;
  }

  const guildIdList = activatedRows.map(r => r.guild_id).join(',');

  // Step 2: 課金済みサーバーの stat_channels のみ取得（最大24件）
  const resp = await sbLocal(
    `/stat_channels?is_enabled=eq.true&guild_id=in.(${guildIdList})` +
    `&or=(last_updated_at.is.null,last_updated_at.lte.${cutoffISO})` +
    `&order=last_updated_at.asc.nullsfirst&limit=${BATCH_LIMIT}`
  );
  if (!resp.ok) { console.error('[StatChannel] Supabase取得失敗'); return; }
  const rows: StatChannelRow[] = await resp.json();
  if (rows.length === 0) { console.log('[StatChannel] 更新対象なし'); return; }

  console.log(`[StatChannel] ${rows.length}件を更新（課金サーバー: ${activatedRows.length}件）`);

  for (const row of rows) {
    if (row.last_updated_at) {
      const elapsed = now - new Date(row.last_updated_at).getTime();
      if (elapsed < RATE_LIMIT_MS) continue;
    }
    await updateSingleStatChannel(row, env);
    await new Promise(r => setTimeout(r, 500));
  }
}

// ── 課金: スロットマップ ──────────────────────────────────────

const SLOT_MAP: Record<string, number> = {
  'jp.noxyapp.stat.1server': 1,
  'jp.noxyapp.stat.2server': 2,
  'jp.noxyapp.stat.3server': 3,
  'jp.noxyapp.stat.5server': 5,
};

// ── 課金: Supabase JWT 検証ヘルパー ──────────────────────────

async function verifySupabaseJwt(
  jwt: string,
  expectedDiscordUserId: string,
  env: Env
): Promise<{ ok: true; supabaseUserId: string } | { ok: false; error: string }> {
  if (!jwt) return { ok: false, error: 'Missing JWT' };

  const userResp = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
    headers: {
      Authorization: `Bearer ${jwt}`,
      apikey: env.SUPABASE_ANON_KEY,
    },
  });
  if (!userResp.ok) return { ok: false, error: 'Invalid or expired JWT' };

  const userJson = await userResp.json() as any;
  const supabaseUserId: string = userJson.id ?? '';

  // JWT に含まれる Discord ID を取得して照合
  const jwtDiscordId: string =
    userJson.user_metadata?.provider_id ??
    userJson.user_metadata?.sub ??
    userJson.identities?.[0]?.identity_data?.sub ??
    '';

  if (!jwtDiscordId || jwtDiscordId !== expectedDiscordUserId) {
    return { ok: false, error: 'Discord user ID mismatch' };
  }

  return { ok: true, supabaseUserId };
}

// ── Supabase JWT 検証（ES256 + HS256 両対応） ──────────────────

// JWKS 公開鍵をメモリキャッシュ（同一 Worker インスタンス内で再利用）
const jwksCache: Map<string, { keys: CryptoKey[]; fetchedAt: number }> = new Map();
const JWKS_CACHE_TTL_MS = 60 * 60 * 1000; // 1時間

async function fetchJwksKeys(supabaseUrl: string): Promise<CryptoKey[]> {
  const cached = jwksCache.get(supabaseUrl);
  if (cached && Date.now() - cached.fetchedAt < JWKS_CACHE_TTL_MS) {
    return cached.keys;
  }

  const jwksUrl = `${supabaseUrl.replace(/\/$/, '')}/auth/v1/.well-known/jwks.json`;
  const resp = await fetch(jwksUrl);
  if (!resp.ok) return [];

  const { keys } = await resp.json() as { keys: any[] };
  const cryptoKeys: CryptoKey[] = [];

  for (const jwk of keys) {
    try {
      if (jwk.kty === 'EC' && jwk.crv === 'P-256') {
        const key = await crypto.subtle.importKey(
          'jwk', jwk,
          { name: 'ECDSA', namedCurve: 'P-256' },
          false, ['verify']
        );
        cryptoKeys.push(key);
      } else if (jwk.kty === 'RSA') {
        const key = await crypto.subtle.importKey(
          'jwk', jwk,
          { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
          false, ['verify']
        );
        cryptoKeys.push(key);
      }
    } catch { /* スキップ */ }
  }

  jwksCache.set(supabaseUrl, { keys: cryptoKeys, fetchedAt: Date.now() });
  return cryptoKeys;
}

function b64urlToBytes(b64url: string): Uint8Array {
  const b64 = b64url.replace(/-/g, '+').replace(/_/g, '/');
  const pad = b64.length % 4 === 0 ? 0 : 4 - (b64.length % 4);
  return Uint8Array.from(atob(b64 + '='.repeat(pad)), c => c.charCodeAt(0));
}

function parseJwtPayload(parts: string[]): any {
  try {
    return JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')));
  } catch { return null; }
}

// ES256（ECC P-256）で検証
async function verifyEs256(header: string, payload: string, sigBytes: Uint8Array, keys: CryptoKey[]): Promise<boolean> {
  const sigInput = new TextEncoder().encode(`${header}.${payload}`);
  for (const key of keys) {
    try {
      const valid = await crypto.subtle.verify(
        { name: 'ECDSA', hash: 'SHA-256' },
        key, sigBytes, sigInput
      );
      if (valid) return true;
    } catch { /* 次のキーを試す */ }
  }
  return false;
}

// HS256（HMAC-SHA256 共有シークレット）で検証
async function verifyHs256(header: string, payload: string, sigBytes: Uint8Array, secret: string): Promise<boolean> {
  try {
    const key = await crypto.subtle.importKey(
      'raw', new TextEncoder().encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false, ['verify']
    );
    return await crypto.subtle.verify(
      'HMAC', key, sigBytes,
      new TextEncoder().encode(`${header}.${payload}`)
    );
  } catch { return false; }
}

// メイン検証関数：ES256（JWKSから公開鍵取得）→ HS256 の順で試行
async function verifySupabaseJwtLocal(
  jwt: string,
  _unused: string,        // 後方互換のため引数を残す（現在は未使用）
  supabaseUrl?: string
): Promise<boolean> {
  if (!jwt) return false;
  const parts = jwt.split('.');
  if (parts.length !== 3) return false;

  // exp チェック（早期リターン）
  const jwtPayload = parseJwtPayload(parts);
  if (!jwtPayload) return false;
  if (jwtPayload.exp && jwtPayload.exp < Math.floor(Date.now() / 1000)) return false;

  const sigBytes = b64urlToBytes(parts[2]);

  // ES256: JWKS から公開鍵を取得して検証
  if (supabaseUrl) {
    const keys = await fetchJwksKeys(supabaseUrl);
    if (keys.length > 0) {
      const valid = await verifyEs256(parts[0], parts[1], sigBytes, keys);
      if (valid) return true;
    }
  }

  return false;
}

// ── Supabase クライアント ─────────────────────────────────────

// グローバル変数（scheduled ハンドラの scheduled() で set される）
declare let SUPABASE_URL: string;
declare let SUPABASE_SERVICE_KEY: string;
declare let DISCORD_BOT_TOKEN: string;

// グローバル変数版（scheduled ハンドラ用）
function supabaseFetch(path: string, options?: RequestInit): Promise<Response> {
  const url = `${SUPABASE_URL}/rest/v1${path}`;
  return fetch(url, {
    ...options,
    headers: {
      "apikey": SUPABASE_SERVICE_KEY,
      "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}`,
      "Content-Type": "application/json",
      "Prefer": "return=representation",
      ...(options?.headers ?? {}),
    },
  });
}

// env 経由版（HTTP ハンドラ用）
function makeSupabaseFetch(env: Env) {
  return (path: string, options?: RequestInit): Promise<Response> => {
    const baseUrl = env.SUPABASE_URL.replace(/\/$/, ''); // 末尾スラッシュを除去
    const url = `${baseUrl}/rest/v1${path}`;
    return fetch(url, {
      ...options,
      headers: {
        "apikey": env.SUPABASE_SERVICE_KEY,
        "Authorization": `Bearer ${env.SUPABASE_SERVICE_KEY}`,
        "Content-Type": "application/json",
        "Prefer": "return=representation",
        ...(options?.headers ?? {}),
      },
    });
  };
}

// ── Discord 送信 ────────────────────────────────────────────

async function sendToDiscord(
  channelId: string,
  embed: Embed
): Promise<boolean> {
  const content = embed.message_content?.trim() || undefined;
  const body = {
    content,
    // 本文中のメンション（@everyone・ロール・ユーザー）を実際に通知する
    allowed_mentions: { parse: ["everyone", "roles", "users"] },
    embeds: [
      {
        title: embed.title ?? undefined,
        description: embed.description ?? undefined,
        color: embed.color_hex,
        fields: embed.fields.map((f) => ({
          name: f.name,
          value: f.value,
          inline: f.inline,
        })),
        image: embed.image_url ? { url: embed.image_url } : undefined,
        thumbnail: embed.thumbnail_url ? { url: embed.thumbnail_url } : undefined,
        footer: embed.footer_text
          ? {
              text: embed.footer_text,
              icon_url: embed.footer_icon_url ?? undefined,
            }
          : undefined,
        timestamp: embed.show_timestamp ? new Date().toISOString() : undefined,
      },
    ],
  };

  const resp = await fetch(
    `https://discord.com/api/v10/channels/${channelId}/messages`,
    {
      method: "POST",
      headers: {
        Authorization: `Bot ${DISCORD_BOT_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    }
  );

  return resp.ok;
}

// ── 注文タイムアウト処理 ──────────────────────────────────────

async function processOrderTimeouts(env: Env): Promise<void> {
  const token = env.DISCORD_BOT_TOKEN;

  // ── open タイムアウトキャンセル（最大10件）──────────────────
  const openResp = await supabaseFetch(`/orders?status=eq.open&order=created_at.asc&limit=10`);
  if (openResp.ok) {
    const openOrders: OrderRow[] = await openResp.json();
    for (const order of openOrders) {
      const shopR  = await supabaseFetch(`/shops?id=eq.${order.shop_id}`);
      const shopArr: ShopRow[] = await shopR.json();
      if (!shopArr.length) continue;
      const shop = shopArr[0];
      if (!shop.timeout_hours) continue;

      const timeoutAt = new Date(new Date(order.created_at).getTime() + shop.timeout_hours * 3600 * 1000);
      if (new Date() < timeoutAt) continue;

      await supabaseFetch(`/orders?id=eq.${order.id}`, {
        method: 'PATCH',
        body: JSON.stringify({ status: 'cancelled', cancelled_at: new Date().toISOString() }),
      });
      if (order.channel_id) {
        await fetch(`https://discord.com/api/v10/channels/${order.channel_id}/messages`, {
          method: 'POST', headers: { Authorization: `Bot ${token}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ content: `⏰ **注文がタイムアウトしました。** ${shop.timeout_hours}時間以内に支払いが確認されなかったため自動キャンセルされました。` }),
        });
        await archiveOrderChannel(order.channel_id, order.buyer_user_id, shop.archive_category_id, env);
      }
      console.log(`[Order] タイムアウトキャンセル: ${order.id}`);
    }
  }

  // ── delivered 48時間自動完了（最大5件）──────────────────────
  const deliveredResp = await supabaseFetch(`/orders?status=eq.delivered&order=delivered_at.asc&limit=5`);
  if (!deliveredResp.ok) return;
  const deliveredOrders: OrderRow[] = await deliveredResp.json();

  for (const order of deliveredOrders) {
    if (!order.delivered_at) continue;
    const autoCompleteAt = new Date(new Date(order.delivered_at).getTime() + 48 * 3600 * 1000);
    if (new Date() < autoCompleteAt) continue;

    const now = new Date().toISOString();
    await supabaseFetch(`/orders?id=eq.${order.id}`, {
      method: 'PATCH',
      body: JSON.stringify({ status: 'completed', completed_at: now, buyer_confirmed: true }),
    });

    const shopR = await supabaseFetch(`/shops?id=eq.${order.shop_id}`);
    const shopArr: ShopRow[] = shopR.ok ? await shopR.json() : [];
    const shop = shopArr[0] ?? null;

    if (order.channel_id && token) {
      const components: unknown[] = [{
        type: 1,
        components: [
          { type: 2, style: 2, label: '🔒 チャンネルを閉じる', custom_id: `order_complete_close_${order.id}` },
          ...(shop?.review_enabled ? [{ type: 2, style: 1, label: '⭐ レビューする', custom_id: `order_review_${order.id}` }] : []),
        ],
      }];
      await fetch(`https://discord.com/api/v10/channels/${order.channel_id}/messages`, {
        method: 'POST', headers: { Authorization: `Bot ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          embeds: [{ title: '🎉 取引完了（自動）', color: 0x10b981, timestamp: now,
            description: `⏰ 48時間が経過したため、自動的に取引完了となりました。\n\nチャンネルを閉じる場合は下のボタンを押してください。${shop?.review_enabled ? '\nレビューも受け付けています！' : ''}` }],
          components,
        }),
      });
    }

    // 購入者DM
    if (order.buyer_user_id && token) {
      const dmR = await fetch('https://discord.com/api/v10/users/@me/channels', {
        method: 'POST', headers: { Authorization: `Bot ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ recipient_id: order.buyer_user_id }),
      });
      if (dmR.ok) {
        const { id: dmId } = await dmR.json() as { id: string };
        await fetch(`https://discord.com/api/v10/channels/${dmId}/messages`, {
          method: 'POST', headers: { Authorization: `Bot ${token}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ content: `🎉 **${order.product_name}** の取引が自動完了しました（48時間経過）。ありがとうございました！` }),
        });
      }
    }
    console.log(`[Order] 48h自動完了: ${order.id}`);
  }
}

// ── Worker Entry Point ───────────────────────────────────────

// ── Discord Ed25519 署名検証 ────────────────────────────────────
async function verifyDiscordSignature(
  publicKey: string,
  signature: string,
  timestamp: string,
  body: string,
): Promise<boolean> {
  try {
    const encoder = new TextEncoder();
    const keyBytes = hexToUint8Array(publicKey);
    const sigBytes = hexToUint8Array(signature);
    const msgBytes = encoder.encode(timestamp + body);

    const cryptoKey = await crypto.subtle.importKey(
      'raw',
      keyBytes,
      { name: 'NODE-ED25519', namedCurve: 'NODE-ED25519' },
      false,
      ['verify'],
    );
    return await crypto.subtle.verify('NODE-ED25519', cryptoKey, sigBytes, msgBytes);
  } catch {
    return false;
  }
}

function hexToUint8Array(hex: string): Uint8Array {
  const len = hex.length / 2;
  const arr = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    arr[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return arr;
}

export default {
  // HTTP API エンドポイント
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // ── CORS プリフライト (#10) ──────────────────────────────
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: {
          'Access-Control-Allow-Origin':  '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, X-Bot-Secret, Authorization',
          'Access-Control-Max-Age':       '86400',
        },
      });
    }

    // スラッシュコマンド登録（X-Bot-Secret が正しい場合のみ）
    if (url.pathname === '/bot/register-commands' && request.method === 'POST') {
      const secret = request.headers.get('X-Bot-Secret') ?? '';
      if (env.WORKER_API_SECRET && secret !== env.WORKER_API_SECRET) {
        return jsonResponse({ error: 'Unauthorized' }, 401);
      }
      const commands = [
        {
          name: 'ping',
          description: 'BotがオンラインかどうかをDiscordから確認します',
          type: 1,
        },
      ];
      const regResp = await fetch(
        `https://discord.com/api/v10/applications/${env.DISCORD_CLIENT_ID}/commands`,
        {
          method: 'PUT',
          headers: {
            Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(commands),
        },
      );
      if (!regResp.ok) {
        const err = await regResp.text();
        return jsonResponse({ error: 'Discord API error', detail: err }, 500);
      }
      const result = await regResp.json();
      return jsonResponse({ ok: true, registered: result });
    }

    // Bot 疎通確認（認証不要・Discord API 不使用）
    if (url.pathname === '/bot/ping') {
      return new Response(JSON.stringify({ ok: true, timestamp: new Date().toISOString() }), {
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      });
    }

    // Bot ステータス（認証不要・Discord API 使用）
    if (url.pathname === '/bot/status') {
      const start = Date.now();
      let isOnline = false;
      let latency = 0;
      try {
        const dcResp = await fetch('https://discord.com/api/v10/users/@me', {
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
        });
        latency = Date.now() - start;
        isOnline = dcResp.ok;
      } catch {
        isOnline = false;
      }
      return new Response(JSON.stringify({ isOnline, latency, uptime: 0, activeGuilds: 0, totalCommands: 0, timestamp: new Date().toISOString() }), {
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      });
    }

    // ── Discord スラッシュコマンド インタラクション ────────────────
    if (url.pathname === '/discord/interactions' && request.method === 'POST') {
      const signature  = request.headers.get('x-signature-ed25519') ?? '';
      const timestamp  = request.headers.get('x-signature-timestamp') ?? '';
      const body       = await request.text();

      // Ed25519 署名検証
      const isValid = await verifyDiscordSignature(env.DISCORD_PUBLIC_KEY, signature, timestamp, body);
      if (!isValid) {
        return new Response('invalid request signature', { status: 401 });
      }

      const interaction = JSON.parse(body) as { type: number; data?: { name?: string } };

      // type=1: Discord の疎通確認（PING）
      if (interaction.type === 1) {
        return jsonResponse({ type: 1 });
      }

      // type=2: スラッシュコマンド
      if (interaction.type === 2) {
        const commandName = (interaction as any).data?.name ?? '';
        if (commandName === 'ping') {
          return jsonResponse({ type: 4, data: { content: '🏓 Pong! Bot is online.' } });
        }
        return jsonResponse({ type: 4, data: { content: '未対応のコマンドです。' } });
      }

      // type=3: ボタン / セレクトメニュー (MESSAGE_COMPONENT)
      if (interaction.type === 3) {
        const ix = interaction as any;
        const customId: string = ix.data?.custom_id ?? '';
        const userId: string   = ix.member?.user?.id ?? ix.user?.id ?? '';
        const guildId: string  = ix.guild_id ?? '';

        // ── 個人招待リンク取得ボタン personal_invite:{guildId} ──────────
        const personalInviteMatch = customId.match(/^personal_invite:(.+)$/);
        if (personalInviteMatch) {
          const gId = personalInviteMatch[1];
          const username    = ix.member?.user?.username    ?? ix.user?.username    ?? userId;
          const displayName = ix.member?.nick ?? ix.member?.user?.global_name ?? ix.member?.user?.username ?? username;

          // 既存の個人リンクを確認
          const existingResp = await sb(`/personal_invites?guild_id=eq.${gId}&user_id=eq.${userId}`);
          const existing: any[] = existingResp.ok ? await existingResp.json() : [];

          let inviteCode: string;
          let inviteUrl: string;

          if (existing.length > 0) {
            // 既存リンクを再表示
            inviteCode = existing[0].invite_code;
            inviteUrl  = existing[0].invite_url;
          } else {
            // 新しいDiscord招待リンクを作成（最初のパネルのチャンネルIDを使用）
            const panelsResp = await sb(`/invite_panels?guild_id=eq.${gId}&limit=1`);
            const panelRows: any[] = panelsResp.ok ? await panelsResp.json() : [];
            const targetChannelId = panelRows.length > 0 ? panelRows[0].channel_id : '';

            if (!targetChannelId) {
              return jsonResponse({ type: 4, data: { content: '❌ 招待パネルの設定が見つかりません。', flags: 64 } });
            }

            // Discord Invite API: unique=true で必ず新しいコードを発行
            const inviteResp = await fetch(`https://discord.com/api/v10/channels/${targetChannelId}/invites`, {
              method: 'POST',
              headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
              body: JSON.stringify({ max_age: 0, max_uses: 0, unique: true }),
            });

            if (!inviteResp.ok) {
              return jsonResponse({ type: 4, data: { content: '❌ 招待リンクの作成に失敗しました。', flags: 64 } });
            }
            const invite = await inviteResp.json() as { code: string };
            inviteCode = invite.code;
            inviteUrl  = `https://discord.gg/${inviteCode}`;

            // DBに保存
            await sb('/personal_invites', {
              method: 'POST',
              headers: { Prefer: 'return=representation' },
              body: JSON.stringify({
                guild_id: gId, user_id: userId, username, display_name: displayName,
                invite_code: inviteCode, invite_url: inviteUrl, channel_id: targetChannelId,
              }),
            });

            // DMでも送信（失敗しても無視）
            try {
              const dmChResp = await fetch('https://discord.com/api/v10/users/@me/channels', {
                method: 'POST',
                headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
                body: JSON.stringify({ recipient_id: userId }),
              });
              if (dmChResp.ok) {
                const dmCh = await dmChResp.json() as { id: string };
                await fetch(`https://discord.com/api/v10/channels/${dmCh.id}/messages`, {
                  method: 'POST',
                  headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
                  body: JSON.stringify({
                    content: `🔗 **あなた専用の招待リンクを発行しました！**\n\n${inviteUrl}\n\nこのリンクを使って友達をサーバーに招待してください。このリンクはあなただけのものです。`,
                  }),
                });
              }
            } catch (_) { /* DM送信失敗は無視 */ }
          }

          const isNew = existing.length === 0;
          const message = isNew
            ? `✅ **あなた専用の招待リンクを発行しました！**\n\n${inviteUrl}\n\n※ このメッセージはあなたにだけ表示されています。`
            : `🔗 **あなたの招待リンクはこちらです**\n\n${inviteUrl}\n\n※ このメッセージはあなたにだけ表示されています。`;

          return jsonResponse({ type: 4, data: { content: message, flags: 64 } });
        }

        // ── チケット開設ボタン ticket_open_{panelId} ──────────────────
        const ticketOpenMatch = customId.match(/^ticket_open_(.+)$/);
        if (ticketOpenMatch) {
          const panelId = ticketOpenMatch[1];

          // パネル情報を取得
          const panelResp = await sb(`/ticket_panels?id=eq.${panelId}`);
          const panels: TicketPanelRow[] = panelResp.ok ? await panelResp.json() : [];
          if (!panels.length) {
            return jsonResponse({ type: 4, data: { content: '❌ パネルが見つかりません。', flags: 64 } });
          }
          const panel = panels[0];
          const maxOpen = panel.max_open_per_user ?? 1;

          // このパネルに対してユーザーがすでに開いているチケット数をチェック
          const openResp = await sb(
            `/tickets?guild_id=eq.${guildId}&opened_by_user_id=eq.${userId}&panel_id=eq.${panelId}&status=eq.open`
          );
          const openTickets: TicketRow[] = openResp.ok ? await openResp.json() : [];

          if (openTickets.length >= maxOpen) {
            const existingChannelId = openTickets[0]?.channel_id ?? '';
            const channelRef = existingChannelId ? ` (<#${existingChannelId}>)` : '';
            return jsonResponse({
              type: 4,
              data: {
                content: `⚠️ すでにこのパネルでオープン中のチケットがあります${channelRef}。\nチケットが解決したら閉じてから新しく開いてください。`,
                flags: 64,  // ephemeral
              },
            });
          }

          // Discord にチケットチャンネルを作成
          const suffix      = Date.now().toString().slice(-4);
          const channelName = `ticket-${userId.slice(-4)}-${suffix}`;

          // パネルのカテゴリに作成（設定されている場合）
          const chBody: Record<string, unknown> = { name: channelName, type: 0 };
          if (panel.open_category_id) chBody.parent_id = panel.open_category_id;

          const chResp = await fetch(`https://discord.com/api/v10/guilds/${guildId}/channels`, {
            method:  'POST',
            headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
            body:    JSON.stringify(chBody),
          });
          if (!chResp.ok) {
            console.error('[Ticket] channel create failed:', await chResp.text());
            return jsonResponse({ type: 4, data: { content: '❌ チケットチャンネルの作成に失敗しました。', flags: 64 } });
          }
          const channel = await chResp.json() as { id: string };
          const channelId = channel.id;

          // チャンネルのユーザー権限を付与（ViewChannel + SendMessages）
          await fetch(`https://discord.com/api/v10/channels/${channelId}/permissions/${userId}`, {
            method:  'PUT',
            headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
            body:    JSON.stringify({ allow: '68608', deny: '0', type: 1 }),
          });

          // サポートロールが設定されている場合はアクセス権付与
          if (panel.support_role_id) {
            await fetch(`https://discord.com/api/v10/channels/${channelId}/permissions/${panel.support_role_id}`, {
              method:  'PUT',
              headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
              body:    JSON.stringify({ allow: '68608', deny: '0', type: 0 }),
            });
          }

          // Supabase にチケットを記録（panel_id を保存）
          const subject = panel.title;
          const sbRes = await sb('/tickets', {
            method:  'POST',
            body:    JSON.stringify({
              guild_id:          guildId,
              channel_id:        channelId,
              opened_by_user_id: userId,
              panel_id:          panelId,
              subject:           subject,
            }),
            headers: { Prefer: 'return=representation' },
          });
          if (!sbRes.ok) {
            console.error('[Ticket] DB insert failed:', await sbRes.text());
          }
          const ticketRows: TicketRow[] = sbRes.ok ? await sbRes.json() : [];
          const ticketId = ticketRows[0]?.id ?? '';

          // チケットチャンネルに開設メッセージを投稿
          const embedTitle   = panel.ticket_embed_title || `チケット: ${subject}`;
          const embedColor   = panel.ticket_embed_color ?? panel.color;
          const msgContent   = panel.ticket_msg_content ?? `<@${userId}> チケットが作成されました。担当者が対応するまでお待ちください。`;
          const closeBtn     = { type: 2, style: 4, label: '🔒 閉じる', custom_id: `ticket_close_${ticketId}` };

          await fetch(`https://discord.com/api/v10/channels/${channelId}/messages`, {
            method:  'POST',
            headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
            body:    JSON.stringify({
              content: msgContent,
              embeds:  [{ title: embedTitle, color: embedColor }],
              components: [{ type: 1, components: [closeBtn] }],
            }),
          });

          // エフェメラル返答
          return jsonResponse({
            type: 4,
            data: {
              content: `✅ チケットを開設しました: <#${channelId}>`,
              flags:   64,
            },
          });
        }

        // ── チケットクローズボタン ticket_close_{ticketId} ──────────────
        const ticketCloseMatch = customId.match(/^ticket_close_(.+)$/);
        if (ticketCloseMatch) {
          const ticketId = ticketCloseMatch[1];
          await sb(`/tickets?id=eq.${ticketId}`, {
            method: 'PATCH',
            body:   JSON.stringify({ status: 'closed', closed_at: new Date().toISOString() }),
          });
          // チャンネルにクローズ通知
          const channelId = ix.channel_id ?? '';
          if (channelId) {
            await fetch(`https://discord.com/api/v10/channels/${channelId}/messages`, {
              method:  'POST',
              headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
              body:    JSON.stringify({ content: '🔒 このチケットはクローズされました。' }),
            });
          }
          return jsonResponse({ type: 4, data: { content: '✅ チケットをクローズしました。', flags: 64 } });
        }

        // ── ショップ商品選択セレクトメニュー shop_select_{shopId} ──
        const shopSelectMatch = customId.match(/^shop_select_(.+)$/);
        if (shopSelectMatch) {
          const shopId = shopSelectMatch[1];
          const values: string[] = ix.data?.values ?? [];
          const productId = values[0] ?? '';

          if (!productId) {
            return jsonResponse({ type: 4, data: { content: '❌ 商品が選択されていません。', flags: 64 } });
          }

          const [shopResp, productResp] = await Promise.all([
            supabaseFetch(`/shops?id=eq.${shopId}`),
            supabaseFetch(`/products?id=eq.${productId}`),
          ]);
          const shops: ShopRow[] = shopResp.ok ? await shopResp.json() : [];
          const products: ProductRow[] = productResp.ok ? await productResp.json() : [];

          if (!products.length) {
            return jsonResponse({ type: 4, data: { content: '❌ 商品が見つかりません。', flags: 64 } });
          }

          const product = products[0];

          // 商品が無効
          if (!product.enabled) {
            return jsonResponse({ type: 4, data: { content: '⚠️ 現在この商品は購入不可能です。', flags: 64 } });
          }

          // 在庫切れ
          if (product.stock !== null && product.stock <= 0) {
            return jsonResponse({ type: 4, data: { content: '⚠️ この商品は売り切れです。', flags: 64 } });
          }

          // ショップが無効
          if (shops.length > 0 && !shops[0].enabled) {
            const disabledMsg = shops[0].disabled_message ?? 'この自販機は現在ご利用いただけません。';
            return jsonResponse({ type: 4, data: { content: `⚠️ ${disabledMsg}`, flags: 64 } });
          }

          const shop = shops[0];
          const paymentLabel = (shop?.payment_input_label ?? 'PayPayの受け取りURLを入力してください').slice(0, 45);

          // 支払いモーダルを表示
          return jsonResponse({
            type: 9,
            data: {
              custom_id: `shop_pay_modal_${shopId}_${productId}`,
              title: product.name.slice(0, 45),
              components: [{
                type: 1,
                components: [{
                  type: 4,
                  custom_id: 'payment_info',
                  label: paymentLabel,
                  style: 1,
                  placeholder: '入力してください',
                  required: true,
                  max_length: 500,
                }],
              }],
            },
          });
        }

        return jsonResponse({ type: 4, data: { content: '未対応のインタラクションです。', flags: 64 } });
      }

      // type=5: モーダル送信
      if (interaction.type === 5) {
        const ix = interaction as any;
        const customId: string = ix.data?.custom_id ?? '';
        const userId: string   = ix.member?.user?.id ?? ix.user?.id ?? '';
        const username: string = ix.member?.user?.username ?? ix.user?.username ?? 'Unknown';
        const guildId: string  = ix.guild_id ?? '';

        // ── ショップ支払いモーダル shop_pay_modal_{shopId}_{productId} ──
        const shopPayModalMatch = customId.match(/^shop_pay_modal_([^_]+(?:_[^_]+)*)_([^_]+)$/);
        if (shopPayModalMatch) {
          const productId = shopPayModalMatch[2];
          const shopId    = shopPayModalMatch[1];
          const components: any[] = ix.data?.components ?? [];
          const paymentInfo = components.flatMap((row: any) => row.components ?? [])
            .find((c: any) => c.custom_id === 'payment_info')?.value ?? '';

          const [shopResp, productResp] = await Promise.all([
            supabaseFetch(`/shops?id=eq.${shopId}`),
            supabaseFetch(`/products?id=eq.${productId}`),
          ]);
          const shops: ShopRow[] = shopResp.ok ? await shopResp.json() : [];
          const products: ProductRow[] = productResp.ok ? await productResp.json() : [];

          if (!products.length || !shops.length) {
            return jsonResponse({ type: 4, data: { content: '❌ 商品またはショップが見つかりません。', flags: 64 } });
          }
          const product = products[0];
          const shop = shops[0];

          if (!product.enabled) {
            return jsonResponse({ type: 4, data: { content: '⚠️ 現在この商品は購入不可能です。', flags: 64 } });
          }
          if (product.stock !== null && product.stock <= 0) {
            return jsonResponse({ type: 4, data: { content: '⚠️ この商品は売り切れです。', flags: 64 } });
          }

          // 注文チャンネルを作成
          const suffix = Date.now().toString().slice(-4);
          const chBody: Record<string, unknown> = { name: `order-${userId.slice(-4)}-${suffix}`, type: 0 };
          if (shop.order_category_id) chBody.parent_id = shop.order_category_id;

          const chResp = await fetch(`https://discord.com/api/v10/guilds/${guildId}/channels`, {
            method:  'POST',
            headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
            body:    JSON.stringify(chBody),
          });
          if (!chResp.ok) {
            return jsonResponse({ type: 4, data: { content: '❌ 注文チャンネルの作成に失敗しました。', flags: 64 } });
          }
          const channel = await chResp.json() as { id: string };
          const channelId = channel.id;

          // 購入者の閲覧権限を付与
          await fetch(`https://discord.com/api/v10/channels/${channelId}/permissions/${userId}`, {
            method:  'PUT',
            headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
            body:    JSON.stringify({ allow: '68608', deny: '0', type: 1 }),
          });
          if (shop.support_role_id) {
            await fetch(`https://discord.com/api/v10/channels/${channelId}/permissions/${shop.support_role_id}`, {
              method:  'PUT',
              headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
              body:    JSON.stringify({ allow: '68608', deny: '0', type: 0 }),
            });
          }

          // 注文をDBに作成
          const orderData = {
            shop_id: shopId, product_id: productId, guild_id: guildId,
            channel_id: channelId, buyer_user_id: userId, buyer_username: username,
            product_name: product.name, product_price_display: product.price_display,
            status: 'open', payment_url: paymentInfo || null,
            payment_submitted_at: paymentInfo ? new Date().toISOString() : null,
          };
          const orderResp = await supabaseFetch('/orders', {
            method: 'POST',
            body: JSON.stringify(orderData),
            headers: { Prefer: 'return=representation' },
          });
          const orderRows: OrderRow[] = orderResp.ok ? await orderResp.json() : [];
          const orderId = orderRows[0]?.id ?? '';

          // ウェルカムメッセージを送信
          const welcomeDesc = shop.welcome_footer_text ?? '支払いが確認できるまでお待ちください。確認でき次第、商品をお渡しします。';
          const welcomeEmbed = {
            title: product.name,
            description: welcomeDesc,
            color: shop.color,
            fields: [
              { name: '商品', value: product.name, inline: true },
              { name: '価格', value: product.price_display, inline: true },
              ...(paymentInfo ? [{ name: '支払い情報', value: paymentInfo, inline: false }] : []),
            ],
            timestamp: new Date().toISOString(),
          };

          await fetch(`https://discord.com/api/v10/channels/${channelId}/messages`, {
            method:  'POST',
            headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
            body:    JSON.stringify({
              content: `<@${userId}> ご注文ありがとうございます！`,
              embeds: [welcomeEmbed],
            }),
          });

          // 在庫を1減らす
          if (product.stock !== null) {
            await supabaseFetch(`/products?id=eq.${productId}`, {
              method: 'PATCH',
              body: JSON.stringify({ stock: product.stock - 1 }),
            });
          }

          return jsonResponse({ type: 4, data: { content: `✅ 注文が完了しました！ <#${channelId}> をご確認ください。`, flags: 64 } });
        }

        return jsonResponse({ type: 4, data: { content: '未対応のモーダルです。', flags: 64 } });
      }

      return jsonResponse({ type: 1 });
    }

    // ── 認証ページ（Cloudflare Turnstile）──────────────────────
    // GET /verify/{panelId}?u={userId}&g={guildId}&exp={expiry}&sig={hmac}
    const verifyPageMatch = url.pathname.match(/^\/verify\/([^/]+)$/);
    if (verifyPageMatch) {
      if (request.method !== 'GET') {
        return jsonResponse({ error: 'Method not allowed' }, 405);
      }
      const panelId = verifyPageMatch[1];
      const u   = url.searchParams.get('u')   ?? '';
      const g   = url.searchParams.get('g')   ?? '';
      const exp = url.searchParams.get('exp') ?? '';
      const sig = url.searchParams.get('sig') ?? '';

      // URL パラメータの基本チェック
      if (!u || !g || !exp || !sig) {
        return verifyErrorPage('無効なURLです。Discordのボタンをもう一度押してください。');
      }

      // 有効期限チェック（署名検証より先に行う）
      if (Date.now() > parseInt(exp, 10)) {
        return verifyErrorPage('このURLは有効期限が切れています。Discordのボタンをもう一度押してください。');
      }

      // HMAC署名検証
      const validSig = await hmacSign(`${panelId}:${u}:${g}:${exp}`, env.WORKER_API_SECRET);
      if (validSig !== sig) {
        return verifyErrorPage('無効なURLです。Discordのボタンをもう一度押してください。');
      }

      // パネル情報を取得
      const sbLocal = makeSupabaseFetch(env);
      const panelResp = await sbLocal(`/verify_panels?id=eq.${panelId}`);
      const panels: VerifyPanelRow[] = panelResp.ok ? await panelResp.json() : [];
      if (!panels.length || !panels[0].enabled) {
        return verifyErrorPage('この認証パネルは現在利用できません。');
      }
      const panel = panels[0];
      const siteKey = (env as any).TURNSTILE_SITE_KEY ?? '';

      return new Response(verifyHtml(panelId, u, g, exp, sig, panel.name, panel.color, siteKey), {
        headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' },
      });
    }

    // POST /verify/{panelId}/complete — Turnstile トークン検証 + ロール付与
    const verifyCompleteMatch = url.pathname.match(/^\/verify\/([^/]+)\/complete$/);
    if (verifyCompleteMatch && request.method === 'POST') {
      const panelId = verifyCompleteMatch[1];
      const body = await request.json() as {
        u: string; g: string; exp: string; sig: string; token: string;
      };
      const { u, g, exp, sig, token } = body;

      if (!u || !g || !exp || !sig || !token) {
        return jsonResponse({ error: 'パラメータが不足しています' }, 400);
      }
      if (Date.now() > parseInt(exp, 10)) {
        return jsonResponse({ error: 'URLの有効期限が切れています' }, 400);
      }

      // 署名検証
      const validSig = await hmacSign(`${panelId}:${u}:${g}:${exp}`, env.WORKER_API_SECRET);
      if (validSig !== sig) {
        return jsonResponse({ error: '無効なリクエストです' }, 403);
      }

      // Turnstile トークン検証
      const secretKey = (env as any).TURNSTILE_SECRET_KEY ?? '';
      if (secretKey) {
        const verifyResp = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ secret: secretKey, response: token }),
        });
        const result = await verifyResp.json() as { success: boolean };
        if (!result.success) {
          return jsonResponse({ error: '認証に失敗しました。もう一度お試しください。' }, 400);
        }
      }

      // パネル取得
      const sbLocal2 = makeSupabaseFetch(env);
      const panelResp = await sbLocal2(`/verify_panels?id=eq.${panelId}`);
      const panels: VerifyPanelRow[] = panelResp.ok ? await panelResp.json() : [];
      if (!panels.length || !panels[0].role_id) {
        return jsonResponse({ error: '認証パネルが見つかりません' }, 404);
      }
      const panel = panels[0];

      // Discord ロール付与
      const roleResp = await fetch(
        `https://discord.com/api/v10/guilds/${g}/members/${u}/roles/${panel.role_id}`,
        { method: 'PUT', headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` } }
      );
      if (!roleResp.ok && roleResp.status !== 204) {
        const errText = await roleResp.text();
        console.error('[Verify] ロール付与失敗:', roleResp.status, errText);
        return jsonResponse({ error: 'ロールの付与に失敗しました' }, 502);
      }

      return jsonResponse({ ok: true });
    }

    // ── API 認証 ─────────────────────────────────────────────
    // 優先度: (1) Supabase JWT署名検証  (2) Bearer存在確認  (3) X-Bot-Secretレガシー
    const authHeader = request.headers.get('Authorization') ?? '';
    const legacySecret = request.headers.get('X-Bot-Secret') ?? '';
    const hasBearerToken = authHeader.startsWith('Bearer ') && authHeader.length > 7;

    if (hasBearerToken) {
      // Bearer トークンあり → ES256（JWKS）で署名検証
      const bearerJwt = authHeader.slice(7);
      const jwtValid = await verifySupabaseJwtLocal(bearerJwt, '', env.SUPABASE_URL);
      if (!jwtValid) {
        // レガシー X-Bot-Secret フォールバック（移行期間用）
        if (!env.WORKER_API_SECRET || legacySecret !== env.WORKER_API_SECRET) {
          return new Response(JSON.stringify({ error: 'Unauthorized: invalid JWT' }), {
            status: 401,
            headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
          });
        }
      }
    } else if (env.WORKER_API_SECRET) {
      // Bearer なし → レガシー X-Bot-Secret で認証
      if (legacySecret !== env.WORKER_API_SECRET) {
        return new Response(JSON.stringify({ error: 'Unauthorized' }), {
          status: 401,
          headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
        });
      }
    } else {
      // 認証手段が何もない → 拒否
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      });
    }

    const sb = makeSupabaseFetch(env);

    // ── 認証パネル CRUD ──────────────────────────────────────────

    // GET /bot/verify-panels?guild_id=xxx
    if (url.pathname === '/bot/verify-panels' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id') ?? '';
      const r = await sb(`/verify_panels?guild_id=eq.${guildId}&order=created_at.desc`);
      const rows: VerifyPanelRow[] = r.ok ? await r.json() : [];
      return jsonResponse(rows.map(mapVerifyPanel));
    }

    // POST /bot/verify-panels
    if (url.pathname === '/bot/verify-panels' && request.method === 'POST') {
      try {
        const b = await request.json() as Record<string, unknown>;
        const data = {
          guild_id: b['guildId'] ?? '', name: b['name'] ?? '認証',
          description: b['description'] ?? '', channel_id: b['channelId'] ?? '',
          role_id: b['roleId'] ?? '', color: b['color'] ?? 1095937,
          footer_text: b['footerText'] ?? '', button_label: b['buttonLabel'] ?? '✅ 認証する',
          enabled: b['enabled'] ?? true,
          verify_type: b['verifyType'] ?? 'captcha',
          reaction_emoji: b['reactionEmoji'] ?? '✅',
          manual_channel_id: b['manualChannelId'] ?? null,
        };
        const r = await sb('/verify_panels', { method: 'POST', body: JSON.stringify(data), headers: { Prefer: 'return=representation' } });
        if (!r.ok) return new Response(await r.text(), { status: r.status });
        const rows: VerifyPanelRow[] = await r.json();
        return jsonResponse(mapVerifyPanel(rows[0]));
      } catch (e) { return jsonResponse({ error: String(e) }, 500); }
    }

    // PATCH /bot/verify-panels/:id
    const verifyPatchMatch = url.pathname.match(/^\/bot\/verify-panels\/([^/]+)$/);
    if (verifyPatchMatch && request.method === 'PATCH') {
      const id = verifyPatchMatch[1];
      try {
        const b = await request.json() as Record<string, unknown>;
        const camel: Record<string, string> = {
          name: 'name', description: 'description', channelId: 'channel_id',
          roleId: 'role_id', color: 'color', footerText: 'footer_text',
          buttonLabel: 'button_label', enabled: 'enabled',
          verifyType: 'verify_type', reactionEmoji: 'reaction_emoji',
          manualChannelId: 'manual_channel_id',
        };
        const data: Record<string, unknown> = {};
        for (const [k, v] of Object.entries(b)) { data[camel[k] ?? k] = v; }
        const r = await sb(`/verify_panels?id=eq.${id}`, { method: 'PATCH', body: JSON.stringify(data), headers: { Prefer: 'return=representation' } });
        if (!r.ok) return new Response(await r.text(), { status: r.status });
        const rows: VerifyPanelRow[] = await r.json();
        return jsonResponse(mapVerifyPanel(rows[0]));
      } catch (e) { return jsonResponse({ error: String(e) }, 500); }
    }

    // DELETE /bot/verify-panels/:id
    if (verifyPatchMatch && request.method === 'DELETE') {
      const id = verifyPatchMatch[1];
      await sb(`/verify_panels?id=eq.${id}`, { method: 'DELETE' });
      return jsonResponse({ ok: true });
    }

    // POST /bot/verify-panels/:id/deploy  body: { channelId }
    const verifyDeployMatch = url.pathname.match(/^\/bot\/verify-panels\/([^/]+)\/deploy$/);
    if (verifyDeployMatch && request.method === 'POST') {
      const id = verifyDeployMatch[1];
      try {
        const b = await request.json() as { channelId: string };
        if (!b.channelId) return jsonResponse({ error: 'channelId required' }, 400);

        const panelResp = await sb(`/verify_panels?id=eq.${id}`);
        const panels: VerifyPanelRow[] = panelResp.ok ? await panelResp.json() : [];
        if (!panels.length) return jsonResponse({ error: 'Panel not found' }, 404);
        const panel = panels[0];

        // Discord にパネルメッセージを投稿
        const discordBody = {
          embeds: [{
            title: panel.name,
            description: panel.description,
            color: panel.color,
            footer: panel.footer_text ? { text: panel.footer_text } : undefined,
          }],
          components: [{
            type: 1,
            components: [{
              type: 2, style: 3,
              label: panel.button_label,
              custom_id: `verify_start_${id}`,
            }],
          }],
        };

        const postR = await fetch(`https://discord.com/api/v10/channels/${b.channelId}/messages`, {
          method: 'POST', headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify(discordBody),
        });
        if (!postR.ok) {
          const errText = await postR.text();
          return jsonResponse({ error: errText }, 502);
        }
        const posted = await postR.json() as { id: string };

        const updR = await sb(`/verify_panels?id=eq.${id}`, {
          method: 'PATCH',
          body: JSON.stringify({ channel_id: b.channelId, message_id: posted.id }),
          headers: { Prefer: 'return=representation' },
        });
        const updRows: VerifyPanelRow[] = await updR.json();
        return jsonResponse(mapVerifyPanel(updRows[0]));
      } catch (e) { return jsonResponse({ error: String(e) }, 500); }
    }

    // ── 手動認証リクエスト ────────────────────────────────────────

    // GET /bot/verify-requests?guild_id=xxx[&status=pending]
    if (url.pathname === '/bot/verify-requests' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id') ?? '';
      const status  = url.searchParams.get('status');
      let query = `/verify_requests?guild_id=eq.${guildId}&order=created_at.desc`;
      if (status) query += `&status=eq.${status}`;
      const r = await sb(query);
      const rows: VerifyRequestRow[] = r.ok ? await r.json() : [];
      return jsonResponse(rows.map(mapVerifyRequest));
    }

    // POST /bot/verify-requests/:id/approve
    const verifyApproveMatch = url.pathname.match(/^\/bot\/verify-requests\/([^/]+)\/approve$/);
    if (verifyApproveMatch && request.method === 'POST') {
      const reqId = verifyApproveMatch[1];
      try {
        const reqResp = await sb(`/verify_requests?id=eq.${reqId}`);
        const reqs: VerifyRequestRow[] = reqResp.ok ? await reqResp.json() : [];
        if (!reqs.length) return jsonResponse({ error: 'Not found' }, 404);
        const req = reqs[0];

        // パネルからロールIDを取得
        const panelResp = await sb(`/verify_panels?id=eq.${req.panel_id}`);
        const panels: VerifyPanelRow[] = panelResp.ok ? await panelResp.json() : [];
        if (!panels.length) return jsonResponse({ error: 'Panel not found' }, 404);
        const panel = panels[0];

        // ロール付与
        await fetch(`https://discord.com/api/v10/guilds/${req.guild_id}/members/${req.user_id}/roles/${panel.role_id}`, {
          method: 'PUT', headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
        });

        // ステータス更新
        await sb(`/verify_requests?id=eq.${reqId}`, {
          method: 'PATCH', body: JSON.stringify({ status: 'approved', resolved_at: new Date().toISOString() }),
        });

        // ユーザーにDM通知
        const dmCh = await fetch('https://discord.com/api/v10/users/@me/channels', {
          method: 'POST', headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ recipient_id: req.user_id }),
        });
        if (dmCh.ok) {
          const { id: dmId } = await dmCh.json() as { id: string };
          await fetch(`https://discord.com/api/v10/channels/${dmId}/messages`, {
            method: 'POST', headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({ content: '✅ **認証が承認されました！** ロールが付与されました。' }),
          });
        }

        return jsonResponse({ ...mapVerifyRequest(req), status: 'approved' });
      } catch (e) { return jsonResponse({ error: String(e) }, 500); }
    }

    // POST /bot/verify-requests/:id/deny
    const verifyDenyMatch = url.pathname.match(/^\/bot\/verify-requests\/([^/]+)\/deny$/);
    if (verifyDenyMatch && request.method === 'POST') {
      const reqId = verifyDenyMatch[1];
      try {
        const reqResp = await sb(`/verify_requests?id=eq.${reqId}`);
        const reqs: VerifyRequestRow[] = reqResp.ok ? await reqResp.json() : [];
        if (!reqs.length) return jsonResponse({ error: 'Not found' }, 404);
        const req = reqs[0];

        await sb(`/verify_requests?id=eq.${reqId}`, {
          method: 'PATCH', body: JSON.stringify({ status: 'denied', resolved_at: new Date().toISOString() }),
        });

        // ユーザーにDM通知
        const dmCh = await fetch('https://discord.com/api/v10/users/@me/channels', {
          method: 'POST', headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ recipient_id: req.user_id }),
        });
        if (dmCh.ok) {
          const { id: dmId } = await dmCh.json() as { id: string };
          await fetch(`https://discord.com/api/v10/channels/${dmId}/messages`, {
            method: 'POST', headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({ content: '❌ **認証が拒否されました。** サーバーの管理者にお問い合わせください。' }),
          });
        }

        return jsonResponse({ ...mapVerifyRequest(req), status: 'denied' });
      } catch (e) { return jsonResponse({ error: String(e) }, 500); }
    }

    // Botが参加しているサーバー一覧
    if (url.pathname === "/bot/guilds") {
      const resp = await fetch("https://discord.com/api/v10/users/@me/guilds", {
        headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
      });
      const guilds: Array<{ id: string; name: string; icon: string | null; owner: boolean }> = await resp.json();

      // Supabase guilds テーブルに UPSERT（存在しないサーバーは自動追加）
      try {
        await Promise.all(guilds.map(async (g) => {
          const iconUrl = g.icon ? `https://cdn.discordapp.com/icons/${g.id}/${g.icon}.png` : null;
          await sb(`/guilds?on_conflict=id`, {
            method: 'POST',
            headers: {
              'Prefer': 'resolution=merge-duplicates,return=representation',
            },
            body: JSON.stringify({
              id: g.id,
              discord_id: g.id,
              name: g.name,
              icon_url: iconUrl,
              member_count: 0,
              user_role: '',
              category: '',
            }),
          });
        }));
      } catch (e) {
        console.error('[Worker] Failed to sync guilds to Supabase:', e);
      }

      return new Response(JSON.stringify(guilds), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Botから見えるチャンネル一覧
    if (url.pathname === "/bot/channels") {
      const guildId = url.searchParams.get("guild_id");
      if (!guildId) return new Response("Missing guild_id", { status: 400 });
      const resp = await fetch(`https://discord.com/api/v10/guilds/${guildId}/channels`, {
        headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
      });
      const channels = await resp.json();
      return new Response(JSON.stringify(channels), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Botから見えるロール一覧
    if (url.pathname === "/bot/roles") {
      const guildId = url.searchParams.get("guild_id");
      if (!guildId) return new Response("Missing guild_id", { status: 400 });
      const resp = await fetch(`https://discord.com/api/v10/guilds/${guildId}/roles`, {
        headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
      });
      const roles = await resp.json();
      return new Response(JSON.stringify(roles), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // ロール新規作成 POST /bot/roles/create
    if (url.pathname === '/bot/roles/create' && request.method === 'POST') {
      try {
        const b = await request.json() as {
          guildId: string; name: string; color?: number;
          channelPermissions?: Array<{ channelId: string; allow: string; deny: string }>;
        };
        if (!b.guildId || !b.name) return jsonResponse({ error: 'guildId and name are required' }, 400);

        // ロール作成
        const roleResp = await fetch(`https://discord.com/api/v10/guilds/${b.guildId}/roles`, {
          method: 'POST',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ name: b.name, color: b.color ?? 0, hoist: false, mentionable: false }),
        });
        if (!roleResp.ok) {
          const err = await roleResp.text();
          return jsonResponse({ error: `ロール作成失敗: ${err}` }, roleResp.status);
        }
        const role = await roleResp.json() as { id: string; name: string; color: number };

        // チャンネル権限オーバーライド設定
        if (b.channelPermissions?.length) {
          await Promise.all(b.channelPermissions.map(async (cp) => {
            if (cp.allow === '0' && cp.deny === '0') return;
            await fetch(`https://discord.com/api/v10/channels/${cp.channelId}/permissions/${role.id}`, {
              method: 'PUT',
              headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
              body: JSON.stringify({ allow: cp.allow, deny: cp.deny, type: 0 }),
            });
          }));
        }

        return jsonResponse({ id: role.id, name: role.name, color: role.color });
      } catch (e) { return jsonResponse({ error: String(e) }, 500); }
    }

    // ── メンバー管理 ────────────────────────────────────────────

    // メンバー一覧取得
    if (url.pathname === "/bot/members" && request.method === "GET") {
      const guildId = url.searchParams.get("guild_id");
      if (!guildId) return new Response("Missing guild_id", { status: 400 });

      const [membersResp, rolesResp] = await Promise.all([
        fetch(`https://discord.com/api/v10/guilds/${guildId}/members?limit=1000`, {
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
        }),
        fetch(`https://discord.com/api/v10/guilds/${guildId}/roles`, {
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
        }),
      ]);

      if (!membersResp.ok) {
        const err = await membersResp.text();
        return new Response(JSON.stringify({ error: err }), { status: membersResp.status });
      }

      const discordMembers = await membersResp.json() as any[];
      const discordRoles   = rolesResp.ok ? await rolesResp.json() as any[] : [];
      const roleMap: Record<string, string> = Object.fromEntries(
        discordRoles.map((r: any) => [r.id, r.name])
      );

      const members = discordMembers
        .filter((m: any) => !m.user?.bot)
        .map((m: any) => {
          const user = m.user;
          const userId = user.id;
          // Snowflake -> createdAt (Discord epoch: 1420070400000)
          const createdTimestamp = ((BigInt(userId) >> 22n) + 1420070400000n);
          const createdAt = new Date(Number(createdTimestamp)).toISOString();
          return {
            id:          userId,
            guildId,
            username:    user.username,
            displayName: m.nick ?? user.global_name ?? user.username,
            discriminator: user.discriminator ?? '0',
            globalName:  user.global_name ?? null,
            nick:        m.nick ?? null,
            avatarUrl:   user.avatar
              ? `https://cdn.discordapp.com/avatars/${userId}/${user.avatar}.png`
              : null,
            bannerUrl:   user.banner
              ? `https://cdn.discordapp.com/banners/${userId}/${user.banner}.png`
              : null,
            accentColor: user.accent_color ?? null,
            publicFlags: user.public_flags ?? 0,
            isBot:       !!user.bot,
            roles:       (m.roles as string[]).map(id => roleMap[id]).filter(Boolean),
            joinedAt:    m.joined_at,
            createdAt:   createdAt,
            isBoosting:  !!m.premium_since,
            boostSince:  m.premium_since ?? null,
            isDeaf:      !!m.deaf,
            isMute:      !!m.mute,
            flags:       m.flags ?? 0,
            communicationDisabledUntil: m.communication_disabled_until ?? null,
            status:      "offline",
          };
        });

      return new Response(JSON.stringify(members), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // メンバーキック
    if (url.pathname === "/bot/members/kick" && request.method === "POST") {
      try {
        const { memberId, guildId, reason } = await request.json() as { memberId: string; guildId: string; reason?: string };
        const resp = await fetch(
          `https://discord.com/api/v10/guilds/${guildId}/members/${memberId}`,
          {
            method: "DELETE",
            headers: {
              Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`,
              ...(reason ? { "X-Audit-Log-Reason": reason } : {}),
            },
          }
        );
        if (!resp.ok && resp.status !== 204) {
          return new Response(await resp.text(), { status: resp.status });
        }
        return new Response(JSON.stringify({ success: true }), { headers: { "Content-Type": "application/json" } });
      } catch (e) {
        return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
      }
    }

    // メンバーBAN
    if (url.pathname === "/bot/members/ban" && request.method === "POST") {
      try {
        const { memberId, guildId, reason } = await request.json() as { memberId: string; guildId: string; reason?: string };
        const resp = await fetch(
          `https://discord.com/api/v10/guilds/${guildId}/bans/${memberId}`,
          {
            method: "PUT",
            headers: {
              Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`,
              "Content-Type": "application/json",
              ...(reason ? { "X-Audit-Log-Reason": reason } : {}),
            },
            body: JSON.stringify({ delete_message_seconds: 0 }),
          }
        );
        if (!resp.ok && resp.status !== 204) {
          return new Response(await resp.text(), { status: resp.status });
        }
        return new Response(JSON.stringify({ success: true }), { headers: { "Content-Type": "application/json" } });
      } catch (e) {
        return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
      }
    }

    // メンバータイムアウト
    if (url.pathname === "/bot/members/timeout" && request.method === "POST") {
      try {
        const { memberId, guildId, until } = await request.json() as { memberId: string; guildId: string; until: string };
        const resp = await fetch(
          `https://discord.com/api/v10/guilds/${guildId}/members/${memberId}`,
          {
            method: "PATCH",
            headers: {
              Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ communication_disabled_until: until }),
          }
        );
        if (!resp.ok) {
          return new Response(await resp.text(), { status: resp.status });
        }
        return new Response(JSON.stringify({ success: true }), { headers: { "Content-Type": "application/json" } });
      } catch (e) {
        return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
      }
    }

    // DM送信
    if (url.pathname === "/bot/members/dm" && request.method === "POST") {
      try {
        const { memberId, message } = await request.json() as { memberId: string; message: string };
        // DMチャンネルを開く（Bot自身=@me のDMチャンネル一覧に対して recipient_id を指定）
        const resp = await fetch(`https://discord.com/api/v10/users/@me/channels`, {
          method: "POST",
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, "Content-Type": "application/json" },
          body: JSON.stringify({ recipient_id: memberId }),
        });
        if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
        const { id: channelId } = await resp.json() as { id: string };
        const msgResp = await fetch(`https://discord.com/api/v10/channels/${channelId}/messages`, {
          method: "POST",
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, "Content-Type": "application/json" },
          body: JSON.stringify({ content: message }),
        });
        if (!msgResp.ok) return new Response(await msgResp.text(), { status: msgResp.status });
        return new Response(JSON.stringify({ success: true }), { headers: { "Content-Type": "application/json" } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // ロール付与
    if (url.pathname === "/bot/members/role/add" && request.method === "POST") {
      try {
        const { memberId, guildId, roleId } = await request.json() as { memberId: string; guildId: string; roleId: string };
        const resp = await fetch(`https://discord.com/api/v10/guilds/${guildId}/members/${memberId}/roles/${roleId}`, {
          method: "PUT",
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
        });
        if (!resp.ok && resp.status !== 204) return new Response(await resp.text(), { status: resp.status });
        return new Response(JSON.stringify({ success: true }), { headers: { "Content-Type": "application/json" } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // ロール剥奪
    if (url.pathname === "/bot/members/role/remove" && request.method === "POST") {
      try {
        const { memberId, guildId, roleId } = await request.json() as { memberId: string; guildId: string; roleId: string };
        const resp = await fetch(`https://discord.com/api/v10/guilds/${guildId}/members/${memberId}/roles/${roleId}`, {
          method: "DELETE",
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
        });
        if (!resp.ok && resp.status !== 204) return new Response(await resp.text(), { status: resp.status });
        return new Response(JSON.stringify({ success: true }), { headers: { "Content-Type": "application/json" } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // ── チャンネルへメッセージ送信 ────────────────────────────────
    if (url.pathname === "/bot/send-message" && request.method === "POST") {
      try {
        const body = await request.json() as { guildId: string; channelId: string; content: string };
        const resp = await fetch(`https://discord.com/api/v10/channels/${body.channelId}/messages`, {
          method: "POST",
          headers: {
            Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ content: body.content }),
        });
        if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
        return new Response(JSON.stringify({ success: true }), { headers: { "Content-Type": "application/json" } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // ── チャンネルへEmbed付きメッセージ送信 ──────────────────────
    if (url.pathname === "/bot/send-embed" && request.method === "POST") {
      try {
        const body = await request.json() as { guildId: string; channelId: string; embed: any };
        const resp = await fetch(`https://discord.com/api/v10/channels/${body.channelId}/messages`, {
          method: "POST",
          headers: {
            Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ embeds: [body.embed] }),
        });
        if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
        return new Response(JSON.stringify({ success: true }), { headers: { "Content-Type": "application/json" } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // リアクションロールパネルをDiscordに送信
    if (url.pathname === "/bot/reaction-roles/publish" && request.method === "POST") {
      try {
        const body = await request.json() as {
          reactionRoleId: string;
          channelId: string;
          channelName: string;
          guildId: string;
        };

        // 1. Supabase からリアクションロール設定を取得
        const rrResp = await sb(`/reaction_roles?id=eq.${body.reactionRoleId}`);
        if (!rrResp.ok) {
          const errBody = await rrResp.text();
          return new Response(JSON.stringify({
            error: `Supabase エラー (${rrResp.status}): ${errBody}`,
            debug: { reactionRoleId: body.reactionRoleId }
          }), { status: 502 });
        }
        const rrList = await rrResp.json() as Array<{
          id: string;
          embed_id: string;
          pairs: Array<{ emoji: string; role_id: string; role_name: string }>;
          mode: string;
        }>;
        if (!rrList.length) {
          return new Response(JSON.stringify({
            error: `IDが一致するデータが見つかりません`,
            debug: { reactionRoleId: body.reactionRoleId, tableHit: true }
          }), { status: 404 });
        }
        const rr = rrList[0];

        // 2. Supabase から embed テンプレートを取得
        const embedResp = await sb(`/embeds?id=eq.${rr.embed_id}`);
        const embedList = await embedResp.json() as Embed[];
        if (!embedList.length) {
          return new Response(JSON.stringify({ error: "Embedテンプレートが見つかりません" }), { status: 404 });
        }
        const embed = embedList[0];

        // 3. Discord にメッセージを投稿
        const discordBody = {
          content: embed.message_content?.trim() || undefined,
          allowed_mentions: { parse: ["everyone", "roles", "users"] },
          embeds: [{
            title: embed.title ?? undefined,
            description: embed.description ?? undefined,
            color: embed.color_hex,
            fields: embed.fields ?? [],
            image: embed.image_url ? { url: embed.image_url } : undefined,
            thumbnail: embed.thumbnail_url ? { url: embed.thumbnail_url } : undefined,
            footer: embed.footer_text ? { text: embed.footer_text, icon_url: embed.footer_icon_url ?? undefined } : undefined,
            timestamp: embed.show_timestamp ? new Date().toISOString() : undefined,
          }],
        };

        const postResp = await fetch(
          `https://discord.com/api/v10/channels/${body.channelId}/messages`,
          {
            method: "POST",
            headers: {
              Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify(discordBody),
          }
        );

        if (!postResp.ok) {
          const errText = await postResp.text();
          return new Response(JSON.stringify({ error: `Discord送信失敗: ${errText}` }), { status: 502 });
        }

        const postedMessage = await postResp.json() as { id: string };
        const messageId = postedMessage.id;

        // 4. 各絵文字をリアクションとして追加
        for (const pair of rr.pairs) {
          const emoji = pair.emoji.replace(/️/g, ""); // variation selector 除去
          const encodedEmoji = encodeURIComponent(emoji);
          await fetch(
            `https://discord.com/api/v10/channels/${body.channelId}/messages/${messageId}/reactions/${encodedEmoji}/@me`,
            {
              method: "PUT",
              headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
            }
          );
          // Discordのレート制限対策（250ms待機）
          await new Promise(r => setTimeout(r, 250));
        }

        // 5. Supabase のリアクションロール設定を更新（channelId / channelName / messageId）
        await sb(`/reaction_roles?id=eq.${body.reactionRoleId}`, {
          method: "PATCH",
          body: JSON.stringify({
            channel_id: body.channelId,
            channel_name: body.channelName,
            message_id: messageId,
          }),
        });

        return new Response(JSON.stringify({ messageId }), {
          headers: { "Content-Type": "application/json" },
        });
      } catch (e) {
        return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
      }
    }

    // Bot招待URL（管理者権限付き）
    if (url.pathname === "/bot/invite-url") {
      const guildId = url.searchParams.get("guild_id") || "";
      // Administrator (8) = サーバー管理者権限
      const permissions = "8";
      const inviteUrl = "https://discord.com/api/oauth2/authorize"
        + `?client_id=${env.DISCORD_CLIENT_ID}`
        + `&permissions=${permissions}`
        + "&scope=bot%20applications.commands"
        + (guildId ? `&guild_id=${guildId}` : "");
      return new Response(inviteUrl, {
        headers: { "Content-Type": "text/plain" },
      });
    }

    // ── チケット管理 ────────────────────────────────────────────

    // チケット作成 POST /bot/tickets/create
    if (url.pathname === '/bot/tickets/create' && request.method === 'POST') {
      try {
        const body = await request.json() as Record<string, unknown>;
        const guildId = (body.guildId ?? body.guild_id ?? '') as string;
        const subject = (body.subject ?? body.subject ?? '') as string;
        const openedByUserId = (body.openedByUserId ?? body.opened_by_user_id ?? 'admin') as string;
        if (!guildId || !subject?.trim())
          return new Response('guildId and subject are required', { status: 400 });

        // Discord にチャンネルを作成
        const suffix      = Date.now().toString().slice(-4);
        const channelName = `ticket-admin-${suffix}`;
        const chResp = await fetch(`https://discord.com/api/v10/guilds/${guildId}/channels`, {
          method: 'POST',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ name: channelName, type: 0 }),
        });
        const channelId = chResp.ok ? ((await chResp.json()) as { id: string }).id : '';

        // Supabase にチケットを記録
        const sbRes = await sb('/tickets', {
          method:  'POST',
          body:    JSON.stringify({
            guild_id:          guildId,
            channel_id:        channelId,
            opened_by_user_id: openedByUserId,
            subject:           subject.trim(),
          }),
          headers: { Prefer: 'return=representation' },
        });
        if (!sbRes.ok) return new Response(await sbRes.text(), { status: sbRes.status });
        const rows = await sbRes.json() as TicketRow[];
        return new Response(JSON.stringify(mapTicket(rows[0])), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) {
        return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
      }
    }

    // チケット一覧 GET /bot/tickets?guild_id=xxx[&status=xxx]
    if (url.pathname === '/bot/tickets' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });
      const status = url.searchParams.get('status');
      let query = `/tickets?guild_id=eq.${guildId}&order=last_message_at.desc`;
      if (status) query += `&status=eq.${status}`;
      const resp = await sb(query);
      if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
      const rows = await resp.json() as TicketRow[];
      return new Response(JSON.stringify(rows.map(mapTicket)), { headers: { 'Content-Type': 'application/json' } });
    }

    // チケット詳細 GET /bot/tickets/:id
    const ticketDetailMatch = url.pathname.match(/^\/bot\/tickets\/([^\/]+)$/);
    if (ticketDetailMatch && request.method === 'GET') {
      const id = ticketDetailMatch[1];
      const resp = await sb(`/tickets?id=eq.${id}`);
      if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
      const rows = await resp.json() as TicketRow[];
      if (!rows.length) return new Response('Not found', { status: 404 });
      return new Response(JSON.stringify(mapTicket(rows[0])), { headers: { 'Content-Type': 'application/json' } });
    }

    // メッセージ一覧 GET /bot/tickets/:id/messages
    const ticketMsgMatch = url.pathname.match(/^\/bot\/tickets\/([^\/]+)\/messages$/);
    if (ticketMsgMatch && request.method === 'GET') {
      const ticketId = ticketMsgMatch[1];
      const resp = await sb(`/ticket_messages?ticket_id=eq.${ticketId}&order=created_at.asc`);
      if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
      const rows = await resp.json() as TicketMessageRow[];
      return new Response(JSON.stringify(rows.map(mapTicketMessage)), { headers: { 'Content-Type': 'application/json' } });
    }

    // クローズ POST /bot/tickets/:id/close
    const ticketCloseMatch = url.pathname.match(/^\/bot\/tickets\/([^\/]+)\/close$/);
    if (ticketCloseMatch && request.method === 'POST') {
      const id = ticketCloseMatch[1];
      const ticketResp = await sb(`/tickets?id=eq.${id}`);
      const tickets = await ticketResp.json() as TicketRow[];
      if (!tickets.length) return new Response('Not found', { status: 404 });
      const ticket = tickets[0];

      // Supabase 更新
      await sb(`/tickets?id=eq.${id}`, {
        method: 'PATCH',
        body: JSON.stringify({ status: 'closed', closed_at: new Date().toISOString() }),
      });

      // Discord: 開設者の ViewChannel を剥奪
      try {
        await fetch(`https://discord.com/api/v10/channels/${ticket.channel_id}/permissions/${ticket.opened_by_user_id}`, {
          method: 'PUT',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ deny: '1024', type: 1 }), // deny VIEW_CHANNEL
        });
        // クローズ通知
        await fetch(`https://discord.com/api/v10/channels/${ticket.channel_id}/messages`, {
          method: 'POST',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ content: '🔒 **チケットがクローズされました。**\n作成者はこのチャンネルにアクセスできなくなりました。' }),
        });
      } catch { /* ignore Discord errors */ }

      return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
    }

    // ステータス変更 POST /bot/tickets/:id/status
    const ticketStatusMatch = url.pathname.match(/^\/bot\/tickets\/([^\/]+)\/status$/);
    if (ticketStatusMatch && request.method === 'POST') {
      const id = ticketStatusMatch[1];
      const body = await request.json() as { status: string };
      if (!['open', 'pending', 'closed'].includes(body.status))
        return new Response('Invalid status', { status: 400 });

      const ticketResp = await sb(`/tickets?id=eq.${id}`);
      const tickets = await ticketResp.json() as TicketRow[];
      if (!tickets.length) return new Response('Not found', { status: 404 });
      const ticket = tickets[0];

      const patchBody: any = { status: body.status };
      if (body.status === 'closed') {
        patchBody.closed_at = new Date().toISOString();
      } else {
        patchBody.closed_at = null;
      }
      await sb(`/tickets?id=eq.${id}`, {
        method: 'PATCH',
        body: JSON.stringify(patchBody),
      });

      // Discord通知
      try {
        const statusMessages: Record<string, string> = {
          open: '🔓 **チケットが再オープンされました。**',
          pending: '⏳ **チケットが対応中になりました。**',
          closed: '🔒 **チケットがクローズされました。**',
        };
        await fetch(`https://discord.com/api/v10/channels/${ticket.channel_id}/messages`, {
          method: 'POST',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ content: statusMessages[body.status] }),
        });

        if (body.status === 'closed') {
          await fetch(`https://discord.com/api/v10/channels/${ticket.channel_id}/permissions/${ticket.opened_by_user_id}`, {
            method: 'PUT',
            headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({ deny: '1024', type: 1 }),
          });
        } else if (body.status === 'open' || body.status === 'pending') {
          await fetch(`https://discord.com/api/v10/channels/${ticket.channel_id}/permissions/${ticket.opened_by_user_id}`, {
            method: 'PUT',
            headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({ allow: '117760', type: 1 }),
          });
        }
      } catch { /* ignore Discord errors */ }

      return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
    }

    // 再オープン POST /bot/tickets/:id/reopen
    const ticketReopenMatch = url.pathname.match(/^\/bot\/tickets\/([^\/]+)\/reopen$/);
    if (ticketReopenMatch && request.method === 'POST') {
      const id = ticketReopenMatch[1];
      const ticketResp = await sb(`/tickets?id=eq.${id}`);
      const tickets = await ticketResp.json() as TicketRow[];
      if (!tickets.length) return new Response('Not found', { status: 404 });
      const ticket = tickets[0];

      await sb(`/tickets?id=eq.${id}`, {
        method: 'PATCH',
        body: JSON.stringify({ status: 'open', closed_at: null }),
      });

      try {
        // 開設者のViewChannel権限を復元
        await fetch(`https://discord.com/api/v10/channels/${ticket.channel_id}/permissions/${ticket.opened_by_user_id}`, {
          method: 'PUT',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ allow: '117760', type: 1 }), // VIEW_CHANNEL + SEND_MESSAGES + READ_HISTORY + ATTACH_FILES
        });
        await fetch(`https://discord.com/api/v10/channels/${ticket.channel_id}/messages`, {
          method: 'POST',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ content: '🔓 **チケットが再オープンされました。**' }),
        });
      } catch { /* ignore */ }

      return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
    }

    // 優先度変更 POST /bot/tickets/:id/priority
    const ticketPriorityMatch = url.pathname.match(/^\/bot\/tickets\/([^\/]+)\/priority$/);
    if (ticketPriorityMatch && request.method === 'POST') {
      const id = ticketPriorityMatch[1];
      const body = await request.json() as { priority: string };
      if (!['low', 'medium', 'high', 'urgent'].includes(body.priority))
        return new Response('Invalid priority', { status: 400 });
      await sb(`/tickets?id=eq.${id}`, {
        method: 'PATCH',
        body: JSON.stringify({ priority: body.priority }),
      });
      const resp = await sb(`/tickets?id=eq.${id}`);
      const rows = await resp.json() as TicketRow[];
      return new Response(JSON.stringify(mapTicket(rows[0])), { headers: { 'Content-Type': 'application/json' } });
    }

    // スタッフ返信 POST /bot/tickets/:id/reply
    const ticketReplyMatch = url.pathname.match(/^\/bot\/tickets\/([^\/]+)\/reply$/);
    if (ticketReplyMatch && request.method === 'POST') {
      const id = ticketReplyMatch[1];
      const body = await request.json() as { content: string };
      if (!body.content?.trim()) return new Response('content is required', { status: 400 });

      const ticketResp = await sb(`/tickets?id=eq.${id}`);
      const tickets = await ticketResp.json() as TicketRow[];
      if (!tickets.length) return new Response('Not found', { status: 404 });
      const ticket = tickets[0];
      if (ticket.status === 'closed') return new Response('Ticket is closed', { status: 400 });

      // Supabase にメッセージ記録
      const msgResp = await sb('/ticket_messages', {
        method: 'POST',
        body: JSON.stringify({
          ticket_id: id,
          user_id: 'app-staff',
          username: 'Staff (App)',
          content: body.content.trim(),
          is_staff: true,
        }),
        headers: { Prefer: 'return=representation' },
      });
      // message_count + last_message_at 更新
      await sb(`/tickets?id=eq.${id}`, {
        method: 'PATCH',
        body: JSON.stringify({
          message_count: ticket.message_count + 1,
          last_message_at: new Date().toISOString(),
        }),
      });

      // Discord チャンネルに送信
      try {
        await fetch(`https://discord.com/api/v10/channels/${ticket.channel_id}/messages`, {
          method: 'POST',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            embeds: [{
              description: body.content.trim(),
              color: 0x6366f1,
              author: { name: '📱 アプリからのスタッフ返信' },
              timestamp: new Date().toISOString(),
            }],
          }),
        });
      } catch { /* ignore */ }

      const msgRows = msgResp.ok ? await msgResp.json() as TicketMessageRow[] : [];
      const msg = msgRows[0] ?? { id: '', ticket_id: id, user_id: 'app-staff', username: 'Staff (App)', content: body.content, is_staff: true, created_at: new Date().toISOString() };
      return new Response(JSON.stringify(mapTicketMessage(msg)), { headers: { 'Content-Type': 'application/json' } });
    }

    // 担当者割り当て POST /bot/tickets/:id/assign
    const ticketAssignMatch = url.pathname.match(/^\/bot\/tickets\/([^\/]+)\/assign$/);
    if (ticketAssignMatch && request.method === 'POST') {
      const id = ticketAssignMatch[1];
      const body = await request.json() as Record<string, unknown>;
      const userId = (body.userId ?? body.user_id ?? '') as string;
      if (!userId?.trim()) return new Response('userId is required', { status: 400 });

      const ticketResp = await sb(`/tickets?id=eq.${id}`);
      const tickets = await ticketResp.json() as TicketRow[];
      if (!tickets.length) return new Response('Not found', { status: 404 });
      const ticket = tickets[0];

      await sb(`/tickets?id=eq.${id}`, {
        method: 'PATCH',
        body: JSON.stringify({ assigned_to_user_id: userId }),
      });

      // Discord チャンネルに担当者を追加
      try {
        await fetch(`https://discord.com/api/v10/channels/${ticket.channel_id}/permissions/${userId}`, {
          method: 'PUT',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ allow: '117760', type: 1 }),
        });
      } catch { /* ignore */ }

      const resp = await sb(`/tickets?id=eq.${id}`);
      const rows = await resp.json() as TicketRow[];
      return new Response(JSON.stringify(mapTicket(rows[0])), { headers: { 'Content-Type': 'application/json' } });
    }

    // ── チケットパネル管理 ──────────────────────────────────────

    // 一覧 GET /bot/ticket-panels?guild_id=xxx
    if (url.pathname === '/bot/ticket-panels' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });
      const resp = await sb(`/ticket_panels?guild_id=eq.${guildId}&order=created_at.desc`);
      if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
      const rows = await resp.json() as TicketPanelRow[];
      return new Response(JSON.stringify(rows.map(mapPanel)), { headers: { 'Content-Type': 'application/json' } });
    }

    // 作成 POST /bot/ticket-panels
    if (url.pathname === '/bot/ticket-panels' && request.method === 'POST') {
      try {
        // iOS は camelCase で送信する
        const body = await request.json() as Record<string, unknown>;
        const insertData = {
          guild_id:          (body.guildId ?? body.guild_id ?? '') as string,
          channel_id:        (body.channelId ?? body.channel_id ?? '') as string,
          title:             (body.title ?? body.title ?? 'サポートチケット') as string,
          description:       (body.description ?? body.description ?? '') as string,
          color:             (body.color ?? body.color ?? 0x6366f1) as number,
          button_label:      (body.buttonLabel ?? body.button_label ?? 'チケットを作成') as string,
          button_emoji:      (body.buttonEmoji ?? body.button_emoji ?? '🎫') as string,
          support_role_id:   (body.supportRoleId ?? body.support_role_id ?? null) as string | null,
          open_category_id:  (body.openCategoryId ?? body.open_category_id ?? null) as string | null,
          closed_category_id:(body.closedCategoryId ?? body.closed_category_id ?? null) as string | null,
          ticket_msg_content:(body.ticketMsgContent ?? body.ticket_msg_content ?? null) as string | null,
          ticket_embed_title:(body.ticketEmbedTitle ?? body.ticket_embed_title ?? 'チケット') as string,
          ticket_embed_color:(body.ticketEmbedColor ?? body.ticket_embed_color ?? 0x6366f1) as number,
          max_open_per_user: (body.maxOpenPerUser ?? body.max_open_per_user ?? 1) as number,
        };
        const resp = await sb('/ticket_panels', {
          method: 'POST',
          body: JSON.stringify(insertData),
          headers: { Prefer: 'return=representation' },
        });
        if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
        const rows = await resp.json() as TicketPanelRow[];
        return new Response(JSON.stringify(mapPanel(rows[0])), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // 詳細 GET /bot/ticket-panels/:id
    const panelDetailMatch = url.pathname.match(/^\/bot\/ticket-panels\/([^\/]+)$/);

    // 更新 PATCH /bot/ticket-panels/:id
    if (panelDetailMatch && request.method === 'PATCH') {
      const id = panelDetailMatch[1];
      try {
        const body = await request.json() as Record<string, unknown>;
        // camelCase → snake_case マッピング
        const updateData: Record<string, unknown> = {};
        const camelToSnake: Record<string, string> = {
          channelId: 'channel_id', title: 'title', description: 'description',
          color: 'color', buttonLabel: 'button_label', buttonEmoji: 'button_emoji',
          supportRoleId: 'support_role_id', openCategoryId: 'open_category_id',
          closedCategoryId: 'closed_category_id', ticketMsgContent: 'ticket_msg_content',
          ticketEmbedTitle: 'ticket_embed_title', ticketEmbedColor: 'ticket_embed_color',
          maxOpenPerUser: 'max_open_per_user',
        };
        for (const [k, v] of Object.entries(body)) {
          const snakeKey = camelToSnake[k] ?? k;
          updateData[snakeKey] = v;
        }
        const resp = await sb(`/ticket_panels?id=eq.${id}`, {
          method: 'PATCH',
          body: JSON.stringify(updateData),
          headers: { Prefer: 'return=representation' },
        });
        if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
        const rows = await resp.json() as TicketPanelRow[];
        return new Response(JSON.stringify(mapPanel(rows[0])), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // 削除 DELETE /bot/ticket-panels/:id
    if (panelDetailMatch && request.method === 'DELETE') {
      const id = panelDetailMatch[1];
      await sb(`/ticket_panels?id=eq.${id}`, { method: 'DELETE' });
      return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
    }

    // デプロイ POST /bot/ticket-panels/:id/deploy  body: { channelId: string }
    const panelDeployMatch = url.pathname.match(/^\/bot\/ticket-panels\/([^\/]+)\/deploy$/);
    if (panelDeployMatch && request.method === 'POST') {
      const id = panelDeployMatch[1];
      try {
        // channelId / channel_id をリクエストボディから受け取る（iOS は snake_case で送信する）
        let bodyChannelId = '';
        try {
          const body = await request.json() as { channelId?: string; channel_id?: string };
          bodyChannelId = body.channelId ?? body.channel_id ?? '';
        } catch { /* body なし */ }

        const panelResp = await sb(`/ticket_panels?id=eq.${id}`);
        const panels = await panelResp.json() as TicketPanelRow[];
        if (!panels.length) return new Response('Panel not found', { status: 404 });
        const panel = panels[0];

        // bodyChannelId が指定されていれば Supabase の channel_id を更新する
        const channelId = bodyChannelId || panel.channel_id;
        if (!channelId) return new Response('channelId is required', { status: 400 });
        if (bodyChannelId) {
          await sb(`/ticket_panels?id=eq.${id}`, {
            method: 'PATCH',
            body: JSON.stringify({ channel_id: bodyChannelId }),
          });
          panel.channel_id = bodyChannelId;
        }

        // Discord にパネルメッセージを投稿
        const btnComponent: Record<string, unknown> = {
          type:      2,
          style:     1,
          label:     panel.button_label,
          custom_id: `ticket_open_${panel.id}`,
        };
        // button_emoji が空でなければ emoji を追加（variation selector も除去）
        const cleanEmoji = (panel.button_emoji ?? '').replace(/\uFE0F/g, '').trim();
        if (cleanEmoji) {
          btnComponent.emoji = { name: cleanEmoji };
        }

        const postResp = await fetch(`https://discord.com/api/v10/channels/${channelId}/messages`, {
          method: 'POST',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            embeds: [{
              title:       panel.title,
              description: panel.description,
              color:       panel.color,
            }],
            components: [{
              type: 1,
              components: [btnComponent],
            }],
          }),
        });
        if (!postResp.ok) {
          const errText = await postResp.text();
          return new Response(JSON.stringify({ error: `Discord送信失敗: ${errText}` }), { status: 502 });
        }
        const posted = await postResp.json() as { id: string };

        // message_id を保存
        await sb(`/ticket_panels?id=eq.${id}`, {
          method: 'PATCH',
          body: JSON.stringify({ message_id: posted.id }),
        });

        const updated = await sb(`/ticket_panels?id=eq.${id}`);
        const updatedRows = await updated.json() as TicketPanelRow[];
        return new Response(JSON.stringify(mapPanel(updatedRows[0])), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // ── 一時チャンネル設定 ──────────────────────────────────────

    // GET /bot/temp-channel-settings?guild_id=xxx
    if (url.pathname === '/bot/temp-channel-settings' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });
      const resp = await sb(`/temp_channel_settings?guild_id=eq.${guildId}`);
      if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
      const rows = await resp.json() as Record<string, unknown>[];
      if (!rows.length) {
        // デフォルト設定を返す
        return new Response(JSON.stringify({
          id: null, guildId, enabled: false, categoryId: null,
          channelNameFormat: '💬-{vc-name}', autoDelete: true,
          deleteDelayMinutes: 0, joinLeaveNotification: true,
          watchAllVcs: true, watchVcIds: [], minMembers: 1,
        }), { headers: { 'Content-Type': 'application/json' } });
      }
      const r = rows[0];
      return new Response(JSON.stringify({
        id:                     r['id'],
        guildId:                r['guild_id'],
        enabled:                r['enabled'],
        categoryId:             r['category_id'] ?? null,
        channelNameFormat:      r['channel_name_format'],
        autoDelete:             r['auto_delete'],
        deleteDelayMinutes:     r['delete_delay_minutes'],
        joinLeaveNotification:  r['join_leave_notification'],
        watchAllVcs:            r['watch_all_vcs'],
        watchVcIds:             r['watch_vc_ids'] ?? [],
        minMembers:             r['min_members'],
      }), { headers: { 'Content-Type': 'application/json' } });
    }

    // POST /bot/temp-channel-settings  (upsert)
    if (url.pathname === '/bot/temp-channel-settings' && request.method === 'POST') {
      try {
        const body = await request.json() as {
          guildId: string; enabled?: boolean; categoryId?: string | null;
          channelNameFormat?: string; autoDelete?: boolean;
          deleteDelayMinutes?: number; joinLeaveNotification?: boolean;
          watchAllVcs?: boolean; watchVcIds?: string[]; minMembers?: number;
        };
        console.log('[Worker] POST /bot/temp-channel-settings body:', JSON.stringify(body));

        // 既存レコードをチェック
        const checkResp = await sb(`/temp_channel_settings?guild_id=eq.${body.guildId}`);
        const checkRows = await checkResp.json() as Record<string, unknown>[];

        const upsertData = {
          guild_id:                body.guildId,
          enabled:                 body.enabled                ?? false,
          category_id:             body.categoryId             ?? null,
          channel_name_format:     body.channelNameFormat      ?? '💬-{vc-name}',
          auto_delete:             body.autoDelete             ?? true,
          delete_delay_minutes:    body.deleteDelayMinutes     ?? 0,
          join_leave_notification: body.joinLeaveNotification  ?? true,
          watch_all_vcs:           body.watchAllVcs            ?? true,
          watch_vc_ids:            body.watchVcIds             ?? [],
          min_members:             body.minMembers             ?? 1,
          updated_at:              new Date().toISOString(),
        };

        let resp: Response;
        if (checkRows.length > 0) {
          // 既存 → PATCH
          console.log('[Worker] temp-channel-settings: updating existing, id=', checkRows[0]['id']);
          resp = await sb(`/temp_channel_settings?id=eq.${checkRows[0]['id']}`, {
            method: 'PATCH',
            body:   JSON.stringify(upsertData),
            headers: { Prefer: 'return=representation' },
          });
        } else {
          // 新規 → POST
          console.log('[Worker] temp-channel-settings: creating new');
          resp = await sb('/temp_channel_settings', {
            method: 'POST',
            body:   JSON.stringify(upsertData),
            headers: { Prefer: 'return=representation' },
          });
        }

        if (!resp.ok) {
          const errText = await resp.text();
          console.error('[Worker] POST /bot/temp-channel-settings FAILED:', resp.status, errText);
          return new Response(errText, { status: resp.status });
        }
        console.log('[Worker] POST /bot/temp-channel-settings OK');
        const rows = await resp.json() as Record<string, unknown>[];
        const r = rows[0];
        return new Response(JSON.stringify({
          id:                    r['id'],
          guildId:               r['guild_id'],
          enabled:               r['enabled'],
          categoryId:            r['category_id'] ?? null,
          channelNameFormat:     r['channel_name_format'],
          autoDelete:            r['auto_delete'],
          deleteDelayMinutes:    r['delete_delay_minutes'],
          joinLeaveNotification: r['join_leave_notification'],
          watchAllVcs:           r['watch_all_vcs'],
          watchVcIds:            r['watch_vc_ids'] ?? [],
          minMembers:            r['min_members'],
        }), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // GET /bot/temp-channels?guild_id=xxx  （アクティブな一時チャンネル一覧）
    if (url.pathname === '/bot/temp-channels' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });
      const resp = await sb(`/temp_channels?guild_id=eq.${guildId}&order=created_at.desc`);
      if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
      const rows = await resp.json() as Record<string, unknown>[];
      return new Response(JSON.stringify(rows.map(r => ({
        id:            r['id'],
        guildId:       r['guild_id'],
        vcChannelId:   r['vc_channel_id'],
        textChannelId: r['text_channel_id'],
        createdAt:     r['created_at'],
      }))), { headers: { 'Content-Type': 'application/json' } });
    }

    // ── 一時VC: temp_vc_sources CRUD ───────────────────

    // GET /bot/temp-vc-sources?guild_id=xxx
    if (url.pathname === '/bot/temp-vc-sources' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });
      const resp = await sb(`/temp_vc_sources?guild_id=eq.${guildId}&order=created_at.desc`);
      if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
      const rows = await resp.json() as Record<string, unknown>[];
      return new Response(JSON.stringify(rows.map(r => ({
        id:                       r['id'],
        guildId:                  r['guild_id'],
        triggerVcId:              r['trigger_vc_id'] ?? null,
        triggerVcName:            r['trigger_vc_name'],
        vcCategoryId:             r['vc_category_id'],
        textChannelCategoryId:    r['text_channel_category_id'],
        vcNameFormat:             r['vc_name_format'],
        channelNameFormat:        r['channel_name_format'],
        userLimit:                r['user_limit'],
        autoDelete:               r['auto_delete'],
        deleteDelayMinutes:       r['delete_delay_minutes'],
        joinLeaveNotification:    r['join_leave_notification'],
        enabled:                  r['enabled'],
        waitingRoomEnabled:       r['waiting_room_enabled'] ?? false,
        createdAt:                r['created_at'],
      }))), { headers: { 'Content-Type': 'application/json' } });
    }

    // POST /bot/temp-vc-sources (create)
    if (url.pathname === '/bot/temp-vc-sources' && request.method === 'POST') {
      try {
        const body = await request.json() as {
          guildId: string; triggerVcName?: string; vcCategoryId: string;
          textChannelCategoryId: string; vcNameFormat?: string; channelNameFormat?: string;
          userLimit?: number; autoDelete?: boolean; deleteDelayMinutes?: number;
          joinLeaveNotification?: boolean; enabled?: boolean; waitingRoomEnabled?: boolean;
        };
        const insertData = {
          guild_id:                   body.guildId,
          trigger_vc_id:              null,
          trigger_vc_name:            body.triggerVcName ?? '🏠 一時VCを作ろう',
          vc_category_id:             body.vcCategoryId,
          text_channel_category_id:   body.textChannelCategoryId,
          vc_name_format:             body.vcNameFormat ?? '{user-name}のVC',
          channel_name_format:        body.channelNameFormat ?? '{user-name}の部屋',
          user_limit:                 body.userLimit ?? 0,
          auto_delete:                body.autoDelete ?? true,
          delete_delay_minutes:       body.deleteDelayMinutes ?? 0,
          join_leave_notification:    body.joinLeaveNotification ?? true,
          enabled:                    body.enabled ?? true,
          waiting_room_enabled:       body.waitingRoomEnabled ?? false,
        };
        const resp = await sb('/temp_vc_sources', {
          method: 'POST',
          body:   JSON.stringify(insertData),
          headers: { Prefer: 'return=representation' },
        });
        if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
        const rows = await resp.json() as Record<string, unknown>[];
        const r = rows[0];
        return new Response(JSON.stringify({
          id:                       r['id'],
          guildId:                  r['guild_id'],
          triggerVcId:              r['trigger_vc_id'] ?? null,
          triggerVcName:            r['trigger_vc_name'],
          vcCategoryId:             r['vc_category_id'],
          textChannelCategoryId:    r['text_channel_category_id'],
          vcNameFormat:             r['vc_name_format'],
          channelNameFormat:        r['channel_name_format'],
          userLimit:                r['user_limit'],
          autoDelete:               r['auto_delete'],
          deleteDelayMinutes:       r['delete_delay_minutes'],
          joinLeaveNotification:    r['join_leave_notification'],
          enabled:                  r['enabled'],
          waitingRoomEnabled:       r['waiting_room_enabled'] ?? false,
          createdAt:                r['created_at'],
        }), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // PATCH /bot/temp-vc-sources/:id
    const tempVcSourcePatchMatch = url.pathname.match(/^\/bot\/temp-vc-sources\/([^\/]+)$/);
    if (tempVcSourcePatchMatch && request.method === 'PATCH') {
      try {
        const id = tempVcSourcePatchMatch[1];
        const body = await request.json() as Record<string, unknown>;
        const updateData: Record<string, unknown> = {};
        const camelToSnake: Record<string, string> = {
          guildId: 'guild_id', triggerVcName: 'trigger_vc_name',
          vcCategoryId: 'vc_category_id', textChannelCategoryId: 'text_channel_category_id',
          vcNameFormat: 'vc_name_format', channelNameFormat: 'channel_name_format',
          userLimit: 'user_limit', autoDelete: 'auto_delete',
          deleteDelayMinutes: 'delete_delay_minutes', joinLeaveNotification: 'join_leave_notification',
          enabled: 'enabled', triggerVcId: 'trigger_vc_id',
          waitingRoomEnabled: 'waiting_room_enabled',
        };
        for (const [k, v] of Object.entries(body)) {
          const snakeKey = camelToSnake[k] ?? k;
          updateData[snakeKey] = v;
        }
        updateData['updated_at'] = new Date().toISOString();
        const resp = await sb(`/temp_vc_sources?id=eq.${id}`, {
          method: 'PATCH',
          body:   JSON.stringify(updateData),
          headers: { Prefer: 'return=representation' },
        });
        if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
        const rows = await resp.json() as Record<string, unknown>[];
        if (!rows.length) return new Response('Not found', { status: 404 });
        const r = rows[0];
        return new Response(JSON.stringify({
          id:                       r['id'],
          guildId:                  r['guild_id'],
          triggerVcId:              r['trigger_vc_id'] ?? null,
          triggerVcName:            r['trigger_vc_name'],
          vcCategoryId:             r['vc_category_id'],
          textChannelCategoryId:    r['text_channel_category_id'],
          vcNameFormat:             r['vc_name_format'],
          channelNameFormat:        r['channel_name_format'],
          userLimit:                r['user_limit'],
          autoDelete:               r['auto_delete'],
          deleteDelayMinutes:       r['delete_delay_minutes'],
          joinLeaveNotification:    r['join_leave_notification'],
          enabled:                  r['enabled'],
          waitingRoomEnabled:       r['waiting_room_enabled'] ?? false,
          createdAt:                r['created_at'],
        }), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // DELETE /bot/temp-vc-sources/:id
    const tempVcSourceDeleteMatch = url.pathname.match(/^\/bot\/temp-vc-sources\/([^\/]+)$/);
    if (tempVcSourceDeleteMatch && request.method === 'DELETE') {
      const id = tempVcSourceDeleteMatch[1];
      const resp = await sb(`/temp_vc_sources?id=eq.${id}`, { method: 'DELETE' });
      if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
      return new Response(JSON.stringify({ success: true }), { headers: { 'Content-Type': 'application/json' } });
    }

    // POST /bot/temp-vc-sources/:id/create-trigger-vc
    const createTriggerVcMatch = url.pathname.match(/^\/bot\/temp-vc-sources\/([^\/]+)\/create-trigger-vc$/);
    if (createTriggerVcMatch && request.method === 'POST') {
      try {
        const id = createTriggerVcMatch[1];
        const body = await request.json() as { guildId: string; triggerVcName: string; vcCategoryId: string };

        // DiscordにトリガーVCを作成（人数制限1）
        const vcResp = await fetch(`https://discord.com/api/v10/guilds/${body.guildId}/channels`, {
          method: 'POST',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            name: body.triggerVcName,
            type: 2, // Voice Channel
            parent_id: body.vcCategoryId,
            user_limit: 1,
            permission_overwrites: [
              { id: body.guildId, allow: '1048576', deny: '0' } // Connect allowed for @everyone
            ],
          }),
        });

        if (!vcResp.ok) {
          return new Response(await vcResp.text(), { status: vcResp.status });
        }

        const vcData = await vcResp.json() as { id: string };
        const triggerVcId = vcData.id;

        // Supabase更新
        const resp = await sb(`/temp_vc_sources?id=eq.${id}`, {
          method: 'PATCH',
          body: JSON.stringify({ trigger_vc_id: triggerVcId, updated_at: new Date().toISOString() }),
          headers: { Prefer: 'return=representation' },
        });
        if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
        const rows = await resp.json() as Record<string, unknown>[];
        const r = rows[0];
        return new Response(JSON.stringify({
          id:                       r['id'],
          guildId:                  r['guild_id'],
          triggerVcId:              r['trigger_vc_id'] ?? null,
          triggerVcName:            r['trigger_vc_name'],
          vcCategoryId:             r['vc_category_id'],
          textChannelCategoryId:    r['text_channel_category_id'],
          vcNameFormat:             r['vc_name_format'],
          channelNameFormat:        r['channel_name_format'],
          userLimit:                r['user_limit'],
          autoDelete:               r['auto_delete'],
          deleteDelayMinutes:       r['delete_delay_minutes'],
          joinLeaveNotification:    r['join_leave_notification'],
          enabled:                  r['enabled'],
          waitingRoomEnabled:       r['waiting_room_enabled'] ?? false,
          createdAt:                r['created_at'],
        }), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // POST /bot/temp-vc-sources/:id/hide-trigger-vc
    const hideTriggerVcMatch = url.pathname.match(/^\/bot\/temp-vc-sources\/([^\/]+)\/hide-trigger-vc$/);
    if (hideTriggerVcMatch && request.method === 'POST') {
      try {
        const id = hideTriggerVcMatch[1];
        const body = await request.json() as { guildId: string; triggerVcId: string };

        // DiscordでトリガーVCを非表示（@everyoneのConnect権限を剥奪）
        await fetch(`https://discord.com/api/v10/channels/${body.triggerVcId}/permissions/${body.guildId}`, {
          method: 'PUT',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ allow: '0', deny: '1048576', type: 0 }), // deny Connect
        });

        return new Response(JSON.stringify({ success: true }), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // POST /bot/temp-vc-sources/:id/show-trigger-vc
    const showTriggerVcMatch = url.pathname.match(/^\/bot\/temp-vc-sources\/([^\/]+)\/show-trigger-vc$/);
    if (showTriggerVcMatch && request.method === 'POST') {
      try {
        const id = showTriggerVcMatch[1];
        const body = await request.json() as { guildId: string; triggerVcId: string };

        // DiscordでトリガーVCを表示（@everyoneのConnect権限を付与）
        await fetch(`https://discord.com/api/v10/channels/${body.triggerVcId}/permissions/${body.guildId}`, {
          method: 'PUT',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ allow: '1048576', deny: '0', type: 0 }), // allow Connect
        });

        return new Response(JSON.stringify({ success: true }), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // ── ショップ CRUD ────────────────────────────────────────────

    // GET /bot/shops?guild_id=xxx
    if (url.pathname === '/bot/shops' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });
      const r = await sb(`/shops?guild_id=eq.${guildId}&order=created_at.desc`);
      const rows = await r.json() as ShopRow[];
      return new Response(JSON.stringify(rows.map(mapShop)), { headers: { 'Content-Type': 'application/json' } });
    }
    if (url.pathname === '/bot/shops' && request.method === 'POST') {
      try {
        const body = await request.json() as Partial<ShopRow> & Record<string, unknown>;
        console.log('[Worker] POST /bot/shops body:', JSON.stringify(body));
        const data = {
          guild_id:            body['guildId'] ?? body.guild_id ?? '',
          shop_type:           body['shopType'] ?? body.shop_type ?? 'shop',
          name:                body['name']    ?? 'ショップ',
          description:         body['description'] ?? '',
          enabled:             body['enabled']  ?? true,
          disabled_message:    body['disabledMessage'] ?? body.disabled_message ?? null,
          channel_id:          body['channelId'] ?? body.channel_id ?? '',
          order_category_id:   body['orderCategoryId']   ?? body.order_category_id   ?? null,
          archive_category_id: body['archiveCategoryId'] ?? body.archive_category_id ?? null,
          support_role_id:     body['supportRoleId']     ?? body.support_role_id     ?? null,
          timeout_hours:       body['timeoutHours']      ?? body.timeout_hours       ?? null,
          color:               body['color']   ?? 6579201,
          footer_text:         body['footerText'] ?? body.footer_text ?? '',
          review_enabled:      body['reviewEnabled'] ?? body.review_enabled ?? false,
          review_channel_id:   body['reviewChannelId'] ?? body.review_channel_id ?? null,
          welcome_image_url:   body['welcomeImageUrl'] ?? body.welcome_image_url ?? null,
          welcome_thumbnail_url: body['welcomeThumbnailUrl'] ?? body.welcome_thumbnail_url ?? null,
          welcome_fields:      body['welcomeFields'] ?? body.welcome_fields ?? [],
          welcome_footer_text: body['welcomeFooterText'] ?? body.welcome_footer_text ?? null,
          welcome_footer_icon_url: body['welcomeFooterIconUrl'] ?? body.welcome_footer_icon_url ?? null,
          welcome_show_timestamp: body['welcomeShowTimestamp'] ?? body.welcome_show_timestamp ?? true,
          payment_input_label: body['paymentInputLabel'] ?? body.payment_input_label ?? null,
          auto_delete_enabled: body['autoDeleteEnabled'] ?? body.auto_delete_enabled ?? false,
          auto_delete_days:    body['autoDeleteDays'] ?? body.auto_delete_days ?? null,
        };
        console.log('[Worker] POST /bot/shops data to Supabase:', JSON.stringify(data));
        let r = await sb('/shops', { method: 'POST', body: JSON.stringify(data), headers: { Prefer: 'return=representation' } });
        if (!r.ok && r.status === 400) {
          // shop_type 等の新カラムが未マイグレーションの場合、除いてリトライ
          const errText = await r.text();
          console.warn('[Worker] POST /bot/shops first attempt failed, retrying without new columns:', errText);
          const { shop_type: _st, payment_input_label: _pil, auto_delete_enabled: _ade, auto_delete_days: _add, ...legacyData } = data;
          r = await sb('/shops', { method: 'POST', body: JSON.stringify(legacyData), headers: { Prefer: 'return=representation' } });
        }
        if (!r.ok) {
          const errText = await r.text();
          console.error('[Worker] POST /bot/shops FAILED:', r.status, errText);
          return new Response(errText, { status: r.status });
        }
        console.log('[Worker] POST /bot/shops OK');
        const rows = await r.json() as ShopRow[];
        return new Response(JSON.stringify(mapShop(rows[0])), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }
    const shopIdMatch = url.pathname.match(/^\/bot\/shops\/([^\/]+)$/);
    if (shopIdMatch && request.method === 'PATCH') {
      try {
        const id   = shopIdMatch[1];
        const body = await request.json() as Record<string, unknown>;
        const camel: Record<string, string> = {
          name: 'name', description: 'description', enabled: 'enabled',
          disabledMessage: 'disabled_message',
          channelId: 'channel_id', orderCategoryId: 'order_category_id',
          archiveCategoryId: 'archive_category_id', supportRoleId: 'support_role_id',
          timeoutHours: 'timeout_hours', color: 'color', footerText: 'footer_text',
          reviewEnabled: 'review_enabled', reviewChannelId: 'review_channel_id',
          welcomeImageUrl: 'welcome_image_url', welcomeThumbnailUrl: 'welcome_thumbnail_url',
          welcomeFields: 'welcome_fields',
          welcomeFooterText: 'welcome_footer_text', welcomeFooterIconUrl: 'welcome_footer_icon_url',
          welcomeShowTimestamp: 'welcome_show_timestamp',
          paymentInputLabel: 'payment_input_label',
          autoDeleteEnabled: 'auto_delete_enabled', autoDeleteDays: 'auto_delete_days',
        };
        const data: Record<string, unknown> = {};
        for (const [k, v] of Object.entries(body)) { const sk = camel[k] ?? k; data[sk] = v; }
        let pr = await sb(`/shops?id=eq.${id}`, { method: 'PATCH', body: JSON.stringify(data), headers: { Prefer: 'return=representation' } });
        if (!pr.ok && pr.status === 400) {
          // 新カラム未マイグレーションの場合、除いてリトライ
          const { shop_type: _st, payment_input_label: _pil, auto_delete_enabled: _ade, auto_delete_days: _add, ...legacyData } = data as Record<string, unknown> & { shop_type?: unknown; payment_input_label?: unknown; auto_delete_enabled?: unknown; auto_delete_days?: unknown };
          pr = await sb(`/shops?id=eq.${id}`, { method: 'PATCH', body: JSON.stringify(legacyData), headers: { Prefer: 'return=representation' } });
        }
        if (!pr.ok) return new Response(await pr.text(), { status: pr.status });
        const rows = await pr.json() as ShopRow[];
        return new Response(JSON.stringify(mapShop(rows[0])), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }
    if (shopIdMatch && request.method === 'DELETE') {
      await sb(`/shops?id=eq.${shopIdMatch[1]}`, { method: 'DELETE' });
      return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
    }

    // ── ショップデプロイ POST /bot/shops/:id/deploy { channelId } ──
    const shopDeployMatch = url.pathname.match(/^\/bot\/shops\/([^\/]+)\/deploy$/);
    if (shopDeployMatch && request.method === 'POST') {
      try {
        const shopId = shopDeployMatch[1];
        const body   = await request.json() as { channelId?: string; channel_id?: string };
        const channelId = body.channelId ?? body.channel_id ?? '';
        console.log('[Worker] POST /bot/shops/:id/deploy shopId=', shopId, 'channelId=', channelId);
        if (!channelId) return new Response('channelId required', { status: 400 });
        // Shop と Products を並列取得
        const [sr, pr] = await Promise.all([
          sb(`/shops?id=eq.${shopId}`),
          sb(`/products?shop_id=eq.${shopId}&enabled=eq.true&order=position.asc`),
        ]);
        const shops = await sr.json() as ShopRow[];
        console.log('[Worker] deploy: shops found=', shops.length);
        if (!shops.length) return new Response('Shop not found', { status: 404 });
        const shop = shops[0];
        const products = await pr.json() as ProductRow[];
        console.log('[Worker] deploy: products found=', products.length);
        if (!products.length) return new Response('No enabled products', { status: 400 });
        // セレクトメニューのオプション
        const options = products.slice(0, 25).map(p => ({
          label:       (p.stock !== null && p.stock <= 0 ? '[売り切れ] ' : '') + p.name.slice(0, 100),
          description: `${p.price_display}${p.description ? ' ・ ' + p.description.slice(0, 50) : ''}`.slice(0, 100),
          value:       p.id,
          default:     false,
        }));
        // Discord にメッセージを投稿
        const discordBody = {
          embeds: [{ title: shop.name, description: shop.description || undefined, color: shop.color,
            image: shop.welcome_image_url ? { url: shop.welcome_image_url } : undefined,
            thumbnail: shop.welcome_thumbnail_url ? { url: shop.welcome_thumbnail_url } : undefined,
            fields: (shop.welcome_fields && shop.welcome_fields.length > 0) ? shop.welcome_fields : undefined,
            footer: { text: shop.welcome_footer_text ?? shop.footer_text ?? '',
              icon_url: shop.welcome_footer_icon_url ?? undefined },
            timestamp: shop.welcome_show_timestamp ? new Date().toISOString() : undefined }],
          components: [
            { type: 1, components: [{ type: 3, custom_id: `shop_select_${shopId}`,
              placeholder: '🛒 商品を選択してください', min_values: 1, max_values: 1, options }] },
            { type: 1, components: [{ type: 2, style: 4, label: '⚠️ 異議を申し立てる',
              custom_id: `shop_dispute_${shopId}` }] },
          ],
        };
        console.log('[Worker] deploy: posting to Discord channel', channelId);
        const postR = await fetch(`https://discord.com/api/v10/channels/${channelId}/messages`, {
          method: 'POST', headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify(discordBody),
        });
        if (!postR.ok) {
          const errText = await postR.text();
          console.error('[Worker] deploy: Discord API error', postR.status, errText);
          return new Response(JSON.stringify({ error: errText }), { status: 502 });
        }
        const posted = await postR.json() as { id: string };
        console.log('[Worker] deploy: Discord message posted, id=', posted.id);
        // PATCH で message_id を更新し、結果を返す（再取得不要）
        const updRows = await sb(`/shops?id=eq.${shopId}`, {
          method: 'PATCH',
          body: JSON.stringify({ channel_id: channelId, message_id: posted.id }),
          headers: { Prefer: 'return=representation' },
        }).then(r => r.json()) as ShopRow[];
        console.log('[Worker] deploy: complete');
        return new Response(JSON.stringify(mapShop(updRows[0])), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // ── 商品 CRUD ─────────────────────────────────────────────

    // GET /bot/shops/:shopId/products
    const shopProductsMatch = url.pathname.match(/^\/bot\/shops\/([^\/]+)\/products$/);
    if (shopProductsMatch && request.method === 'GET') {
      const r = await sb(`/products?shop_id=eq.${shopProductsMatch[1]}&order=position.asc`);
      const rows = await r.json() as ProductRow[];
      return new Response(JSON.stringify(rows.map(mapProduct)), { headers: { 'Content-Type': 'application/json' } });
    }
    if (shopProductsMatch && request.method === 'POST') {
      try {
        const body = await request.json() as Record<string, unknown>;
        const data = {
          shop_id:          shopProductsMatch[1],
          name:             body['name']             ?? '商品',
          description:      body['description']      ?? '',
          price_display:    body['priceDisplay']     ?? '要相談',
          image_url:        body['imageUrl']         ?? null,
          stock:            body['stock']            ?? null,
          reward_type:      body['rewardType']       ?? 'text',
          reward_content:   body['rewardContent']    ?? null,
          reward_role_id:   body['rewardRoleId']     ?? null,
          reward_dm_content:body['rewardDmContent']  ?? null,
          position:         body['position']         ?? 0,
          enabled:          body['enabled']          ?? true,
        };
        const r = await sb('/products', { method: 'POST', body: JSON.stringify(data), headers: { Prefer: 'return=representation' } });
        if (!r.ok) return new Response(await r.text(), { status: r.status });
        const rows = await r.json() as ProductRow[];
        return new Response(JSON.stringify(mapProduct(rows[0])), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }
    const productIdMatch = url.pathname.match(/^\/bot\/products\/([^\/]+)$/);
    if (productIdMatch && request.method === 'PATCH') {
      try {
        const id   = productIdMatch[1];
        const body = await request.json() as Record<string, unknown>;
        const camel: Record<string, string> = {
          name: 'name', description: 'description', priceDisplay: 'price_display',
          imageUrl: 'image_url', stock: 'stock', rewardType: 'reward_type',
          rewardContent: 'reward_content', rewardRoleId: 'reward_role_id',
          rewardDmContent: 'reward_dm_content', position: 'position', enabled: 'enabled',
        };
        const data: Record<string, unknown> = {};
        for (const [k, v] of Object.entries(body)) { const sk = camel[k] ?? k; data[sk] = v; }
        const r = await sb(`/products?id=eq.${id}`, { method: 'PATCH', body: JSON.stringify(data), headers: { Prefer: 'return=representation' } });
        if (!r.ok) return new Response(await r.text(), { status: r.status });
        const rows = await r.json() as ProductRow[];
        return new Response(JSON.stringify(mapProduct(rows[0])), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }
    if (productIdMatch && request.method === 'DELETE') {
      await sb(`/products?id=eq.${productIdMatch[1]}`, { method: 'DELETE' });
      return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
    }

    // ── 注文 API ────────────────────────────────────────────────

    // GET /bot/orders?guild_id=xxx[&status=xxx]
    if (url.pathname === '/bot/orders' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });
      const status  = url.searchParams.get('status');
      let query = `/orders?guild_id=eq.${guildId}&order=created_at.desc`;
      if (status) query += `&status=eq.${status}`;
      const r = await sb(query);
      const rows = await r.json() as OrderRow[];
      return new Response(JSON.stringify(rows.map(mapOrder)), { headers: { 'Content-Type': 'application/json' } });
    }
    // GET /bot/orders/:id
    const orderIdMatch = url.pathname.match(/^\/bot\/orders\/([^\/]+)$/);
    if (orderIdMatch && request.method === 'GET') {
      const r = await sb(`/orders?id=eq.${orderIdMatch[1]}`);
      const rows = await r.json() as OrderRow[];
      if (!rows.length) return new Response('Not found', { status: 404 });
      return new Response(JSON.stringify(mapOrder(rows[0])), { headers: { 'Content-Type': 'application/json' } });
    }
    // POST /bot/orders/:id/confirm-payment （iOS から支払確認 → 対価を自動送信）
    const orderPayMatch = url.pathname.match(/^\/bot\/orders\/([^\/]+)\/confirm-payment$/);
    if (orderPayMatch && request.method === 'POST') {
      try {
        const id = orderPayMatch[1];
        const or = await sb(`/orders?id=eq.${id}`); const orders = await or.json() as OrderRow[];
        if (!orders.length) return new Response('Not found', { status: 404 });
        const order = orders[0];
        if (order.status !== 'open') return new Response(JSON.stringify({ error: 'Not open' }), { status: 400 });
        const pr = await sb(`/products?id=eq.${order.product_id}`); const products = await pr.json() as ProductRow[];
        const shr = await sb(`/shops?id=eq.${order.shop_id}`);       const shopArr  = await shr.json() as ShopRow[];
        if (!products.length || !shopArr.length) return new Response('Data not found', { status: 404 });
        // 対価を送信
        await deliverReward(order, products[0], shopArr[0], env);
        // ステータス更新: paid → delivered
        const now = new Date().toISOString();
        await sb(`/orders?id=eq.${id}`, { method: 'PATCH', body: JSON.stringify({ status: 'delivered', paid_at: now, delivered_at: now }) });
        // チャンネルに通知
        if (order.channel_id) {
          await fetch(`https://discord.com/api/v10/channels/${order.channel_id}/messages`, {
            method: 'POST', headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({ embeds: [{ title: '✅ 支払いが確認されました', description: '対価を送信しました。受け取りを確認して「取引完了」を押してください。', color: 0x10b981, timestamp: now }] }),
          });
        }
        const upR = await sb(`/orders?id=eq.${id}`); const upRows = await upR.json() as OrderRow[];
        return new Response(JSON.stringify(mapOrder(upRows[0])), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }
    // POST /bot/orders/:id/complete { party: 'buyer'|'seller' }
    const orderCompleteMatch = url.pathname.match(/^\/bot\/orders\/([^\/]+)\/complete$/);
    if (orderCompleteMatch && request.method === 'POST') {
      try {
        const id   = orderCompleteMatch[1];
        const body = await request.json() as { party: 'buyer' | 'seller' };
        const or   = await sb(`/orders?id=eq.${id}`); const orders = await or.json() as OrderRow[];
        if (!orders.length) return new Response('Not found', { status: 404 });
        const order = orders[0];
        const update: Record<string, unknown> = {};
        if (body.party === 'buyer')  update['buyer_confirmed']  = true;
        if (body.party === 'seller') update['seller_confirmed'] = true;
        await sb(`/orders?id=eq.${id}`, { method: 'PATCH', body: JSON.stringify(update) });
        const upR = await sb(`/orders?id=eq.${id}`); const upRows = await upR.json() as OrderRow[];
        const updated = upRows[0];
        // 双方確認済みなら完了処理
        if (updated.buyer_confirmed && updated.seller_confirmed) {
          const shr = await sb(`/shops?id=eq.${order.shop_id}`); const shopArr = await shr.json() as ShopRow[];
          const shop = shopArr[0];
          await sb(`/orders?id=eq.${id}`, { method: 'PATCH', body: JSON.stringify({ status: 'completed', completed_at: new Date().toISOString() }) });
          if (order.channel_id) await archiveOrderChannel(order.channel_id, order.buyer_user_id, shop?.archive_category_id ?? null, env);
        }
        const finalR = await sb(`/orders?id=eq.${id}`); const finalRows = await finalR.json() as OrderRow[];
        return new Response(JSON.stringify(mapOrder(finalRows[0])), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // ── モデレーション ────────────────────────────────────────────

    // GET /bot/timeouts?guild_id=  タイムアウト中のメンバー一覧
    if (url.pathname === '/bot/timeouts' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });
      const resp = await fetch(`https://discord.com/api/v10/guilds/${guildId}/members?limit=1000`, {
        headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
      });
      if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
      const members = await resp.json() as any[];
      const now = new Date().toISOString();
      const timedOut = members
        .filter((m: any) => m.communication_disabled_until && m.communication_disabled_until > now)
        .map((m: any) => ({
          id:           m.user.id,
          username:     m.user.username,
          displayName:  m.nick ?? m.user.global_name ?? m.user.username,
          avatarUrl:    m.user.avatar
            ? `https://cdn.discordapp.com/avatars/${m.user.id}/${m.user.avatar}.png`
            : null,
          timeoutUntil: m.communication_disabled_until,
          mutedByName:  "モデレーター",
        }));
      return new Response(JSON.stringify(timedOut), { headers: { 'Content-Type': 'application/json' } });
    }

    // GET /bot/bans?guild_id=  BAN一覧
    if (url.pathname === '/bot/bans' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });
      const resp = await fetch(`https://discord.com/api/v10/guilds/${guildId}/bans?limit=1000`, {
        headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
      });
      if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
      return new Response(JSON.stringify(await resp.json()), { headers: { 'Content-Type': 'application/json' } });
    }

    // DELETE /bot/bans/:userId?guild_id=  アンBAN
    const unbanMatch = url.pathname.match(/^\/bot\/bans\/([^\/]+)$/);
    if (unbanMatch && request.method === 'DELETE') {
      const userId = unbanMatch[1];
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });
      const resp = await fetch(`https://discord.com/api/v10/guilds/${guildId}/bans/${userId}`, {
        method: 'DELETE',
        headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
      });
      if (!resp.ok && resp.status !== 204) return new Response(await resp.text(), { status: resp.status });
      return new Response(JSON.stringify({ success: true }), { headers: { 'Content-Type': 'application/json' } });
    }

    // PATCH /bot/members/:userId/untimeout  タイムアウト解除
    const untimeoutMatch = url.pathname.match(/^\/bot\/members\/([^\/]+)\/untimeout$/);
    if (untimeoutMatch && request.method === 'PATCH') {
      try {
        const userId = untimeoutMatch[1];
        const body = await request.json() as { guildId: string };
        const resp = await fetch(`https://discord.com/api/v10/guilds/${body.guildId}/members/${userId}`, {
          method: 'PATCH',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ communication_disabled_until: null }),
        });
        if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
        return new Response(JSON.stringify({ success: true }), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // GET /bot/warnings?guild_id=&user_id=  警告一覧
    if (url.pathname === '/bot/warnings' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      const userId  = url.searchParams.get('user_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });
      let query = `/mod_warnings?guild_id=eq.${guildId}&order=created_at.desc`;
      if (userId) query += `&user_id=eq.${userId}`;
      const resp = await sb(query);
      if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
      return new Response(JSON.stringify(await resp.json()), { headers: { 'Content-Type': 'application/json' } });
    }

    // POST /bot/warnings  警告追加（自動アクション付き）
    if (url.pathname === '/bot/warnings' && request.method === 'POST') {
      try {
        const body = await request.json() as {
          guildId: string; userId: string; username: string; displayName: string;
          reason: string; staffId: string; staffName: string; autoAction?: string;
        };
        const insertResp = await sb('/mod_warnings', {
          method: 'POST',
          body: JSON.stringify({
            guild_id: body.guildId, user_id: body.userId, username: body.username,
            display_name: body.displayName, reason: body.reason,
            staff_id: body.staffId, staff_name: body.staffName, is_revoked: false,
          }),
          headers: { Prefer: 'return=representation' },
        });
        if (!insertResp.ok) return new Response(await insertResp.text(), { status: insertResp.status });

        // 自動アクション
        if (body.autoAction === 'ban') {
          await fetch(`https://discord.com/api/v10/guilds/${body.guildId}/bans/${body.userId}`, {
            method: 'PUT',
            headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({ delete_message_seconds: 0 }),
          });
        } else if (body.autoAction?.startsWith('timeout_')) {
          const hours = body.autoAction === 'timeout_1h' ? 1 : 24;
          const until = new Date(Date.now() + hours * 3600 * 1000).toISOString();
          await fetch(`https://discord.com/api/v10/guilds/${body.guildId}/members/${body.userId}`, {
            method: 'PATCH',
            headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({ communication_disabled_until: until }),
          });
        }

        // DM通知
        try {
          const dmCh = await fetch('https://discord.com/api/v10/users/@me/channels', {
            method: 'POST',
            headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({ recipient_id: body.userId }),
          });
          if (dmCh.ok) {
            const { id: dmId } = await dmCh.json() as { id: string };
            await fetch(`https://discord.com/api/v10/channels/${dmId}/messages`, {
              method: 'POST',
              headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
              body: JSON.stringify({
                embeds: [{
                  title: '⚠️ 警告を受け取りました',
                  description: `**理由:** ${body.reason}\n**スタッフ:** ${body.staffName}\n\n警告が蓄積されると、タイムアウト・キック・BANなどの自動アクションが実行される場合があります。`,
                  color: 0xF59E0B,
                  timestamp: new Date().toISOString(),
                }],
              }),
            });
          }
        } catch { /* DM送信失敗は無視 */ }

        const rows = await insertResp.json() as Record<string, unknown>[];
        return new Response(JSON.stringify(rows[0]), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // PATCH /bot/warnings/:id/revoke  警告取り消し
    const warnRevokeMatch = url.pathname.match(/^\/bot\/warnings\/([^\/]+)\/revoke$/);
    if (warnRevokeMatch && request.method === 'PATCH') {
      const id = warnRevokeMatch[1];
      await sb(`/mod_warnings?id=eq.${id}`, { method: 'PATCH', body: JSON.stringify({ is_revoked: true }) });
      return new Response(JSON.stringify({ success: true }), { headers: { 'Content-Type': 'application/json' } });
    }

    // ── ロール管理 ────────────────────────────────────────────────

    // PATCH /bot/roles/reorder  ロール並び替え
    if (url.pathname === '/bot/roles/reorder' && request.method === 'PATCH') {
      try {
        const body = await request.json() as { guildId: string; positions: Array<{ id: string; position: number }> };
        const resp = await fetch(`https://discord.com/api/v10/guilds/${body.guildId}/roles`, {
          method: 'PATCH',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify(body.positions),
        });
        if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
        return new Response(JSON.stringify(await resp.json()), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // POST /bot/roles  ロール作成
    if (url.pathname === '/bot/roles' && request.method === 'POST') {
      try {
        const body = await request.json() as { guildId: string; name?: string; color?: number; permissions?: string };
        const resp = await fetch(`https://discord.com/api/v10/guilds/${body.guildId}/roles`, {
          method: 'POST',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            name:        body.name        ?? '新しいロール',
            color:       body.color       ?? 0,
            permissions: body.permissions ?? '0',
          }),
        });
        if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
        return new Response(JSON.stringify(await resp.json()), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // PATCH /bot/roles/:roleId  ロール更新（名前・色・権限）
    const rolePatchMatch = url.pathname.match(/^\/bot\/roles\/([^\/]+)$/);
    if (rolePatchMatch && request.method === 'PATCH') {
      const roleId = rolePatchMatch[1];
      try {
        const body = await request.json() as { guildId: string; name?: string; color?: number; permissions?: string };
        const patch: Record<string, unknown> = {};
        if (body.name        !== undefined) patch.name        = body.name;
        if (body.color       !== undefined) patch.color       = body.color;
        if (body.permissions !== undefined) patch.permissions = body.permissions;
        const resp = await fetch(`https://discord.com/api/v10/guilds/${body.guildId}/roles/${roleId}`, {
          method: 'PATCH',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify(patch),
        });
        if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
        return new Response(JSON.stringify(await resp.json()), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // DELETE /bot/roles/:roleId  ロール削除
    const roleDeleteMatch = url.pathname.match(/^\/bot\/roles\/([^\/]+)$/);
    if (roleDeleteMatch && request.method === 'DELETE') {
      const roleId = roleDeleteMatch[1];
      try {
        const guildId = url.searchParams.get('guild_id');
        if (!guildId) return new Response('Missing guild_id', { status: 400 });
        const resp = await fetch(`https://discord.com/api/v10/guilds/${guildId}/roles/${roleId}`, {
          method: 'DELETE',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
        });
        if (!resp.ok && resp.status !== 204) return new Response(await resp.text(), { status: resp.status });
        return new Response(JSON.stringify({ success: true }), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // ── AutoMod設定 ────────────────────────────────────────────────

    // GET /bot/automod-settings?guild_id=xxx
    if (url.pathname === '/bot/automod-settings' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });
      const resp = await sb(`/automod_settings?guild_id=eq.${guildId}`);
      if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
      const rows = await resp.json() as Record<string, unknown>[];
      if (!rows.length) {
        return new Response(JSON.stringify({
          guildId,
          msgSpamEnabled: true, msgSpamCount: 5, msgSpamSeconds: 5,
          dupMsgEnabled: false, dupMsgCount: 3,
          mentionEnabled: true, mentionLimit: 5,
          massMentionEnabled: true, massMentionLimit: 3,
          emojiEnabled: false, emojiLimit: 10,
          capsEnabled: true, capsPercent: 70,
          keywordEnabled: true, blockedKeywords: [],
          regexEnabled: false, blockedRegex: [],
          inviteLinkEnabled: true, phishingEnabled: true,
          linkFilterEnabled: false, linkMode: 'allowAll', allowedLinks: [],
          nsfwEnabled: false,
          minAgeEnabled: false, minAgeDays: 7,
          newMemberEnabled: false, newMemberMins: 10,
          raidEnabled: false, raidJoins: 10, raidSeconds: 30,
          antiNukeEnabled: false,
          channelDeleteLimit: 3, channelDeleteSeconds: 10,
          roleDeleteLimit: 3, roleDeleteSeconds: 10,
          massBanLimit: 5, massBanSeconds: 30,
          defaultAction: 'deleteAndWarn', timeoutMinutes: 60,
          escalationEnabled: true, escalationSteps: [
            { violations: 3, action: { type: 'timeout', minutes: 10 } },
            { violations: 5, action: { type: 'timeout', minutes: 60 } },
            { violations: 10, action: { type: 'kick' } },
            { violations: 15, action: { type: 'ban' } },
          ],
          logEnabled: true, logChannelId: '',
          exemptRoles: ['管理者', 'モデレーター'], exemptChannels: [],
        }), { headers: { 'Content-Type': 'application/json' } });
      }
      const r = rows[0];
      return new Response(JSON.stringify({
        id: r['id'], guildId: r['guild_id'],
        msgSpamEnabled: r['msg_spam_enabled'], msgSpamCount: r['msg_spam_count'], msgSpamSeconds: r['msg_spam_seconds'],
        dupMsgEnabled: r['dup_msg_enabled'], dupMsgCount: r['dup_msg_count'],
        mentionEnabled: r['mention_enabled'], mentionLimit: r['mention_limit'],
        massMentionEnabled: r['mass_mention_enabled'], massMentionLimit: r['mass_mention_limit'],
        emojiEnabled: r['emoji_enabled'], emojiLimit: r['emoji_limit'],
        capsEnabled: r['caps_enabled'], capsPercent: r['caps_percent'],
        keywordEnabled: r['keyword_enabled'], blockedKeywords: r['blocked_keywords'] ?? [],
        regexEnabled: r['regex_enabled'], blockedRegex: r['blocked_regex'] ?? [],
        inviteLinkEnabled: r['invite_link_enabled'], phishingEnabled: r['phishing_enabled'],
        linkFilterEnabled: r['link_filter_enabled'], linkMode: r['link_mode'], allowedLinks: r['allowed_links'] ?? [],
        nsfwEnabled: r['nsfw_enabled'],
        minAgeEnabled: r['min_age_enabled'], minAgeDays: r['min_age_days'],
        newMemberEnabled: r['new_member_enabled'], newMemberMins: r['new_member_mins'],
        raidEnabled: r['raid_enabled'], raidJoins: r['raid_joins'], raidSeconds: r['raid_seconds'],
        antiNukeEnabled: r['anti_nuke_enabled'],
        channelDeleteLimit: r['channel_delete_limit'], channelDeleteSeconds: r['channel_delete_seconds'],
        roleDeleteLimit: r['role_delete_limit'], roleDeleteSeconds: r['role_delete_seconds'],
        massBanLimit: r['mass_ban_limit'], massBanSeconds: r['mass_ban_seconds'],
        defaultAction: r['default_action'], timeoutMinutes: r['timeout_minutes'],
        escalationEnabled: r['escalation_enabled'], escalationSteps: r['escalation_steps'] ?? [],
        logEnabled: r['log_enabled'], logChannelId: r['log_channel_id'],
        exemptRoles: r['exempt_roles'] ?? [], exemptChannels: r['exempt_channels'] ?? [],
        createdAt: r['created_at'], updatedAt: r['updated_at'],
      }), { headers: { 'Content-Type': 'application/json' } });
    }

    // POST /bot/automod-settings (upsert)
    if (url.pathname === '/bot/automod-settings' && request.method === 'POST') {
      try {
        const body = await request.json() as Record<string, unknown>;
        const checkResp = await sb(`/automod_settings?guild_id=eq.${body['guildId']}`);
        const checkRows = await checkResp.json() as Record<string, unknown>[];

        const camelToSnake: Record<string, string> = {
          guildId: 'guild_id', msgSpamEnabled: 'msg_spam_enabled', msgSpamCount: 'msg_spam_count',
          msgSpamSeconds: 'msg_spam_seconds', dupMsgEnabled: 'dup_msg_enabled', dupMsgCount: 'dup_msg_count',
          mentionEnabled: 'mention_enabled', mentionLimit: 'mention_limit',
          massMentionEnabled: 'mass_mention_enabled', massMentionLimit: 'mass_mention_limit',
          emojiEnabled: 'emoji_enabled', emojiLimit: 'emoji_limit',
          capsEnabled: 'caps_enabled', capsPercent: 'caps_percent',
          keywordEnabled: 'keyword_enabled', blockedKeywords: 'blocked_keywords',
          regexEnabled: 'regex_enabled', blockedRegex: 'blocked_regex',
          inviteLinkEnabled: 'invite_link_enabled', phishingEnabled: 'phishing_enabled',
          linkFilterEnabled: 'link_filter_enabled', linkMode: 'link_mode', allowedLinks: 'allowed_links',
          nsfwEnabled: 'nsfw_enabled',
          minAgeEnabled: 'min_age_enabled', minAgeDays: 'min_age_days',
          newMemberEnabled: 'new_member_enabled', newMemberMins: 'new_member_mins',
          raidEnabled: 'raid_enabled', raidJoins: 'raid_joins', raidSeconds: 'raid_seconds',
          antiNukeEnabled: 'anti_nuke_enabled',
          channelDeleteLimit: 'channel_delete_limit', channelDeleteSeconds: 'channel_delete_seconds',
          roleDeleteLimit: 'role_delete_limit', roleDeleteSeconds: 'role_delete_seconds',
          massBanLimit: 'mass_ban_limit', massBanSeconds: 'mass_ban_seconds',
          defaultAction: 'default_action', timeoutMinutes: 'timeout_minutes',
          escalationEnabled: 'escalation_enabled', escalationSteps: 'escalation_steps',
          logEnabled: 'log_enabled', logChannelId: 'log_channel_id',
          exemptRoles: 'exempt_roles', exemptChannels: 'exempt_channels',
        };

        const upsertData: Record<string, unknown> = { updated_at: new Date().toISOString() };
        for (const [k, v] of Object.entries(body)) {
          const snakeKey = camelToSnake[k] ?? k;
          upsertData[snakeKey] = v;
        }

        let resp: Response;
        if (checkRows.length > 0) {
          resp = await sb(`/automod_settings?id=eq.${checkRows[0]['id']}`, {
            method: 'PATCH', body: JSON.stringify(upsertData), headers: { Prefer: 'return=representation' },
          });
        } else {
          resp = await sb('/automod_settings', {
            method: 'POST', body: JSON.stringify(upsertData), headers: { Prefer: 'return=representation' },
          });
        }

        if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
        const rows = await resp.json() as Record<string, unknown>[];
        const r = rows[0];
        return new Response(JSON.stringify({ id: r['id'], guildId: r['guild_id'], updatedAt: r['updated_at'] }), {
          headers: { 'Content-Type': 'application/json' },
        });
      } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500 }); }
    }

    // ── 最近のアクティビティ ────────────────────────────────────────

    // GET /bot/recent-activity?guild_id=xxx
    if (url.pathname === '/bot/recent-activity' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });

      const [ticketsResp, ordersResp] = await Promise.all([
        sb(`/tickets?guild_id=eq.${guildId}&order=opened_at.desc&limit=5`),
        sb(`/orders?guild_id=eq.${guildId}&order=created_at.desc&limit=5`),
      ]);

      type Activity = { type: string; icon: string; text: string; timeAgo: string; ticketId?: string; referenceId?: string };
      const activities: Activity[] = [];

      if (ticketsResp.ok) {
        const tickets = await ticketsResp.json() as any[];
        for (const t of tickets) {
          const mins = Math.floor((Date.now() - new Date(t.opened_at).getTime()) / 60000);
          const timeStr = mins < 60 ? `${mins}分前` : mins < 1440 ? `${Math.floor(mins/60)}時間前` : `${Math.floor(mins/1440)}日前`;
          activities.push({ type: 'ticket', icon: 'ticket.fill', text: `チケット「${t.subject}」が作成されました`, timeAgo: timeStr, ticketId: t.id });
        }
      }

      if (ordersResp.ok) {
        const orders = await ordersResp.json() as any[];
        for (const o of orders) {
          const mins = Math.floor((Date.now() - new Date(o.created_at).getTime()) / 60000);
          const timeStr = mins < 60 ? `${mins}分前` : mins < 1440 ? `${Math.floor(mins/60)}時間前` : `${Math.floor(mins/1440)}日前`;
          activities.push({ type: 'order', icon: 'cart.fill', text: `注文: ${o.product_name} (${o.status})`, timeAgo: timeStr, referenceId: o.id });
        }
      }

      activities.sort((a, b) => {
        const parseTime = (s: string) => {
          const num = parseInt(s);
          if (s.includes('分')) return num;
          if (s.includes('時間')) return num * 60;
          if (s.includes('日')) return num * 1440;
          return 999999;
        };
        return parseTime(a.timeAgo) - parseTime(b.timeAgo);
      });

      return new Response(JSON.stringify(activities.slice(0, 10)), { headers: { 'Content-Type': 'application/json' } });
    }

    // ── モニターアクティビティログ ──────────────────────────────────

    // GET /bot/monitor-activity?guild_id=xxx&type=all|errors|commands|automation
    if (url.pathname === '/bot/monitor-activity' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });
      const typeFilter = url.searchParams.get('type') ?? 'all';

      const activities: Array<{type: string; icon: string; title: string; detail: string; guildName: string; timeAgo: string; isError: boolean}> = [];

      // チケット作成
      const ticketsResp = await sb(`/tickets?guild_id=eq.${guildId}&order=opened_at.desc&limit=20`);
      if (ticketsResp.ok) {
        const tickets = await ticketsResp.json() as any[];
        for (const t of tickets) {
          const mins = Math.floor((Date.now() - new Date(t.opened_at).getTime()) / 60000);
          const timeStr = mins < 1 ? 'たった今' : mins < 60 ? `${mins}分前` : mins < 1440 ? `${Math.floor(mins/60)}時間前` : `${Math.floor(mins/1440)}日前`;
          activities.push({ type: 'command', icon: 'terminal.fill', title: '/ticket create', detail: `チケット「${t.subject}」`, guildName: '', timeAgo: timeStr, isError: false });
        }
      }

      // 注文
      const ordersResp = await sb(`/orders?guild_id=eq.${guildId}&order=created_at.desc&limit=20`);
      if (ordersResp.ok) {
        const orders = await ordersResp.json() as any[];
        for (const o of orders) {
          const mins = Math.floor((Date.now() - new Date(o.created_at).getTime()) / 60000);
          const timeStr = mins < 1 ? 'たった今' : mins < 60 ? `${mins}分前` : mins < 1440 ? `${Math.floor(mins/60)}時間前` : `${Math.floor(mins/1440)}日前`;
          activities.push({ type: 'automation', icon: 'cart.fill', title: '新規注文', detail: `${o.product_name} — ${o.status}`, guildName: '', timeAgo: timeStr, isError: o.status === 'cancelled' });
        }
      }

      // 警告
      const warningsResp = await sb(`/mod_warnings?guild_id=eq.${guildId}&order=created_at.desc&limit=20`);
      if (warningsResp.ok) {
        const warnings = await warningsResp.json() as any[];
        for (const w of warnings) {
          const mins = Math.floor((Date.now() - new Date(w.created_at).getTime()) / 60000);
          const timeStr = mins < 1 ? 'たった今' : mins < 60 ? `${mins}分前` : mins < 1440 ? `${Math.floor(mins/60)}時間前` : `${Math.floor(mins/1440)}日前`;
          activities.push({ type: 'moderation', icon: w.is_revoked ? 'checkmark.circle' : 'exclamationmark.triangle.fill', title: w.is_revoked ? '警告取り消し' : '警告追加', detail: `${w.display_name} — ${w.reason}`, guildName: '', timeAgo: timeStr, isError: false });
        }
      }

      activities.sort((a, b) => {
        const parseTime = (s: string) => {
          if (s === 'たった今') return 0;
          const num = parseInt(s);
          if (s.includes('分')) return num;
          if (s.includes('時間')) return num * 60;
          if (s.includes('日')) return num * 1440;
          return 999999;
        };
        return parseTime(a.timeAgo) - parseTime(b.timeAgo);
      });

      let filtered = activities;
      if (typeFilter === 'errors') filtered = activities.filter(a => a.isError);
      else if (typeFilter === 'commands') filtered = activities.filter(a => a.type === 'command');
      else if (typeFilter === 'automation') filtered = activities.filter(a => a.type === 'automation');

      return new Response(JSON.stringify(filtered.slice(0, 30)), { headers: { 'Content-Type': 'application/json' } });
    }

    // ── アナリティクス (#7) GET /bot/analytics?guild_id=xxx ─────────────
    if (url.pathname === '/bot/analytics' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });

      // Discord からギルド情報を取得（メンバー数）
      const guildResp = await fetch(`https://discord.com/api/v10/guilds/${guildId}?with_counts=true`, {
        headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
      });
      const guildData = guildResp.ok ? await guildResp.json() as any : null;
      const totalMembers: number = guildData?.approximate_member_count ?? 0;

      // アクティブチケット数
      const ticketsResp = await sb(`/tickets?guild_id=eq.${guildId}&status=eq.open`);
      const tickets: any[] = ticketsResp.ok ? await ticketsResp.json() : [];
      const activeTickets = tickets.length;

      // 今日の注文数
      const todayStr = new Date().toISOString().split('T')[0];
      const ordersResp = await sb(`/orders?guild_id=eq.${guildId}&created_at=gte.${todayStr}T00:00:00Z`);
      const todayOrders: any[] = ordersResp.ok ? await ordersResp.json() : [];

      // 過去7日間の日別チケット数（メッセージ履歴の代替）
      const messageHistory: number[] = [];
      const memberHistory: number[] = Array(7).fill(totalMembers);
      for (let d = 6; d >= 0; d--) {
        const dayStart = new Date(Date.now() - d * 86400000);
        const dayEnd   = new Date(Date.now() - (d - 1) * 86400000);
        const r = await sb(`/tickets?guild_id=eq.${guildId}&opened_at=gte.${dayStart.toISOString()}&opened_at=lt.${dayEnd.toISOString()}`);
        const dayTickets: any[] = r.ok ? await r.json() : [];
        messageHistory.push(dayTickets.length);
      }

      return new Response(JSON.stringify({
        guildId,
        totalMembers,
        memberGrowthPercent:  0,
        messagesToday:        todayOrders.length,
        messageGrowthPercent: 0,
        commandsUsed:         0,
        commandGrowthPercent: 0,
        activeTickets,
        voiceMinutes:         0,
        memberHistory,
        messageHistory,
      }), { headers: { 'Content-Type': 'application/json' } });
    }

    // ── 自動応答 CRUD (#8) ──────────────────────────────────────────

    // GET /bot/auto-responses?guild_id=xxx
    if (url.pathname === '/bot/auto-responses' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });
      const resp = await sb(`/auto_responses?guild_id=eq.${guildId}&order=created_at.asc`);
      if (!resp.ok) return new Response('Supabase error', { status: 500 });
      const rows: any[] = await resp.json();
      return new Response(JSON.stringify(rows.map(mapAutoResponse)), { headers: { 'Content-Type': 'application/json' } });
    }

    // POST /bot/auto-responses
    if (url.pathname === '/bot/auto-responses' && request.method === 'POST') {
      const body = await request.json() as any;
      const data = {
        guild_id:     body.guildId,
        trigger_type: triggerTypeToDB[body.matchType] ?? 'contains',
        trigger:      body.trigger,
        response:     body.response,
        is_enabled:   body.enabled ?? true,
        cooldown_sec: body.cooldownSeconds ?? 0,
        channel_ids:  body.channelIds ?? [],
      };
      const resp = await sb('/auto_responses', {
        method: 'POST',
        headers: { Prefer: 'return=representation' },
        body: JSON.stringify(data),
      });
      if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
      const rows: any[] = await resp.json();
      return new Response(JSON.stringify(mapAutoResponse(rows[0])), { status: 201, headers: { 'Content-Type': 'application/json' } });
    }

    // PATCH /bot/auto-responses/:id
    const arPatchMatch = url.pathname.match(/^\/bot\/auto-responses\/([^/]+)$/);
    if (arPatchMatch && request.method === 'PATCH') {
      const id = arPatchMatch[1];
      const body = await request.json() as any;
      const patch: Record<string, any> = {};
      if (body.trigger      !== undefined) patch.trigger      = body.trigger;
      if (body.response     !== undefined) patch.response     = body.response;
      if (body.matchType    !== undefined) patch.trigger_type = triggerTypeToDB[body.matchType] ?? 'contains';
      if (body.enabled      !== undefined) patch.is_enabled   = body.enabled;
      if (body.cooldownSeconds !== undefined) patch.cooldown_sec = body.cooldownSeconds;
      if (body.channelIds   !== undefined) patch.channel_ids  = body.channelIds;
      const resp = await sb(`/auto_responses?id=eq.${id}`, {
        method: 'PATCH',
        headers: { Prefer: 'return=representation' },
        body: JSON.stringify(patch),
      });
      if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
      const rows: any[] = await resp.json();
      return new Response(JSON.stringify(mapAutoResponse(rows[0])), { headers: { 'Content-Type': 'application/json' } });
    }

    // DELETE /bot/auto-responses/:id
    const arDeleteMatch = url.pathname.match(/^\/bot\/auto-responses\/([^/]+)$/);
    if (arDeleteMatch && request.method === 'DELETE') {
      const id = arDeleteMatch[1];
      const resp = await sb(`/auto_responses?id=eq.${id}`, { method: 'DELETE' });
      return new Response(JSON.stringify({ ok: resp.ok }), { headers: { 'Content-Type': 'application/json' } });
    }

    // POST /bot/auto-responses/:id/toggle
    const arToggleMatch = url.pathname.match(/^\/bot\/auto-responses\/([^/]+)\/toggle$/);
    if (arToggleMatch && request.method === 'POST') {
      const id = arToggleMatch[1];
      const body = await request.json() as any;
      const resp = await sb(`/auto_responses?id=eq.${id}`, {
        method: 'PATCH',
        headers: { Prefer: 'return=representation' },
        body: JSON.stringify({ is_enabled: body.enabled ?? true }),
      });
      if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
      const rows: any[] = await resp.json();
      return new Response(JSON.stringify(mapAutoResponse(rows[0])), { headers: { 'Content-Type': 'application/json' } });
    }

    // ── ステータスチャンネル CRUD ────────────────────────────────

    // GET /bot/stat-channels?guild_id=xxx
    if (url.pathname === '/bot/stat-channels' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });
      const resp = await sb(`/stat_channels?guild_id=eq.${guildId}&order=created_at.asc`);
      if (!resp.ok) return new Response('Supabase error', { status: 500 });
      const rows: StatChannelRow[] = await resp.json();
      return new Response(JSON.stringify(rows.map(mapStatChannel)), { headers: { 'Content-Type': 'application/json' } });
    }

    // POST /bot/stat-channels  → Discord VCチャンネル作成 + DB登録
    if (url.pathname === '/bot/stat-channels' && request.method === 'POST') {
      const body = await request.json() as { guildId?: string; guild_id?: string; statType?: StatType; stat_type?: StatType; categoryId?: string; category_id?: string };
      const guildId = body.guild_id ?? body.guildId ?? '';
      const statType = (body.stat_type ?? body.statType) as StatType;
      const categoryId = body.category_id ?? body.categoryId;

      // 課金済みサーバーのみ作成を許可
      const activatedCheckResp = await sb(`/activated_servers?guild_id=eq.${guildId}&select=id`);
      const activatedCheck: any[] = activatedCheckResp.ok ? await activatedCheckResp.json() : [];
      if (activatedCheck.length === 0) {
        return new Response(JSON.stringify({ error: 'Server not activated. Please subscribe first.' }), {
          status: 402, headers: { 'Content-Type': 'application/json' },
        });
      }

      // チャンネル名の初期値を生成
      const initialName = statChannelLabel(statType, 0);

      // Discord にボイスチャンネルを作成
      const createBody: Record<string, any> = {
        name:  initialName,
        type:  2, // GUILD_VOICE
        permission_overwrites: [
          // @everyone: 見える・入れない
          { id: guildId, type: 0, allow: '1024', deny: '1048576' },
        ],
      };
      if (categoryId) createBody.parent_id = categoryId;

      const chResp = await fetch(`https://discord.com/api/v10/guilds/${guildId}/channels`, {
        method: 'POST',
        headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(createBody),
      });
      if (!chResp.ok) {
        const err = await chResp.text();
        return new Response(JSON.stringify({ error: `Discord API: ${err}` }), { status: chResp.status });
      }
      const channel = await chResp.json() as { id: string };

      // Supabase に登録
      const insertResp = await sb('/stat_channels', {
        method: 'POST',
        headers: { Prefer: 'return=representation' },
        body: JSON.stringify({ guild_id: guildId, channel_id: channel.id, stat_type: statType, is_enabled: true, last_value: -1 }),
      });
      if (!insertResp.ok) return new Response(await insertResp.text(), { status: insertResp.status });
      const rows: StatChannelRow[] = await insertResp.json();
      return new Response(JSON.stringify(mapStatChannel(rows[0])), { status: 201, headers: { 'Content-Type': 'application/json' } });
    }

    // PATCH /bot/stat-channels/:id/toggle
    const scToggleMatch = url.pathname.match(/^\/bot\/stat-channels\/([^/]+)\/toggle$/);
    if (scToggleMatch && request.method === 'PATCH') {
      const id = scToggleMatch[1];
      const body = await request.json() as { enabled: boolean };
      const resp = await sb(`/stat_channels?id=eq.${id}`, {
        method: 'PATCH',
        headers: { Prefer: 'return=representation' },
        body: JSON.stringify({ is_enabled: body.enabled }),
      });
      if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
      const rows: StatChannelRow[] = await resp.json();
      return new Response(JSON.stringify(mapStatChannel(rows[0])), { headers: { 'Content-Type': 'application/json' } });
    }

    // DELETE /bot/stat-channels/:id  → Discord チャンネル削除 + DB削除
    const scDeleteMatch = url.pathname.match(/^\/bot\/stat-channels\/([^/]+)$/);
    if (scDeleteMatch && request.method === 'DELETE') {
      const id = scDeleteMatch[1];
      // DBからチャンネルIDを取得
      const getResp = await sb(`/stat_channels?id=eq.${id}`);
      const rows: StatChannelRow[] = getResp.ok ? await getResp.json() : [];
      if (rows.length > 0) {
        // Discord チャンネルを削除
        await fetch(`https://discord.com/api/v10/channels/${rows[0].channel_id}`, {
          method: 'DELETE',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
        }).catch(() => {});
      }
      await sb(`/stat_channels?id=eq.${id}`, { method: 'DELETE' });
      return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
    }

    // POST /bot/stat-channels/:id/refresh  → 即時更新
    const scRefreshMatch = url.pathname.match(/^\/bot\/stat-channels\/([^/]+)\/refresh$/);
    if (scRefreshMatch && request.method === 'POST') {
      const id = scRefreshMatch[1];
      const getResp = await sb(`/stat_channels?id=eq.${id}`);
      const rows: StatChannelRow[] = getResp.ok ? await getResp.json() : [];
      if (rows.length === 0) return new Response('Not found', { status: 404 });
      await updateSingleStatChannel(rows[0], env);
      return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
    }

    // ── Invite Tracker ────────────────────────────────────────────────

    // GET /bot/invite-tracker/leaderboard?guild_id=xxx&period=xxx
    if (url.pathname === '/bot/invite-tracker/leaderboard' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      const period  = url.searchParams.get('period') ?? 'all_time';
      if (!guildId) return new Response('Missing guild_id', { status: 400 });

      let filter = `guild_id=eq.${guildId}`;
      if (period === 'today') {
        const since = new Date(); since.setHours(0, 0, 0, 0);
        filter += `&joined_since=gte.${since.toISOString()}`;
      } else if (period === 'week') {
        const since = new Date(); since.setDate(since.getDate() - 7);
        filter += `&joined_since=gte.${since.toISOString()}`;
      } else if (period === 'month') {
        const since = new Date(); since.setMonth(since.getMonth() - 1);
        filter += `&joined_since=gte.${since.toISOString()}`;
      }

      const resp = await sb(`/invite_stats?${filter}&order=valid_invites.desc&limit=50`);
      if (!resp.ok) return new Response('Supabase error', { status: 500 });
      const rows: any[] = await resp.json();
      return new Response(JSON.stringify(rows.map((r, i) => ({ ...r, rank: i + 1,
        userId: r.user_id, guildId: r.guild_id, displayName: r.display_name,
        avatarUrl: r.avatar_url, totalInvites: r.total_invites, validInvites: r.valid_invites,
        leftInvites: r.left_invites, fakeInvites: r.fake_invites, influenceScore: r.influence_score,
        treeSize: r.tree_size, retentionRate: r.retention_rate,
      }))), { headers: { 'Content-Type': 'application/json' } });
    }

    // GET /bot/invite-tracker/member?guild_id=xxx&user_id=xxx
    if (url.pathname === '/bot/invite-tracker/member' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      const userId  = url.searchParams.get('user_id');
      if (!guildId || !userId) return new Response('Missing params', { status: 400 });

      const [statsResp, eventsResp, parentResp] = await Promise.all([
        sb(`/invite_stats?guild_id=eq.${guildId}&user_id=eq.${userId}`),
        sb(`/invite_events?guild_id=eq.${guildId}&inviter_user_id=eq.${userId}&order=joined_at.desc&limit=20`),
        sb(`/invite_events?guild_id=eq.${guildId}&invitee_user_id=eq.${userId}&limit=1`),
      ]);

      const stats: any[] = statsResp.ok ? await statsResp.json() : [];
      const events: any[] = eventsResp.ok ? await eventsResp.json() : [];
      const parents: any[] = parentResp.ok ? await parentResp.json() : [];

      const statsRow = stats[0];
      const parentRow = parents[0];

      return new Response(JSON.stringify({
        stats: statsRow ? {
          userId: statsRow.user_id, guildId: statsRow.guild_id,
          username: statsRow.username, displayName: statsRow.display_name,
          avatarUrl: statsRow.avatar_url, totalInvites: statsRow.total_invites,
          validInvites: statsRow.valid_invites, leftInvites: statsRow.left_invites,
          fakeInvites: statsRow.fake_invites, influenceScore: statsRow.influence_score,
          treeSize: statsRow.tree_size, retentionRate: statsRow.retention_rate, rank: null,
        } : null,
        recentInvitees: events.map(e => ({
          userId: e.invitee_user_id, username: e.invitee_username, displayName: e.invitee_display_name,
          avatarUrl: e.invitee_avatar_url, joinedAt: e.joined_at, leftAt: e.left_at,
        })),
        invitedByUserId:      parentRow?.inviter_user_id ?? null,
        invitedByUsername:    parentRow?.inviter_username ?? null,
        invitedByDisplayName: parentRow?.inviter_display_name ?? null,
        invitePathDisplayNames: [],
      }), { headers: { 'Content-Type': 'application/json' } });
    }

    // GET /bot/invite-tracker/tree?guild_id=xxx&user_id=xxx
    if (url.pathname === '/bot/invite-tracker/tree' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      const userId  = url.searchParams.get('user_id');
      if (!guildId || !userId) return new Response('Missing params', { status: 400 });

      // Recursively build tree (max 4 levels to avoid N+1)
      async function buildTree(uid: string, depth: number): Promise<any> {
        const [statsResp, childrenResp] = await Promise.all([
          sb(`/invite_stats?guild_id=eq.${guildId}&user_id=eq.${uid}`),
          sb(`/invite_events?guild_id=eq.${guildId}&inviter_user_id=eq.${uid}&order=joined_at.asc`),
        ]);
        const statsRows: any[] = statsResp.ok ? await statsResp.json() : [];
        const childEvents: any[] = childrenResp.ok ? await childrenResp.json() : [];
        const s = statsRows[0] ?? { user_id: uid, username: uid, display_name: uid, avatar_url: null, is_current_member: true, joined_at: null, left_at: null, direct_invites: 0, tree_size: 0 };

        const children = depth < 4
          ? await Promise.all(childEvents.map(c => buildTree(c.invitee_user_id, depth + 1)))
          : [];

        return {
          userId: s.user_id, username: s.username, displayName: s.display_name,
          avatarUrl: s.avatar_url, isCurrentMember: true,
          joinedAt: s.joined_at ?? null, leftAt: null,
          directInvites: childEvents.length, totalDescendants: s.tree_size ?? 0,
          children,
        };
      }

      const tree = await buildTree(userId, 0);
      return new Response(JSON.stringify(tree), { headers: { 'Content-Type': 'application/json' } });
    }

    // GET /bot/invite-tracker/settings?guild_id=xxx
    if (url.pathname === '/bot/invite-tracker/settings' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });

      const [settingsResp, milestonesResp] = await Promise.all([
        sb(`/invite_tracker_settings?guild_id=eq.${guildId}`),
        sb(`/invite_milestones?guild_id=eq.${guildId}&order=count.asc`),
      ]);
      const settings: any[] = settingsResp.ok ? await settingsResp.json() : [];
      const milestones: any[] = milestonesResp.ok ? await milestonesResp.json() : [];

      const s = settings[0] ?? { guild_id: guildId, is_enabled: false, log_channel_id: null, notify_on_join: true, notify_on_leave: true, fake_invite_threshold_hours: 24 };
      return new Response(JSON.stringify({
        guildId: s.guild_id, isEnabled: s.is_enabled, logChannelId: s.log_channel_id,
        notifyOnJoin: s.notify_on_join, notifyOnLeave: s.notify_on_leave,
        fakeInviteThresholdHours: s.fake_invite_threshold_hours,
        milestones: milestones.map(m => ({ id: m.id, guildId: m.guild_id, count: m.count, roleId: m.role_id, roleName: m.role_name })),
      }), { headers: { 'Content-Type': 'application/json' } });
    }

    // POST /bot/invite-tracker/settings
    if (url.pathname === '/bot/invite-tracker/settings' && request.method === 'POST') {
      const body = await request.json() as any;
      const payload = {
        guild_id: body.guildId, is_enabled: body.isEnabled,
        log_channel_id: body.logChannelId, notify_on_join: body.notifyOnJoin,
        notify_on_leave: body.notifyOnLeave, fake_invite_threshold_hours: body.fakeInviteThresholdHours,
      };
      const resp = await sb(`/invite_tracker_settings?guild_id=eq.${body.guildId}`, {
        method: 'PATCH', headers: { Prefer: 'return=representation' }, body: JSON.stringify(payload),
      });
      if (!resp.ok) {
        // Insert if not found
        const insResp = await sb('/invite_tracker_settings', {
          method: 'POST', headers: { Prefer: 'return=representation' }, body: JSON.stringify(payload),
        });
        if (!insResp.ok) return new Response(await insResp.text(), { status: insResp.status });
        const rows: any[] = await insResp.json();
        return new Response(JSON.stringify({ ...body, ...rows[0] }), { headers: { 'Content-Type': 'application/json' } });
      }
      const rows: any[] = await resp.json();
      return new Response(JSON.stringify({ ...body, ...rows[0] }), { headers: { 'Content-Type': 'application/json' } });
    }

    // GET /bot/invite-tracker/campaigns?guild_id=xxx
    if (url.pathname === '/bot/invite-tracker/campaigns' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });

      const resp = await sb(`/invite_campaigns?guild_id=eq.${guildId}&order=created_at.desc`);
      if (!resp.ok) return new Response('Supabase error', { status: 500 });
      const rows: any[] = await resp.json();
      return new Response(JSON.stringify(rows.map(c => ({
        id: c.id, guildId: c.guild_id, name: c.name, description: c.description,
        inviteCode: c.invite_code, targetCount: c.target_count, currentCount: c.current_count,
        startsAt: c.starts_at, endsAt: c.ends_at, isActive: c.is_active, createdAt: c.created_at,
      }))), { headers: { 'Content-Type': 'application/json' } });
    }

    // POST /bot/invite-tracker/campaigns
    if (url.pathname === '/bot/invite-tracker/campaigns' && request.method === 'POST') {
      const body = await request.json() as any;
      const resp = await sb('/invite_campaigns', {
        method: 'POST',
        headers: { Prefer: 'return=representation' },
        body: JSON.stringify({
          guild_id: body.guildId, name: body.name, description: body.description ?? null,
          invite_code: body.inviteCode ?? null, target_count: body.targetCount ?? null,
          current_count: 0, starts_at: new Date().toISOString(),
          ends_at: body.endsAt ?? null, is_active: true,
        }),
      });
      if (!resp.ok) return new Response(await resp.text(), { status: resp.status });
      const rows: any[] = await resp.json();
      const c = rows[0];
      return new Response(JSON.stringify({
        id: c.id, guildId: c.guild_id, name: c.name, description: c.description,
        inviteCode: c.invite_code, targetCount: c.target_count, currentCount: c.current_count,
        startsAt: c.starts_at, endsAt: c.ends_at, isActive: c.is_active, createdAt: c.created_at,
      }), { status: 201, headers: { 'Content-Type': 'application/json' } });
    }

    // DELETE /bot/invite-tracker/campaigns/:id
    const campaignDeleteMatch = url.pathname.match(/^\/bot\/invite-tracker\/campaigns\/([^/]+)$/);
    if (campaignDeleteMatch && request.method === 'DELETE') {
      const id = campaignDeleteMatch[1];
      await sb(`/invite_campaigns?id=eq.${id}`, { method: 'DELETE' });
      return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
    }

    // ── Invite Panel ──────────────────────────────────────────────────

    // POST /bot/invite-tracker/panel  → Discordチャンネルにボタンを送信してパネル登録
    if (url.pathname === '/bot/invite-tracker/panel' && request.method === 'POST') {
      const body = await request.json() as { guildId: string; channelId: string; channelName: string };
      const { guildId: gId, channelId, channelName } = body;

      // Discord にメッセージ + ボタンを送信
      const msgResp = await fetch(`https://discord.com/api/v10/channels/${channelId}/messages`, {
        method: 'POST',
        headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          embeds: [{
            title: '🔗 あなた専用の招待リンク',
            description: 'ボタンを押すと、あなただけの招待リンクが発行されます。友達をサーバーに招待しよう！',
            color: 0x9B59B6,
          }],
          components: [{
            type: 1,
            components: [{
              type: 2,
              style: 1,
              label: '招待リンクを取得する',
              custom_id: `personal_invite:${gId}`,
              emoji: { name: '🔗' },
            }],
          }],
        }),
      });

      if (!msgResp.ok) {
        const err = await msgResp.text();
        return new Response(JSON.stringify({ error: `Discord API: ${err}` }), { status: msgResp.status, headers: { 'Content-Type': 'application/json' } });
      }
      const msg = await msgResp.json() as { id: string };

      // DBに保存
      const insertResp = await sb('/invite_panels', {
        method: 'POST',
        headers: { Prefer: 'return=representation' },
        body: JSON.stringify({ guild_id: gId, channel_id: channelId, channel_name: channelName, message_id: msg.id }),
      });
      if (!insertResp.ok) return new Response(await insertResp.text(), { status: insertResp.status });
      const rows: any[] = await insertResp.json();
      const p = rows[0];
      return new Response(JSON.stringify({
        id: p.id, guildId: p.guild_id, channelId: p.channel_id, channelName: p.channel_name,
        messageId: p.message_id, createdAt: p.created_at,
      }), { status: 201, headers: { 'Content-Type': 'application/json' } });
    }

    // GET /bot/invite-tracker/panels?guild_id=xxx
    if (url.pathname === '/bot/invite-tracker/panels' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });
      const resp = await sb(`/invite_panels?guild_id=eq.${guildId}&order=created_at.desc`);
      if (!resp.ok) return new Response('Supabase error', { status: 500 });
      const rows: any[] = await resp.json();
      return new Response(JSON.stringify(rows.map(p => ({
        id: p.id, guildId: p.guild_id, channelId: p.channel_id, channelName: p.channel_name,
        messageId: p.message_id, createdAt: p.created_at,
      }))), { headers: { 'Content-Type': 'application/json' } });
    }

    // DELETE /bot/invite-tracker/panels/:id  → Discordメッセージ削除 + DB削除
    const panelDeleteMatch = url.pathname.match(/^\/bot\/invite-tracker\/panels\/([^/]+)$/);
    if (panelDeleteMatch && request.method === 'DELETE') {
      const id = panelDeleteMatch[1];
      const getResp = await sb(`/invite_panels?id=eq.${id}`);
      const rows: any[] = getResp.ok ? await getResp.json() : [];
      if (rows.length > 0 && rows[0].message_id) {
        await fetch(`https://discord.com/api/v10/channels/${rows[0].channel_id}/messages/${rows[0].message_id}`, {
          method: 'DELETE',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
        }).catch(() => {});
      }
      await sb(`/invite_panels?id=eq.${id}`, { method: 'DELETE' });
      return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
    }

    // GET /bot/invite-tracker/personal-invites?guild_id=xxx
    if (url.pathname === '/bot/invite-tracker/personal-invites' && request.method === 'GET') {
      const guildId = url.searchParams.get('guild_id');
      if (!guildId) return new Response('Missing guild_id', { status: 400 });
      const resp = await sb(`/personal_invites?guild_id=eq.${guildId}&order=created_at.desc`);
      if (!resp.ok) return new Response('Supabase error', { status: 500 });
      const rows: any[] = await resp.json();
      return new Response(JSON.stringify(rows.map(p => ({
        id: p.id, guildId: p.guild_id, userId: p.user_id, username: p.username,
        displayName: p.display_name, inviteCode: p.invite_code, inviteUrl: p.invite_url,
        channelId: p.channel_id, createdAt: p.created_at,
      }))), { headers: { 'Content-Type': 'application/json' } });
    }

    // DELETE /bot/invite-tracker/personal-invites/:id
    const personalInviteDeleteMatch = url.pathname.match(/^\/bot\/invite-tracker\/personal-invites\/([^/]+)$/);
    if (personalInviteDeleteMatch && request.method === 'DELETE') {
      const id = personalInviteDeleteMatch[1];
      // Discordの招待リンクも削除
      const getResp = await sb(`/personal_invites?id=eq.${id}`);
      const rows: any[] = getResp.ok ? await getResp.json() : [];
      if (rows.length > 0) {
        await fetch(`https://discord.com/api/v10/invites/${rows[0].invite_code}`, {
          method: 'DELETE',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
        }).catch(() => {});
      }
      await sb(`/personal_invites?id=eq.${id}`, { method: 'DELETE' });
      return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
    }

    // ── 課金: エンタイトルメント同期 POST /billing/entitlement ─────────
    // iOS が StoreKit 2 で購入成功後に呼ぶ。user_profiles を UPSERT。
    if (url.pathname === '/billing/entitlement' && request.method === 'POST') {
      const body = await request.json() as {
        discordUserId: string;
        productId: string;
        expiresAt: string | null;
        jwsToken: string;    // transaction.jsonRepresentation
        supabaseJwt: string;
      };

      // JWT 検証
      const authResult = await verifySupabaseJwt(body.supabaseJwt, body.discordUserId, env);
      if (!authResult.ok) {
        return new Response(JSON.stringify({ error: authResult.error }), { status: 401, headers: { 'Content-Type': 'application/json' } });
      }

      // JWS payload をデコードして productId と expiresAt を取得（署名は iOS 側検証済み）
      const slots = SLOT_MAP[body.productId] ?? 0;
      if (slots === 0) {
        return new Response(JSON.stringify({ error: 'Unknown product' }), { status: 400, headers: { 'Content-Type': 'application/json' } });
      }

      // user_profiles を UPSERT（supabase auth.users.id は Supabase JWT から取得）
      const upsertResp = await sb('/user_profiles', {
        method: 'POST',
        headers: { Prefer: 'return=representation,resolution=merge-duplicates' },
        body: JSON.stringify({
          id:                       authResult.supabaseUserId,
          discord_user_id:          body.discordUserId,
          purchased_slots:          slots,
          subscription_product_id:  body.productId,
          subscription_expires_at:  body.expiresAt ?? null,
          updated_at:               new Date().toISOString(),
        }),
      });
      if (!upsertResp.ok) {
        return new Response(await upsertResp.text(), { status: upsertResp.status });
      }

      return new Response(JSON.stringify({ ok: true, purchasedSlots: slots }), {
        status: 200, headers: { 'Content-Type': 'application/json' },
      });
    }

    // ── 課金: サーバー有効化 POST /billing/activate ───────────────────
    if (url.pathname === '/billing/activate' && request.method === 'POST') {
      const body = await request.json() as {
        guildId: string;
        discordUserId: string;
        supabaseJwt: string;
      };

      // L1+L2: JWT 検証 + discordUserId 照合
      const authResult = await verifySupabaseJwt(body.supabaseJwt, body.discordUserId, env);
      if (!authResult.ok) {
        return new Response(JSON.stringify({ error: authResult.error }), { status: 401, headers: { 'Content-Type': 'application/json' } });
      }

      // L3: Discord API でオーナー確認
      const guildResp = await fetch(`https://discord.com/api/v10/guilds/${body.guildId}`, {
        headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
      });
      if (!guildResp.ok) {
        return new Response(JSON.stringify({ error: 'Guild not found' }), { status: 404, headers: { 'Content-Type': 'application/json' } });
      }
      const guild = await guildResp.json() as { owner_id: string };
      if (guild.owner_id !== body.discordUserId) {
        return new Response(JSON.stringify({ error: 'Not the owner of this server' }), { status: 403, headers: { 'Content-Type': 'application/json' } });
      }

      // L4: スロット上限チェック
      const profileResp = await sb(`/user_profiles?discord_user_id=eq.${body.discordUserId}&select=purchased_slots,subscription_expires_at`);
      const profiles: any[] = profileResp.ok ? await profileResp.json() : [];
      const profile = profiles[0];
      if (!profile || profile.purchased_slots === 0) {
        return new Response(JSON.stringify({ error: 'No active subscription' }), { status: 402, headers: { 'Content-Type': 'application/json' } });
      }
      if (profile.subscription_expires_at && new Date(profile.subscription_expires_at) < new Date()) {
        return new Response(JSON.stringify({ error: 'Subscription expired' }), { status: 402, headers: { 'Content-Type': 'application/json' } });
      }

      const countResp = await sb(`/activated_servers?discord_user_id=eq.${body.discordUserId}&select=count`);
      const countJson: any[] = countResp.ok ? await countResp.json() : [];
      const usedSlots = Number(countJson[0]?.count ?? 0);
      if (usedSlots >= profile.purchased_slots) {
        return new Response(JSON.stringify({ error: 'Slot limit reached', limit: profile.purchased_slots, used: usedSlots }), {
          status: 402, headers: { 'Content-Type': 'application/json' },
        });
      }

      // L5: INSERT（UNIQUE 制約で二重登録防止）
      const insertResp = await sb('/activated_servers', {
        method: 'POST',
        headers: { Prefer: 'return=representation' },
        body: JSON.stringify({ discord_user_id: body.discordUserId, guild_id: body.guildId }),
      });
      if (!insertResp.ok) {
        const errText = await insertResp.text();
        if (errText.includes('unique') || errText.includes('duplicate') || errText.includes('23505')) {
          return new Response(JSON.stringify({ ok: true, alreadyActivated: true }), { status: 200, headers: { 'Content-Type': 'application/json' } });
        }
        return new Response(errText, { status: insertResp.status });
      }
      return new Response(JSON.stringify({ ok: true }), { status: 201, headers: { 'Content-Type': 'application/json' } });
    }

    // ── 課金: サーバー有効化解除 DELETE /billing/activate/:guildId ───
    const billingDeactivateMatch = url.pathname.match(/^\/billing\/activate\/([^/]+)$/);
    if (billingDeactivateMatch && request.method === 'DELETE') {
      const guildId = billingDeactivateMatch[1];
      const discordUserId = url.searchParams.get('discord_user_id') ?? '';
      if (!discordUserId) return new Response(JSON.stringify({ error: 'discord_user_id required' }), { status: 400, headers: { 'Content-Type': 'application/json' } });

      // JWT 検証
      const jwt = request.headers.get('X-Supabase-Jwt') ?? '';
      const authResult = await verifySupabaseJwt(jwt, discordUserId, env);
      if (!authResult.ok) {
        return new Response(JSON.stringify({ error: authResult.error }), { status: 401, headers: { 'Content-Type': 'application/json' } });
      }

      await sb(`/activated_servers?guild_id=eq.${guildId}&discord_user_id=eq.${discordUserId}`, { method: 'DELETE' });
      return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
    }

    // ── 課金: ステータス取得 GET /billing/status?discord_user_id=xxx ──
    if (url.pathname === '/billing/status' && request.method === 'GET') {
      const discordUserId = url.searchParams.get('discord_user_id') ?? '';
      if (!discordUserId) return new Response(JSON.stringify({ error: 'discord_user_id required' }), { status: 400, headers: { 'Content-Type': 'application/json' } });

      const [profileResp, activatedResp] = await Promise.all([
        sb(`/user_profiles?discord_user_id=eq.${discordUserId}&select=purchased_slots,subscription_product_id,subscription_expires_at`),
        sb(`/activated_servers?discord_user_id=eq.${discordUserId}&select=guild_id,activated_at`),
      ]);

      const profiles: any[] = profileResp.ok ? await profileResp.json() : [];
      const activated: any[] = activatedResp.ok ? await activatedResp.json() : [];
      const profile = profiles[0];

      return new Response(JSON.stringify({
        purchasedSlots:        profile?.purchased_slots ?? 0,
        usedSlots:             activated.length,
        productId:             profile?.subscription_product_id ?? null,
        expiresAt:             profile?.subscription_expires_at ?? null,
        activatedGuildIds:     activated.map((r: any) => r.guild_id),
      }), { headers: { 'Content-Type': 'application/json' } });
    }

    // ── デバッグ専用: プロ状態をDBに設定 POST /billing/debug-setup ──
    // X-Debug: 1 ヘッダーが必要。本番アプリは絶対に送らない。
    if (url.pathname === '/billing/debug-setup' && request.method === 'POST') {
      if (request.headers.get('X-Debug') !== '1') {
        return new Response(JSON.stringify({ error: 'Not Found' }), { status: 404, headers: { 'Content-Type': 'application/json' } });
      }
      const body = await request.json() as {
        discordUserId: string;
        supabaseUserId: string;
        purchasedSlots: number;   // 0 = リセット
        productId: string | null;
      };
      const { discordUserId, supabaseUserId, purchasedSlots, productId } = body;

      if (purchasedSlots === 0) {
        // リセット: user_profiles を 0 スロットに / activated_servers を全削除
        await Promise.all([
          sb(`/user_profiles?id=eq.${supabaseUserId}`, {
            method: 'PATCH',
            body: JSON.stringify({ purchased_slots: 0, subscription_product_id: null, subscription_expires_at: null }),
          }),
          sb(`/activated_servers?discord_user_id=eq.${discordUserId}`, { method: 'DELETE' }),
        ]);
      } else {
        // セットアップ: 指定スロット数で user_profiles を UPSERT
        const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
        await sb('/user_profiles', {
          method: 'POST',
          headers: { Prefer: 'return=representation,resolution=merge-duplicates' },
          body: JSON.stringify({
            id: supabaseUserId,
            discord_user_id: discordUserId,
            purchased_slots: purchasedSlots,
            subscription_product_id: productId ?? `jp.noxyapp.stat.${purchasedSlots}server`,
            subscription_expires_at: expiresAt,
            updated_at: new Date().toISOString(),
          }),
        });
      }
      return new Response(JSON.stringify({ ok: true, purchasedSlots }), { headers: { 'Content-Type': 'application/json' } });
    }

    // ── 画像アップロード POST /upload/image ─────────────────────
    if (url.pathname === '/upload/image' && request.method === 'POST') {
      try {
        const formData = await request.formData();
        const file = formData.get('file') as File | null;
        if (!file || typeof file === 'string') {
          return new Response(JSON.stringify({ error: 'No file provided' }), { status: 400, headers: { 'Content-Type': 'application/json' } });
        }

        const bucket = 'embed-images';

        // 1. バケットが存在するか確認、なければ自動作成
        await ensureStorageBucket(env, bucket);

        const arrayBuffer = await file.arrayBuffer();
        const uint8Array = new Uint8Array(arrayBuffer);
        const fileName = `embeds/${crypto.randomUUID()}.jpg`;

        // 2. ファイルアップロード
        const uploadResp = await fetch(`${env.SUPABASE_URL}/storage/v1/object/${bucket}/${fileName}`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
            'Content-Type': 'image/jpeg',
            'x-upsert': 'true',
          },
          body: uint8Array,
        });

        if (!uploadResp.ok) {
          const errText = await uploadResp.text();
          console.error(`[Upload] Supabase storage error: ${uploadResp.status} ${errText}`);
          return new Response(JSON.stringify({ error: `Storage upload failed: ${errText}` }), { status: 500, headers: { 'Content-Type': 'application/json' } });
        }

        const publicUrl = `${env.SUPABASE_URL}/storage/v1/object/public/${bucket}/${fileName}`;
        return new Response(JSON.stringify({ url: publicUrl }), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) {
        console.error(`[Upload] Error: ${String(e)}`);
        return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { 'Content-Type': 'application/json' } });
      }
    }

    // ── 画像削除 POST /upload/delete ────────────────────────────
    if (url.pathname === '/upload/delete' && request.method === 'POST') {
      try {
        const body = await request.json() as { urls: string[] };
        const results: { url: string; ok: boolean }[] = [];
        for (const imageUrl of body.urls) {
          // URL から Storage パスを抽出
          // https://...supabase.co/storage/v1/object/public/embed-images/embeds/xxx.jpg
          const match = imageUrl.match(/\/embed-images\/(.+)$/);
          if (match) {
            const path = match[1];
            const delResp = await fetch(`${env.SUPABASE_URL}/storage/v1/object/embed-images/${path}`, {
              method: 'DELETE',
              headers: { 'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}` },
            });
            results.push({ url: imageUrl, ok: delResp.ok });
          } else {
            results.push({ url: imageUrl, ok: false });
          }
        }
        return new Response(JSON.stringify({ results }), { headers: { 'Content-Type': 'application/json' } });
      } catch (e) {
        console.error(`[Upload] Delete error: ${String(e)}`);
        return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { 'Content-Type': 'application/json' } });
      }
    }

    return new Response(JSON.stringify({ error: 'Not Found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    });
  },

  async scheduled(
    event: ScheduledEvent,
    env: Env,
    _ctx: ExecutionContext
  ): Promise<void> {
    // グローバル変数を設定（supabaseFetch / sendToDiscord が参照）
    (globalThis as any).SUPABASE_URL        = env.SUPABASE_URL;
    (globalThis as any).SUPABASE_SERVICE_KEY = env.SUPABASE_SERVICE_KEY;
    (globalThis as any).DISCORD_BOT_TOKEN   = env.DISCORD_BOT_TOKEN;

    // event.cron でどのトリガーが発火したか判別して処理を振り分ける
    // 50サブリクエスト/実行の制限を超えないよう、処理を分散させる
    switch (event.cron) {

      // ── 5分毎: 注文タイムアウト ──────────────────────────────
      case "*/5 * * * *": {
        console.log("[Cron] 注文タイムアウト処理開始");
        await processOrderTimeouts(env);
        console.log("[Cron] 注文タイムアウト処理完了");
        break;
      }

      // ── 毎時: ステータスチャンネル更新 ──────────────────────
      case "0 * * * *": {
        console.log("[Cron] ステータスチャンネル更新開始");
        await processStatChannels(env);
        console.log("[Cron] ステータスチャンネル更新完了");
        break;
      }

      default:
        console.warn(`[Cron] 未知のトリガー: ${event.cron}`);
    }
  },
};

// ── 環境変数インターフェース ─────────────────────────────────

interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_KEY: string;
  DISCORD_BOT_TOKEN: string;
  DISCORD_CLIENT_ID: string;
  DISCORD_PUBLIC_KEY: string;  // wrangler secret put DISCORD_PUBLIC_KEY
  WORKER_API_SECRET: string;   // wrangler secret put WORKER_API_SECRET (legacy, optional)
  SUPABASE_ANON_KEY: string;   // wrangler secret put SUPABASE_ANON_KEY（課金JWT検証用）
  SUPABASE_JWT_SECRET: string; // wrangler secret put SUPABASE_JWT_SECRET
}

// ── Supabase Storage: バケット自動作成 ───────────────────────

async function ensureStorageBucket(env: Env, bucketId: string): Promise<void> {
  // バケット一覧を取得
  const listResp = await fetch(`${env.SUPABASE_URL}/storage/v1/bucket`, {
    headers: { 'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}` },
  });

  if (!listResp.ok) {
    console.error(`[Upload] Failed to list buckets: ${listResp.status}`);
    throw new Error('Failed to list storage buckets');
  }

  const buckets: any[] = await listResp.json();
  const exists = buckets.some((b: any) => b.id === bucketId || b.name === bucketId);

  if (exists) {
    console.log(`[Upload] Bucket already exists: ${bucketId}`);
    return;
  }

  // バケットを作成（public = true）
  const createResp = await fetch(`${env.SUPABASE_URL}/storage/v1/bucket`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      id: bucketId,
      name: bucketId,
      public: true,
    }),
  });

  if (!createResp.ok) {
    const errText = await createResp.text();
    console.error(`[Upload] Failed to create bucket: ${createResp.status} ${errText}`);
    throw new Error(`Failed to create bucket: ${errText}`);
  }

  console.log(`[Upload] Created bucket: ${bucketId}`);
}
