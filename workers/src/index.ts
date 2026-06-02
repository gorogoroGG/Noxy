/**
 * Noxy Scheduler Worker
 *
 * 1分ごとに実行され、Supabase 内の送信予定メッセージを確認し、
 * 指定時刻になったものを Discord に投稿する。
 *
 * Cron トリガーで実行されるため、HTTP リクエストのハンドラは不要。
 */

interface ScheduledMessage {
  id: string;
  guild_id: string;
  channel_id: string;
  embed_id: string;
  title: string;
  scheduled_for: string;
  repeat_rule: string; // "none" | "daily" | "weekly" | "monthly"
  status: string;      // "pending" | "sent" | "cancelled"
  end_date: string | null;
}

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

// ── ショップ型定義 ────────────────────────────────────────────

interface ShopRow {
  id: string; guild_id: string; name: string; description: string; enabled: boolean;
  disabled_message: string | null;
  channel_id: string; message_id: string | null;
  order_category_id: string | null; archive_category_id: string | null;
  support_role_id: string | null; timeout_hours: number | null;
  color: number; footer_text: string;
  payment_flow: string; auto_deliver: boolean;
  welcome_image_url: string | null; welcome_thumbnail_url: string | null;
  welcome_fields: Array<{name: string; value: string; inline: boolean}>;
  welcome_footer_text: string | null; welcome_footer_icon_url: string | null;
  welcome_show_timestamp: boolean;
  created_at: string;
}

function mapShop(s: ShopRow) {
  return { id: s.id, guildId: s.guild_id, name: s.name, description: s.description,
    enabled: s.enabled, disabledMessage: s.disabled_message,
    channelId: s.channel_id, messageId: s.message_id,
    orderCategoryId: s.order_category_id, archiveCategoryId: s.archive_category_id,
    supportRoleId: s.support_role_id, timeoutHours: s.timeout_hours,
    color: s.color, footerText: s.footer_text,
    paymentFlow: s.payment_flow, autoDeliver: s.auto_deliver,
    welcomeImageUrl: s.welcome_image_url, welcomeThumbnailUrl: s.welcome_thumbnail_url,
    welcomeFields: s.welcome_fields ?? [],
    welcomeFooterText: s.welcome_footer_text, welcomeFooterIconUrl: s.welcome_footer_icon_url,
    welcomeShowTimestamp: s.welcome_show_timestamp,
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

// ── Supabase クライアント ─────────────────────────────────────

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

// ── 繰り返し日時の計算 ──────────────────────────────────────

function nextScheduledDate(current: Date, rule: string, endDate: string | null): Date | null {
  const next = new Date(current);
  switch (rule) {
    case "daily":
      next.setDate(next.getDate() + 1);
      break;
    case "weekly":
      next.setDate(next.getDate() + 7);
      break;
    case "monthly":
      next.setMonth(next.getMonth() + 1);
      break;
    default:
      return null; // 繰り返しなし
  }
  if (endDate && next > new Date(endDate)) return null; // 終了日超過
  return next;
}

// ── メイン処理 ──────────────────────────────────────────────

async function processScheduledMessages(): Promise<{
  sent: number;
  rescheduled: number;
  errors: number;
}> {
  const now = new Date().toISOString();
  let sent = 0;
  let rescheduled = 0;
  let errors = 0;

  // (1) 送信時刻を過ぎた pending メッセージを取得
  const resp = await supabaseFetch(
    `/scheduled_messages?status=eq.pending&scheduled_for=lte.${now}&order=scheduled_for.asc`
  );
  if (!resp.ok) {
    console.error(`Supabase fetch error: ${resp.status} ${await resp.text()}`);
    return { sent, rescheduled, errors };
  }
  const messages: ScheduledMessage[] = await resp.json();
  console.log(`Found ${messages.length} pending message(s)`);

  for (const msg of messages) {
    try {
      // (2) 埋め込みテンプレートを取得
      const embedResp = await supabaseFetch(
        `/embeds?id=eq.${msg.embed_id}`
      );
      if (!embedResp.ok) {
        console.error(`Embed ${msg.embed_id} not found for message ${msg.id}`);
        errors++;
        continue;
      }
      const embeds: Embed[] = await embedResp.json();
      if (embeds.length === 0) {
        console.error(`Embed ${msg.embed_id} empty for message ${msg.id}`);
        errors++;
        continue;
      }

      // (3) Discord に送信
      const ok = await sendToDiscord(msg.channel_id, embeds[0]);
      if (!ok) {
        console.error(`Failed to send message ${msg.id} to Discord`);
        errors++;
        continue;
      }
      sent++;
      console.log(`Sent message ${msg.id} (${msg.title || "untitled"})`);

      // (4) ステータス更新（繰り返しがあれば次回日時を設定）
      if (msg.repeat_rule !== "none") {
        const nextDate = nextScheduledDate(
          new Date(msg.scheduled_for),
          msg.repeat_rule,
          msg.end_date
        );
        if (nextDate) {
          await supabaseFetch(`/scheduled_messages?id=eq.${msg.id}`, {
            method: "PATCH",
            body: JSON.stringify({
              scheduled_for: nextDate.toISOString(),
            }),
          });
          rescheduled++;
          console.log(`  → next: ${nextDate.toISOString()}`);
        } else {
          // 繰り返し終了
          await supabaseFetch(`/scheduled_messages?id=eq.${msg.id}`, {
            method: "PATCH",
            body: JSON.stringify({ status: "sent" }),
          });
        }
      } else {
        await supabaseFetch(`/scheduled_messages?id=eq.${msg.id}`, {
          method: "PATCH",
          body: JSON.stringify({ status: "sent" }),
        });
      }
    } catch (e) {
      console.error(`Error processing message ${msg.id}:`, e);
      errors++;
    }
  }

  return { sent, rescheduled, errors };
}

// ── 注文タイムアウト処理 ──────────────────────────────────────

async function processOrderTimeouts(env: Env): Promise<void> {
  // open 状態の注文をすべて取得
  const resp = await supabaseFetch('/orders?status=eq.open&order=created_at.asc');
  if (!resp.ok) return;
  const orders: OrderRow[] = await resp.json();

  for (const order of orders) {
    const shopR  = await supabaseFetch(`/shops?id=eq.${order.shop_id}`);
    const shopArr: ShopRow[] = await shopR.json();
    if (!shopArr.length) continue;
    const shop = shopArr[0];
    if (!shop.timeout_hours) continue;

    const createdAt  = new Date(order.created_at);
    const timeoutAt  = new Date(createdAt.getTime() + shop.timeout_hours * 3600 * 1000);
    if (new Date() < timeoutAt) continue;

    // タイムアウト: キャンセル
    await supabaseFetch(`/orders?id=eq.${order.id}`, {
      method: 'PATCH',
      body: JSON.stringify({ status: 'cancelled', cancelled_at: new Date().toISOString() }),
    });
    if (order.channel_id) {
      await fetch(`https://discord.com/api/v10/channels/${order.channel_id}/messages`, {
        method: 'POST', headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ content: `⏰ **注文がタイムアウトしました。** ${shop.timeout_hours}時間以内に支払いが確認されなかったため自動キャンセルされました。` }),
      });
      await archiveOrderChannel(order.channel_id, order.buyer_user_id, shop.archive_category_id, env);
    }
    console.log(`[Order] タイムアウトキャンセル: ${order.id}`);
  }
}

// ── Worker Entry Point ───────────────────────────────────────

export default {
  // HTTP API エンドポイント
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // Botが参加しているサーバー一覧
    if (url.pathname === "/bot/guilds") {
      const resp = await fetch("https://discord.com/api/v10/users/@me/guilds", {
        headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}` },
      });
      const guilds: Array<{ id: string; name: string; icon: string | null; owner: boolean }> = await resp.json();
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
        .map((m: any) => ({
          id:          m.user.id,
          guildId,
          username:    m.user.username,
          displayName: m.nick ?? m.user.global_name ?? m.user.username,
          avatarUrl:   m.user.avatar
            ? `https://cdn.discordapp.com/avatars/${m.user.id}/${m.user.avatar}.png`
            : null,
          roles:       (m.roles as string[]).map(id => roleMap[id]).filter(Boolean),
          joinedAt:    m.joined_at,
          isBoosting:  !!m.premium_since,
          status:      "offline",
        }));

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

    // リアクションロールパネルをDiscordに送信
    if (url.pathname === "/bot/reaction-roles/publish" && request.method === "POST") {
      try {
        const body = await request.json() as {
          reactionRoleId: string;
          channelId: string;
          channelName: string;
          guildId: string;
        };

        const sb = makeSupabaseFetch(env);

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

    // Bot招待URL
    if (url.pathname === "/bot/invite-url") {
      const guildId = url.searchParams.get("guild_id") || "";
      // MoveMembers (16777216) を追加
      const permissions = "2164262912";
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

    const sb = makeSupabaseFetch(env);

    // チケット作成 POST /bot/tickets/create
    if (url.pathname === '/bot/tickets/create' && request.method === 'POST') {
      try {
        const body = await request.json() as { guildId: string; subject: string; openedByUserId?: string };
        if (!body.guildId || !body.subject?.trim())
          return new Response('guildId and subject are required', { status: 400 });

        // Discord にチャンネルを作成
        const suffix      = Date.now().toString().slice(-4);
        const channelName = `ticket-admin-${suffix}`;
        const chResp = await fetch(`https://discord.com/api/v10/guilds/${body.guildId}/channels`, {
          method: 'POST',
          headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ name: channelName, type: 0 }),
        });
        const channelId = chResp.ok ? ((await chResp.json()) as { id: string }).id : '';

        // Supabase にチケットを記録
        const sbRes = await sb('/tickets', {
          method:  'POST',
          body:    JSON.stringify({
            guild_id:          body.guildId,
            channel_id:        channelId,
            opened_by_user_id: body.openedByUserId ?? 'admin',
            subject:           body.subject.trim(),
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
      const body = await request.json() as { userId: string };
      if (!body.userId?.trim()) return new Response('userId is required', { status: 400 });

      const ticketResp = await sb(`/tickets?id=eq.${id}`);
      const tickets = await ticketResp.json() as TicketRow[];
      if (!tickets.length) return new Response('Not found', { status: 404 });
      const ticket = tickets[0];

      await sb(`/tickets?id=eq.${id}`, {
        method: 'PATCH',
        body: JSON.stringify({ assigned_to_user_id: body.userId }),
      });

      // Discord チャンネルに担当者を追加
      try {
        await fetch(`https://discord.com/api/v10/channels/${ticket.channel_id}/permissions/${body.userId}`, {
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
        const body = await request.json() as {
          guildId?: string; channelId?: string; title?: string; description?: string;
          color?: number; buttonLabel?: string; buttonEmoji?: string;
          supportRoleId?: string | null; openCategoryId?: string | null;
          closedCategoryId?: string | null; ticketMsgContent?: string | null;
          ticketEmbedTitle?: string; ticketEmbedColor?: number; maxOpenPerUser?: number;
        };
        const insertData = {
          guild_id:          body.guildId          ?? '',
          channel_id:        body.channelId        ?? '',
          title:             body.title            ?? 'サポートチケット',
          description:       body.description      ?? '',
          color:             body.color            ?? 0x6366f1,
          button_label:      body.buttonLabel      ?? 'チケットを作成',
          button_emoji:      body.buttonEmoji      ?? '🎫',
          support_role_id:   body.supportRoleId    ?? null,
          open_category_id:  body.openCategoryId   ?? null,
          closed_category_id:body.closedCategoryId ?? null,
          ticket_msg_content:body.ticketMsgContent ?? null,
          ticket_embed_title:body.ticketEmbedTitle ?? 'チケット',
          ticket_embed_color:body.ticketEmbedColor ?? 0x6366f1,
          max_open_per_user: body.maxOpenPerUser   ?? 1,
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
        // channelId をリクエストボディから受け取る
        let bodyChannelId = '';
        try {
          const body = await request.json() as { channelId?: string };
          bodyChannelId = body.channelId ?? '';
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
              components: [{
                type:      2,
                style:     1,
                label:     panel.button_label,
                emoji:     { name: panel.button_emoji },
                custom_id: `ticket_open_${panel.id}`,
              }],
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
          joinLeaveNotification?: boolean; enabled?: boolean;
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
          payment_flow:        body['paymentFlow'] ?? body.payment_flow ?? 'manual',
          auto_deliver:        body['autoDeliver'] ?? body.auto_deliver ?? true,
          welcome_image_url:   body['welcomeImageUrl'] ?? body.welcome_image_url ?? null,
          welcome_thumbnail_url: body['welcomeThumbnailUrl'] ?? body.welcome_thumbnail_url ?? null,
          welcome_fields:      body['welcomeFields'] ?? body.welcome_fields ?? [],
          welcome_footer_text: body['welcomeFooterText'] ?? body.welcome_footer_text ?? null,
          welcome_footer_icon_url: body['welcomeFooterIconUrl'] ?? body.welcome_footer_icon_url ?? null,
          welcome_show_timestamp: body['welcomeShowTimestamp'] ?? body.welcome_show_timestamp ?? true,
        };
        console.log('[Worker] POST /bot/shops data to Supabase:', JSON.stringify(data));
        const r = await sb('/shops', { method: 'POST', body: JSON.stringify(data), headers: { Prefer: 'return=representation' } });
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
          paymentFlow: 'payment_flow', autoDeliver: 'auto_deliver',
          welcomeImageUrl: 'welcome_image_url', welcomeThumbnailUrl: 'welcome_thumbnail_url',
          welcomeFields: 'welcome_fields',
          welcomeFooterText: 'welcome_footer_text', welcomeFooterIconUrl: 'welcome_footer_icon_url',
          welcomeShowTimestamp: 'welcome_show_timestamp',
        };
        const data: Record<string, unknown> = {};
        for (const [k, v] of Object.entries(body)) { const sk = camel[k] ?? k; data[sk] = v; }
        const r = await sb(`/shops?id=eq.${id}`, { method: 'PATCH', body: JSON.stringify(data), headers: { Prefer: 'return=representation' } });
        if (!r.ok) return new Response(await r.text(), { status: r.status });
        const rows = await r.json() as ShopRow[];
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
        const body   = await request.json() as { channelId: string };
        console.log('[Worker] POST /bot/shops/:id/deploy shopId=', shopId, 'channelId=', body.channelId);
        if (!body.channelId) return new Response('channelId required', { status: 400 });
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
        console.log('[Worker] deploy: posting to Discord channel', body.channelId);
        const postR = await fetch(`https://discord.com/api/v10/channels/${body.channelId}/messages`, {
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
          body: JSON.stringify({ channel_id: body.channelId, message_id: posted.id }),
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

    return new Response("Not Found", { status: 404 });
  },

  async scheduled(
    _event: ScheduledEvent,
    env: Env,
    _ctx: ExecutionContext
  ): Promise<void> {
    (globalThis as any).SUPABASE_URL = env.SUPABASE_URL;
    (globalThis as any).SUPABASE_SERVICE_KEY = env.SUPABASE_SERVICE_KEY;
    (globalThis as any).DISCORD_BOT_TOKEN = env.DISCORD_BOT_TOKEN;

    console.log("Noxy Scheduler: checking pending messages...");
    const result = await processScheduledMessages();
    console.log(`Done: sent=${result.sent} rescheduled=${result.rescheduled} errors=${result.errors}`);

    // 注文タイムアウトチェック
    await processOrderTimeouts(env);
  },
};

// ── 環境変数インターフェース ─────────────────────────────────

interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_KEY: string;
  DISCORD_BOT_TOKEN: string;
  DISCORD_CLIENT_ID: string;
}
