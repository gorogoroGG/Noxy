/**
 * REST API v1 — iOS アプリ向け JSON エンドポイント
 *
 * 認証: X-API-Key ヘッダー（.env の API_KEY と照合）
 *       API_KEY 未設定時はローカル開発用として全許可
 */
import type { FastifyInstance } from 'fastify';
import { client } from '../../bot/client.js';
import * as TicketModel      from '../../db/models/ticket.js';
import * as GuildModel       from '../../db/models/guild.js';
import * as MemberModel      from '../../db/models/member.js';
import * as EmbedModelDB     from '../../db/models/embed.js';
import * as AutoResponseModel from '../../db/models/autoResponse.js';
import * as ScheduleModel    from '../../db/models/schedule.js';
import * as AuditLogModel    from '../../db/models/auditLog.js';
import * as SettingsModel    from '../../db/models/ticketSettings.js';
import { closeTicket, reopenTicket } from '../../bot/services/ticket.js';
import { getBotGlobalStatus } from './bot.js';
import type { Ticket, Member, Embed } from '../../shared/types.js';
import type { TextChannel } from 'discord.js';

const API_KEY = process.env['API_KEY'] ?? '';

// =====================================================
// 型マッピングヘルパー
// =====================================================

/** SQLite の datetime 文字列を ISO8601 に正規化 */
function toIso(s: string | null | undefined): string {
  if (!s) return new Date().toISOString();
  if (s.includes('T')) return s.endsWith('Z') ? s : s + 'Z';
  return s.replace(' ', 'T') + '.000Z';
}

function mapTicket(t: Ticket) {
  return {
    id:                String(t.id),
    guildId:           t.guild_id,
    channelId:         t.channel_id,
    openedBy:          t.opened_by_user_id,
    subject:           t.subject,
    status:            t.status,
    priority:          t.priority,
    assignedToUserId:  t.assigned_to_user_id ?? null,
    panelId:           t.panel_id ?? null,
    openedAt:          toIso(t.opened_at),
    closedAt:          t.closed_at ? toIso(t.closed_at) : null,
    lastMessageAt:     toIso(t.last_message_at),
    messageCount:      t.message_count,
  };
}

function mapTicketMessage(m: import('../../shared/types.js').TicketMessage) {
  return {
    id:        String(m.id),
    ticketId:  String(m.ticket_id),
    userId:    m.user_id,
    username:  m.username,
    content:   m.content,
    isStaff:   m.is_staff === 1,
    createdAt: toIso(m.created_at),
  };
}

function mapMember(m: Member) {
  let roles: string[] = [];
  try { roles = JSON.parse(m.roles); } catch { roles = []; }
  return {
    id:          m.user_id,
    guildId:     m.guild_id,
    username:    m.username,
    displayName: m.display_name ?? m.username,
    avatarUrl:   m.avatar_url ?? null,
    roles,
    joinedAt:    toIso(m.joined_at ?? new Date().toISOString()),
    isBoosting:  m.is_boosting === 1,
    status:      'offline' as const,
  };
}

function mapEmbed(e: Embed) {
  return {
    id:            String(e.id),
    name:          e.name,
    authorName:    e.author_name ?? null,
    authorIconUrl: e.author_icon_url ?? null,
    authorUrl:     null,
    title:         e.title ?? null,
    embedUrl:      null,
    description:   e.description ?? null,
    colorHex:      e.color ?? 0x6366f1,
    fields:       (e.fields ?? []).map((f: { id?: number; name: string; value: string; inline: boolean }) => ({
      id:     String(f.id ?? Math.random()),
      name:   f.name,
      value:  f.value,
      inline: f.inline,
    })),
    imageUrl:      e.image_url ?? null,
    thumbnailUrl:  e.thumbnail_url ?? null,
    footerText:    e.footer_text ?? null,
    footerIconUrl: e.footer_icon_url ?? null,
    showTimestamp: false,
    createdAt:     toIso(e.created_at),
    updatedAt:     toIso(e.updated_at),
  };
}

// triggerType: DB↔iOS の変換
const triggerTypeToiOS: Record<string, string> = {
  contains:   'contains',
  exact:      'exact',
  regex:      'regex',
  starts_with: 'startsWith',
  ends_with:  'contains', // iOS に ends_with なし → contains にフォールバック
};
const triggerTypeToDB: Record<string, string> = {
  contains:   'contains',
  exact:      'exact',
  regex:      'regex',
  startsWith: 'starts_with',
};

function mapAutoResponse(ar: import('../../db/models/autoResponse.js').AutoResponse) {
  let channelIds: string[] = [];
  try { channelIds = JSON.parse(ar.channel_ids); } catch { channelIds = []; }
  return {
    id:             String(ar.id),
    guildId:        ar.guild_id,
    trigger:        ar.trigger,
    response:       ar.response,
    matchType:      triggerTypeToiOS[ar.trigger_type] ?? 'contains',
    enabled:        ar.is_enabled === 1,
    cooldownSeconds: ar.cooldown_sec,
    channelIds,
  };
}

function mapScheduled(s: import('../../db/models/schedule.js').ScheduledSend) {
  const repeatMap: Record<string, string> = {
    none: 'none', daily: 'daily', weekly: 'weekly', monthly: 'monthly',
  };
  const statusMap: Record<string, string> = {
    pending: 'pending', sent: 'sent', cancelled: 'cancelled',
    active: 'pending', failed: 'cancelled',
  };
  return {
    id:           String(s.id),
    guildId:      s.guild_id,
    channelId:    s.channel_id,
    embedId:      s.embed_id ? String(s.embed_id) : '',
    scheduledFor: toIso(s.scheduled_for),
    repeatRule:   repeatMap[s.recurrence] ?? 'none',
    status:       statusMap[s.status] ?? 'pending',
  };
}

function mapAuditLog(e: import('../../db/models/auditLog.js').AuditLogEntry) {
  return {
    id:        String(e.id),
    guildId:   e.guild_id,
    userId:    e.actor_id ?? '',
    action:    e.action,
    target:    e.target_tag ?? e.target_id ?? '',
    timestamp: toIso(e.created_at),
    details:   e.detail ?? null,
  };
}

// =====================================================
// ルート登録
// =====================================================

export async function apiRoutes(app: FastifyInstance): Promise<void> {

  // API キー認証
  app.addHook('preHandler', async (req, reply) => {
    if (!req.url.startsWith('/api/')) return;
    if (!API_KEY) return;
    if (req.headers['x-api-key'] !== API_KEY) {
      return reply.status(401).send({ error: 'Unauthorized' });
    }
  });

  // =====================================================
  // Bot ステータス
  // =====================================================
  app.get('/api/v1/bot/status', async (_req, reply) => {
    const s = getBotGlobalStatus();
    return reply.send({
      isOnline:      s.online,
      latency:       s.online ? Math.round(client.ws.ping) : 0,
      uptime:        Math.round(process.uptime()),
      activeGuilds:  client.guilds.cache.size,
      totalCommands: 1,
    });
  });

  // =====================================================
  // Guilds
  // =====================================================
  app.get('/api/v1/guilds', async (_req, reply) => {
    return reply.send(GuildModel.listAll().map(g => ({
      id: g.id, discordId: g.id, name: g.name,
      iconUrl: g.icon_url ?? null, memberCount: g.member_count,
      userRole: 'admin', category: 'support',
    })));
  });

  app.get<{ Params: { id: string } }>('/api/v1/guilds/:id', async (req, reply) => {
    const g = GuildModel.findById(req.params.id);
    if (!g) return reply.status(404).send({ error: 'Not found' });
    return reply.send({
      id: g.id, discordId: g.id, name: g.name,
      iconUrl: g.icon_url ?? null, memberCount: g.member_count,
      userRole: 'admin', category: 'support',
    });
  });

  app.get<{ Params: { id: string } }>('/api/v1/guilds/:id/channels', async (req, reply) => {
    const typeMap: Record<number, string> = { 0: 'text', 2: 'voice', 5: 'announcement' };
    return reply.send(GuildModel.listChannels(req.params.id).map(c => ({
      id: c.id, guildId: c.guild_id, name: c.name,
      type: typeMap[c.type] ?? 'text', categoryName: null, botCanSend: true,
    })));
  });

  // =====================================================
  // Tickets
  // =====================================================
  app.get('/api/v1/tickets', async (req, reply) => {
    const q = req.query as Record<string, string>;
    if (!q['guildId']) return reply.send([]);
    return reply.send(TicketModel.listByGuild(q['guildId'], q['status']).map(mapTicket));
  });

  app.get<{ Params: { id: string } }>('/api/v1/tickets/:id', async (req, reply) => {
    const t = TicketModel.findById(Number(req.params.id));
    if (!t) return reply.status(404).send({ error: 'Not found' });
    return reply.send(mapTicket(t));
  });

  app.post<{ Params: { id: string } }>('/api/v1/tickets/:id/close', async (req, reply) => {
    await closeTicket(Number(req.params.id));
    return reply.send({ ok: true });
  });

  app.post<{ Params: { id: string } }>('/api/v1/tickets/:id/reopen', async (req, reply) => {
    await reopenTicket(Number(req.params.id));
    return reply.send({ ok: true });
  });

  app.post<{ Params: { id: string } }>('/api/v1/tickets/:id/priority', async (req, reply) => {
    const body = req.body as Record<string, string>;
    const priority = body['priority'];
    if (!['low', 'medium', 'high', 'urgent'].includes(priority))
      return reply.status(400).send({ error: 'Invalid priority' });
    TicketModel.updatePriority(Number(req.params.id), priority);
    return reply.send(mapTicket(TicketModel.findById(Number(req.params.id))!));
  });

  // メッセージ一覧
  app.get<{ Params: { id: string } }>('/api/v1/tickets/:id/messages', async (req, reply) => {
    const ticket = TicketModel.findById(Number(req.params.id));
    if (!ticket) return reply.status(404).send({ error: 'Not found' });
    return reply.send(TicketModel.getMessages(ticket.id).map(mapTicketMessage));
  });

  // スタッフからの返信（アプリ → Discordチャンネル + DB記録）
  app.post<{ Params: { id: string } }>('/api/v1/tickets/:id/reply', async (req, reply) => {
    const body   = req.body as Record<string, string>;
    const content = (body['content'] ?? '').trim();
    if (!content) return reply.status(400).send({ error: 'content is required' });

    const ticket = TicketModel.findById(Number(req.params.id));
    if (!ticket) return reply.status(404).send({ error: 'Not found' });
    if (ticket.status === 'closed') return reply.status(400).send({ error: 'Ticket is closed' });

    // DB に記録
    const msg = TicketModel.addMessage({
      ticket_id: ticket.id,
      user_id:   'app-staff',
      username:  'Staff (App)',
      content,
      is_staff:  true,
    });

    // Discord チャンネルに送信
    try {
      const { client } = await import('../../bot/client.js');
      const channel = client.channels.cache.get(ticket.channel_id);
      if (channel?.isTextBased()) {
        await (channel as import('discord.js').TextChannel).send({
          content,
          embeds: [{
            description: content,
            color: 0x6366f1,
            author: { name: '📱 アプリからのスタッフ返信' },
            timestamp: new Date().toISOString(),
          }],
        });
      }
    } catch { /* Discord 送信失敗は無視（DB 記録は成功） */ }

    return reply.send(mapTicketMessage(msg));
  });

  // 担当者割り当て
  app.post<{ Params: { id: string } }>('/api/v1/tickets/:id/assign', async (req, reply) => {
    const body   = req.body as Record<string, string>;
    const userId = (body['userId'] ?? '').trim();
    if (!userId) return reply.status(400).send({ error: 'userId is required' });

    const ticket = TicketModel.findById(Number(req.params.id));
    if (!ticket) return reply.status(404).send({ error: 'Not found' });

    TicketModel.assign(ticket.id, userId);

    // Discordチャンネルにも追加
    try {
      const { client }  = await import('../../bot/client.js');
      const { PermissionFlagsBits } = await import('discord.js');
      const channel = client.channels.cache.get(ticket.channel_id);
      if (channel?.isTextBased()) {
        await (channel as import('discord.js').TextChannel).permissionOverwrites.edit(userId, {
          ViewChannel: true, SendMessages: true, ReadMessageHistory: true,
        });
      }
    } catch { /* ignore */ }

    return reply.send(mapTicket(TicketModel.findById(ticket.id)!));
  });

  // =====================================================
  // Members
  // =====================================================
  app.get('/api/v1/members', async (req, reply) => {
    const q = req.query as Record<string, string>;
    if (!q['guildId']) return reply.send([]);
    return reply.send(
      MemberModel.listByGuild(q['guildId'], { search: q['search'], limit: 100 }).map(mapMember)
    );
  });

  // =====================================================
  // Embeds（CRUD + 送信）
  // =====================================================
  app.get('/api/v1/embeds', async (_req, reply) => {
    return reply.send(EmbedModelDB.listAll().map(mapEmbed));
  });

  app.get<{ Params: { id: string } }>('/api/v1/embeds/:id', async (req, reply) => {
    const e = EmbedModelDB.findById(Number(req.params.id));
    if (!e) return reply.status(404).send({ error: 'Not found' });
    return reply.send(mapEmbed(e));
  });

  app.post('/api/v1/embeds', async (req, reply) => {
    const b = req.body as Record<string, unknown>;
    const e = EmbedModelDB.create({
      name:          String(b['name'] ?? ''),
      title:         b['title'] ? String(b['title']) : null,
      description:   b['description'] ? String(b['description']) : null,
      color:         Number(b['colorHex'] ?? 0x6366f1),
      fields:        (b['fields'] as { name: string; value: string; inline: boolean }[]) ?? [],
      image_url:     b['imageUrl'] ? String(b['imageUrl']) : null,
      thumbnail_url: b['thumbnailUrl'] ? String(b['thumbnailUrl']) : null,
      footer_text:   b['footerText'] ? String(b['footerText']) : null,
      footer_icon_url: b['footerIconUrl'] ? String(b['footerIconUrl']) : null,
      author_name:   null,
      author_icon_url: null,
    });
    return reply.status(201).send(mapEmbed(e));
  });

  app.put<{ Params: { id: string } }>('/api/v1/embeds/:id', async (req, reply) => {
    const b = req.body as Record<string, unknown>;
    EmbedModelDB.update(Number(req.params.id), {
      name:          b['name'] ? String(b['name']) : undefined,
      title:         b['title'] ? String(b['title']) : null,
      description:   b['description'] ? String(b['description']) : null,
      color:         b['colorHex'] !== undefined ? Number(b['colorHex']) : undefined,
      fields:        b['fields'] as { name: string; value: string; inline: boolean }[] | undefined,
      image_url:     b['imageUrl'] ? String(b['imageUrl']) : null,
      thumbnail_url: b['thumbnailUrl'] ? String(b['thumbnailUrl']) : null,
      footer_text:   b['footerText'] ? String(b['footerText']) : null,
      footer_icon_url: b['footerIconUrl'] ? String(b['footerIconUrl']) : null,
    });
    const e = EmbedModelDB.findById(Number(req.params.id));
    if (!e) return reply.status(404).send({ error: 'Not found' });
    return reply.send(mapEmbed(e));
  });

  app.delete<{ Params: { id: string } }>('/api/v1/embeds/:id', async (req, reply) => {
    EmbedModelDB.remove(Number(req.params.id));
    return reply.send({ ok: true });
  });

  app.post<{ Params: { id: string } }>('/api/v1/embeds/:id/send', async (req, reply) => {
    const b = req.body as Record<string, string>;
    const embed = EmbedModelDB.findById(Number(req.params.id));
    if (!embed) return reply.status(404).send({ error: 'Embed not found' });
    const channel = client.channels.cache.get(b['channelId']) as TextChannel | undefined;
    if (!channel?.isTextBased()) return reply.status(400).send({ error: 'Channel not found' });
    await channel.send({
      embeds: [{
        title:       embed.title ?? undefined,
        description: embed.description ?? undefined,
        color:       embed.color ?? undefined,
        fields:      embed.fields ?? [],
        image:       embed.image_url ? { url: embed.image_url } : undefined,
        thumbnail:   embed.thumbnail_url ? { url: embed.thumbnail_url } : undefined,
        footer:      embed.footer_text ? { text: embed.footer_text } : undefined,
      }],
    });
    return reply.send({ ok: true });
  });

  // =====================================================
  // Auto Responses（CRUD）
  // =====================================================
  app.get('/api/v1/auto-responses', async (req, reply) => {
    const q = req.query as Record<string, string>;
    if (!q['guildId']) return reply.send([]);
    return reply.send(AutoResponseModel.listByGuild(q['guildId']).map(mapAutoResponse));
  });

  app.post('/api/v1/auto-responses', async (req, reply) => {
    const b = req.body as Record<string, unknown>;
    const guildId = String(b['guildId'] ?? '');
    if (!guildId) return reply.status(400).send({ error: 'guildId required' });
    const ar = AutoResponseModel.create({
      guild_id:     guildId,
      name:         String(b['trigger'] ?? ''),
      trigger_type: triggerTypeToDB[String(b['matchType'] ?? 'contains')] as 'contains' | 'exact' | 'regex' | 'starts_with' | 'ends_with' ?? 'contains',
      trigger:      String(b['trigger'] ?? ''),
      response:     String(b['response'] ?? ''),
      response_type: 'text',
      embed_title:  null,
      embed_color:  0,
      is_enabled:   1,
      match_case:   0,
      channel_ids:  JSON.stringify(b['channelIds'] ?? []),
      cooldown_sec: Number(b['cooldownSeconds'] ?? 0),
      delete_trigger: 0,
    });
    return reply.status(201).send(mapAutoResponse(ar));
  });

  app.put<{ Params: { id: string } }>('/api/v1/auto-responses/:id', async (req, reply) => {
    const b = req.body as Record<string, unknown>;
    AutoResponseModel.update(Number(req.params.id), {
      trigger:      b['trigger'] ? String(b['trigger']) : undefined,
      response:     b['response'] ? String(b['response']) : undefined,
      trigger_type: b['matchType'] ? triggerTypeToDB[String(b['matchType'])] as 'contains' | 'exact' | 'regex' | 'starts_with' | 'ends_with' : undefined,
      is_enabled:   b['enabled'] !== undefined ? (b['enabled'] ? 1 : 0) : undefined,
      cooldown_sec: b['cooldownSeconds'] !== undefined ? Number(b['cooldownSeconds']) : undefined,
      channel_ids:  b['channelIds'] !== undefined ? JSON.stringify(b['channelIds']) : undefined,
    });
    const ar = AutoResponseModel.findById(Number(req.params.id));
    if (!ar) return reply.status(404).send({ error: 'Not found' });
    return reply.send(mapAutoResponse(ar));
  });

  app.delete<{ Params: { id: string } }>('/api/v1/auto-responses/:id', async (req, reply) => {
    AutoResponseModel.remove(Number(req.params.id));
    return reply.send({ ok: true });
  });

  app.post<{ Params: { id: string } }>('/api/v1/auto-responses/:id/toggle', async (req, reply) => {
    const b = req.body as Record<string, boolean>;
    AutoResponseModel.toggle(Number(req.params.id), b['enabled'] ?? true);
    return reply.send({ ok: true });
  });

  // =====================================================
  // Scheduled Messages（一覧 + キャンセル）
  // =====================================================
  app.get('/api/v1/scheduled-messages', async (_req, reply) => {
    const all = [
      ...ScheduleModel.listByType('once'),
      ...ScheduleModel.listByType('recurring'),
    ].sort((a, b) => new Date(a.scheduled_for).getTime() - new Date(b.scheduled_for).getTime());
    return reply.send(all.map(mapScheduled));
  });

  app.post<{ Params: { id: string } }>('/api/v1/scheduled-messages/:id/cancel', async (req, reply) => {
    ScheduleModel.updateStatus(Number(req.params.id), 'cancelled');
    return reply.send({ ok: true });
  });

  // =====================================================
  // Audit Log
  // =====================================================
  app.get('/api/v1/audit-logs', async (req, reply) => {
    const q = req.query as Record<string, string>;
    if (!q['guildId']) return reply.send([]);
    const logs = AuditLogModel.listByGuild(q['guildId'], 100);
    return reply.send(logs.map(mapAuditLog));
  });

  // =====================================================
  // Analytics（利用可能な実データ）
  // =====================================================
  app.get('/api/v1/analytics', async (req, reply) => {
    const q = req.query as Record<string, string>;
    const guildId = q['guildId'] ?? '';
    const guild = GuildModel.findById(guildId);
    const openTickets   = guildId ? TicketModel.listByGuild(guildId, 'open').length  : 0;
    const totalMembers  = guild?.member_count ?? 0;
    return reply.send({
      guildId,
      totalMembers,
      memberGrowthPercent:  0,
      messagesToday:        0,
      messageGrowthPercent: 0,
      commandsUsed:         0,
      commandGrowthPercent: 0,
      activeTickets:        openTickets,
      voiceMinutes:         0,
      memberHistory:        Array(7).fill(totalMembers),
      messageHistory:       Array(7).fill(0),
    });
  });

  // =====================================================
  // Notifications（アプリ内通知 = 監査ログから生成）
  // =====================================================
  app.get('/api/v1/notifications', async (req, reply) => {
    const q = req.query as Record<string, string>;
    const guildId = q['guildId'] ?? '';
    if (!guildId) return reply.send([]);
    const logs = AuditLogModel.listByGuild(guildId, 20);
    const notifications = logs.map(l => ({
      id:        String(l.id),
      type:      'system',
      title:     l.action,
      body:      [l.actor_tag, l.target_tag].filter(Boolean).join(' → ') || l.detail || '',
      guildId,
      read:      true,
      timestamp: toIso(l.created_at),
    }));
    return reply.send(notifications);
  });

  // =====================================================
  // Ticket Panels
  // =====================================================
  app.get('/api/v1/ticket-panels', async (req, reply) => {
    const q = req.query as Record<string, string>;
    if (!q['guildId']) return reply.send([]);
    return reply.send(SettingsModel.listPanels(q['guildId']).map(p => ({
      id:             String(p.id),
      guildId:        p.guild_id,
      channelId:      p.channel_id,
      title:          p.title,
      description:    p.description,
      buttonLabel:    p.button_label,
      buttonEmoji:    p.button_emoji,
      isDeployed:     !!p.message_id,
      supportRoleId:  p.support_role_id ?? null,
      maxOpenPerUser: p.max_open_per_user,
    })));
  });
}
