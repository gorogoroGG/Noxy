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
      const permissions = "2147485696";
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

    // デプロイ POST /bot/ticket-panels/:id/deploy
    const panelDeployMatch = url.pathname.match(/^\/bot\/ticket-panels\/([^\/]+)\/deploy$/);
    if (panelDeployMatch && request.method === 'POST') {
      const id = panelDeployMatch[1];
      try {
        const panelResp = await sb(`/ticket_panels?id=eq.${id}`);
        const panels = await panelResp.json() as TicketPanelRow[];
        if (!panels.length) return new Response('Panel not found', { status: 404 });
        const panel = panels[0];
        if (!panel.channel_id) return new Response('channel_id is not set', { status: 400 });

        // Discord にパネルメッセージを投稿
        const postResp = await fetch(`https://discord.com/api/v10/channels/${panel.channel_id}/messages`, {
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
    console.log(
      `Done: sent=${result.sent} rescheduled=${result.rescheduled} errors=${result.errors}`
    );
  },
};

// ── 環境変数インターフェース ─────────────────────────────────

interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_KEY: string;
  DISCORD_BOT_TOKEN: string;
  DISCORD_CLIENT_ID: string;
}
