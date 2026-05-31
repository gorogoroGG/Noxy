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

interface Embed {
  id: string;
  name: string;
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
  const body = {
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
