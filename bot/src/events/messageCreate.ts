import { Events, type Message, PermissionFlagsBits } from 'discord.js';
import { client } from '../client.js';
import { supabase } from '../db.js';

// ── AutoMod Settings Cache (#3: メッセージごとのSupabaseクエリを削減) ──────
const settingsCache = new Map<string, { data: any; expiresAt: number }>();
const SETTINGS_TTL_MS = 30_000; // 30秒キャッシュ

async function getAutomodSettings(guildId: string): Promise<any | null> {
  const cached = settingsCache.get(guildId);
  if (cached && Date.now() < cached.expiresAt) return cached.data;

  const { data } = await supabase
    .from('automod_settings')
    .select('*')
    .eq('guild_id', guildId)
    .single();

  if (data) {
    settingsCache.set(guildId, { data, expiresAt: Date.now() + SETTINGS_TTL_MS });
  } else {
    // 設定なしもキャッシュ（null で短期間）
    settingsCache.set(guildId, { data: null, expiresAt: Date.now() + SETTINGS_TTL_MS });
  }
  return data ?? null;
}

// ── AutoMod Violation Tracking (in-memory) ──────────────────────
const violationCounts = new Map<string, { count: number; lastReset: number }>();

function getViolations(userId: string, guildId: string): number {
  const key = `${guildId}:${userId}`;
  const entry = violationCounts.get(key);
  if (!entry) return 0;
  // Reset after 1 hour
  if (Date.now() - entry.lastReset > 3600000) {
    violationCounts.delete(key);
    return 0;
  }
  return entry.count;
}

function addViolation(userId: string, guildId: string): number {
  const key = `${guildId}:${userId}`;
  const entry = violationCounts.get(key);
  const newCount = entry ? entry.count + 1 : 1;
  violationCounts.set(key, { count: newCount, lastReset: Date.now() });
  return newCount;
}

// ── Message History Cache (#2: スパム・重複検知用) ───────────────────────
// Map<"guildId:userId", { timestamps: number[]; contents: string[] }>
const messageHistory = new Map<string, { timestamps: number[]; contents: string[] }>();
const SPAM_WINDOW_MS   = 5_000;  // 5秒以内に
const SPAM_THRESHOLD   = 5;      // 5件以上でスパム
const DUP_WINDOW_MS    = 10_000; // 10秒以内の
const DUP_THRESHOLD    = 3;      // 3回以上の同一内容で重複

function trackMessage(userId: string, guildId: string, content: string): void {
  const key = `${guildId}:${userId}`;
  const now = Date.now();
  const hist = messageHistory.get(key) ?? { timestamps: [], contents: [] };

  // 古いエントリを削除（最大ウィンドウより古いもの）
  const maxWindow = Math.max(SPAM_WINDOW_MS, DUP_WINDOW_MS);
  const cutoff = now - maxWindow;
  let i = 0;
  while (i < hist.timestamps.length && hist.timestamps[i] < cutoff) i++;
  hist.timestamps = hist.timestamps.slice(i);
  hist.contents   = hist.contents.slice(i);

  hist.timestamps.push(now);
  hist.contents.push(content.toLowerCase().trim());
  messageHistory.set(key, hist);
}

function checkSpam(message: Message, settings: any): boolean {
  if (!settings.msgSpamEnabled) return false;
  const key = `${message.guildId}:${message.author.id}`;
  const hist = messageHistory.get(key);
  if (!hist) return false;
  const now = Date.now();
  const recentCount = hist.timestamps.filter(t => now - t <= SPAM_WINDOW_MS).length;
  return recentCount >= SPAM_THRESHOLD;
}

function checkDuplicateMessage(message: Message, settings: any): boolean {
  if (!settings.dupMsgEnabled) return false;
  const key = `${message.guildId}:${message.author.id}`;
  const hist = messageHistory.get(key);
  if (!hist) return false;
  const now = Date.now();
  const target = message.content.toLowerCase().trim();
  if (target.length < 4) return false; // 短すぎる文字列は無視

  let dupCount = 0;
  for (let i = 0; i < hist.timestamps.length; i++) {
    if (now - hist.timestamps[i] <= DUP_WINDOW_MS && hist.contents[i] === target) {
      dupCount++;
    }
  }
  return dupCount >= DUP_THRESHOLD;
}

// ── AutoMod Rule Checks ─────────────────────────────────────────

function isExempt(message: Message, settings: any): boolean {
  const member = message.member;
  if (!member) return false;
  const exemptRoles = settings.exemptRoles ?? [];
  return member.roles.cache.some(r => exemptRoles.includes(r.name));
}

function checkMentions(message: Message, settings: any): boolean {
  if (!settings.mentionEnabled && !settings.massMentionEnabled) return false;
  const mentionCount = message.mentions.users.size + message.mentions.roles.size;
  const limit = settings.massMentionEnabled ? settings.massMentionLimit : settings.mentionLimit;
  return mentionCount >= limit;
}

function checkKeywords(message: Message, settings: any): string | null {
  if (!settings.keywordEnabled) return null;
  const keywords = settings.blockedKeywords ?? [];
  const content = message.content.toLowerCase();
  for (const kw of keywords) {
    if (content.includes(kw.toLowerCase())) return kw;
  }
  return null;
}

function checkRegex(message: Message, settings: any): string | null {
  if (!settings.regexEnabled) return null;
  const patterns = settings.blockedRegex ?? [];
  for (const pattern of patterns) {
    try {
      const regex = new RegExp(pattern, 'i');
      if (regex.test(message.content)) return pattern;
    } catch { /* invalid regex, skip */ }
  }
  return null;
}

function checkInviteLink(message: Message, settings: any): boolean {
  if (!settings.inviteLinkEnabled) return false;
  return /(discord\.gg|discord\.com\/invite|discordapp\.com\/invite)\/[a-zA-Z0-9]+/i.test(message.content);
}

function checkPhishing(message: Message, settings: any): boolean {
  if (!settings.phishingEnabled) return false;
  const phishingPatterns = [
    /discord\.gift\/[a-zA-Z0-9]+/i,
    /free.*nitro/i,
    /claim.*nitro/i,
    /steamcommunity\.com\/gift/i,
  ];
  return phishingPatterns.some(p => p.test(message.content));
}

function checkLinkFilter(message: Message, settings: any): boolean {
  if (!settings.linkFilterEnabled) return false;
  const urlRegex = /https?:\/\/[^\s]+/gi;
  const urls = message.content.match(urlRegex);
  if (!urls) return false;
  const mode = settings.linkMode;
  if (mode === 'allowAll') return false;
  if (mode === 'blockAll') return true;
  const allowed = settings.allowedLinks ?? [];
  return urls.some(url => {
    return !allowed.some((a: string) => url.toLowerCase().includes(a.toLowerCase()));
  });
}

function checkCaps(message: Message, settings: any): boolean {
  if (!settings.capsEnabled) return false;
  const content = message.content.replace(/[^a-zA-Z]/g, '');
  if (content.length < 5) return false;
  const capsCount = content.replace(/[^A-Z]/g, '').length;
  const percent = (capsCount / content.length) * 100;
  return percent >= settings.capsPercent;
}

// ── Action Handler ──────────────────────────────────────────────

async function takeAction(message: Message, settings: any, reason: string, violationCount: number) {
  if (settings.escalationEnabled) {
    const steps = settings.escalationSteps ?? [];
    for (const step of steps.sort((a: any, b: any) => a.violations - b.violations)) {
      if (violationCount >= step.violations) {
        await executeAction(message, step.action, reason);
        return;
      }
    }
  }
  await executeAction(message, settings.defaultAction, reason);
}

async function executeAction(message: Message, action: string | { type: string; minutes?: number }, reason: string) {
  const actionType = typeof action === 'string' ? action : action.type;

  try {
    const dm = await message.author.createDM();
    await dm.send({
      embeds: [{
        title: '⚠️ 警告を受け取りました',
        description: `**サーバー:** ${message.guild?.name}\n**理由:** ${reason}\n\n警告が蓄積されると、タイムアウト・キック・BANなどの自動アクションが実行される場合があります。`,
        color: 0xF59E0B,
        timestamp: new Date().toISOString(),
      }],
    }).catch(() => {});
  } catch { /* DM送信失敗は無視 */ }

  // channel.send が利用できるチャンネルのみ送信
  const sendReply = async (content: string) => {
    if ('send' in message.channel) {
      await (message.channel as import('discord.js').TextChannel).send({ content }).catch(() => {});
    }
  };

  switch (actionType) {
    case 'deleteOnly':
    case 'delete_and_warn':
    case 'warn':
      await message.delete().catch(() => {});
      await sendReply(`⚠️ ${message.author} 規約違反: ${reason}`);
      break;

    case 'deleteAndTimeout':
    case 'delete_and_timeout':
    case 'timeout': {
      await message.delete().catch(() => {});
      const minutes = typeof action === 'object' ? (action.minutes ?? 60) : 60;
      // discord.js v14: timeout() はミリ秒を受け取る
      await message.member?.timeout(minutes * 60 * 1000, reason).catch(() => {});
      await sendReply(`⏰ ${message.author} ${minutes}分タイムアウト: ${reason}`);
      break;
    }

    case 'deleteAndKick':
    case 'delete_and_kick':
    case 'kick':
      await message.delete().catch(() => {});
      await message.member?.kick(reason).catch(() => {});
      await sendReply(`👢 ${message.author} キック: ${reason}`);
      break;

    case 'deleteAndBan':
    case 'delete_and_ban':
    case 'ban':
      await message.delete().catch(() => {});
      await message.member?.ban({ reason, deleteMessageSeconds: 3600 }).catch(() => {});
      await sendReply(`🚫 ${message.author} BAN: ${reason}`);
      break;

    default:
      await message.delete().catch(() => {});
  }
}

// ── Auto-Response Check ─────────────────────────────────────────

async function checkAutoResponses(message: Message): Promise<boolean> {
  const { data: rules } = await supabase
    .from('auto_responses')
    .select('*')
    .eq('guild_id', message.guildId!)
    .eq('is_enabled', true);

  if (!rules || rules.length === 0) return false;

  const content = message.content;

  for (const rule of rules) {
    // クールダウンチェック
    if (rule.cooldown_sec > 0) {
      const cdKey = `ar_cd:${rule.id}:${message.author.id}`;
      const cdEntry = violationCounts.get(cdKey);
      if (cdEntry && Date.now() - cdEntry.lastReset < rule.cooldown_sec * 1000) continue;
    }

    // チャンネル制限チェック
    if (rule.channel_ids && rule.channel_ids.length > 0) {
      if (!rule.channel_ids.includes(message.channelId)) continue;
    }

    let matched = false;
    const trigger: string = rule.trigger ?? '';
    switch (rule.trigger_type) {
      case 'exact':
        matched = content.toLowerCase() === trigger.toLowerCase();
        break;
      case 'contains':
        matched = content.toLowerCase().includes(trigger.toLowerCase());
        break;
      case 'starts_with':
        matched = content.toLowerCase().startsWith(trigger.toLowerCase());
        break;
      case 'ends_with':
        matched = content.toLowerCase().endsWith(trigger.toLowerCase());
        break;
      case 'regex':
        try { matched = new RegExp(trigger, 'i').test(content); } catch { matched = false; }
        break;
    }

    if (matched) {
      if ('send' in message.channel) {
        await (message.channel as import('discord.js').TextChannel).send(rule.response).catch(() => {});
      }
      // クールダウンを記録
      if (rule.cooldown_sec > 0) {
        const cdKey = `ar_cd:${rule.id}:${message.author.id}`;
        violationCounts.set(cdKey, { count: 1, lastReset: Date.now() });
      }
      return true;
    }
  }
  return false;
}

// ── Main Event Handler ──────────────────────────────────────────

client.on(Events.MessageCreate, async (message: Message) => {
  if (message.author.bot) return;
  if (!message.guildId) return;
  if (!message.content) return;

  // --- チケットチャンネルへの返信を Supabase に記録 ---
  const { data: ticket } = await supabase
    .from('tickets')
    .select('id, status')
    .eq('channel_id', message.channelId)
    .single();

  if (ticket && ticket.status !== 'closed') {
    await supabase.from('ticket_messages').insert({
      ticket_id: ticket.id,
      user_id:   message.author.id,
      username:  message.author.username,
      content:   message.content || '[添付ファイル]',
      is_staff:  false,
    });
    // #4: アトミックな UPDATE（SELECT+UPDATE の競合を排除）
    await supabase.from('tickets')
      .update({ last_message_at: new Date().toISOString() })
      .eq('id', ticket.id);
    await supabase.rpc('increment_ticket_message_count', { p_ticket_id: ticket.id });
    return; // チケットチャンネルは AutoMod / 自動応答をスキップ
  }

  // --- メッセージ履歴を記録 (#2: スパム・重複検知用) ---
  trackMessage(message.author.id, message.guildId, message.content);

  // --- AutoMod チェック (キャッシュ付き #3) ---
  const settings = await getAutomodSettings(message.guildId);

  if (settings && !isExempt(message, settings)) {
    const botMember = message.guild?.members.me;
    const canDelete = botMember?.permissions.has(PermissionFlagsBits.ManageMessages);

    let violationReason: string | null = null;

    if (checkSpam(message, settings)) {
      violationReason = 'スパム検出（短時間に大量送信）';
    } else if (checkDuplicateMessage(message, settings)) {
      violationReason = '同一メッセージの繰り返し';
    } else if (checkMentions(message, settings)) {
      violationReason = 'メンション制限違反';
    } else if (checkKeywords(message, settings)) {
      violationReason = `禁止キーワード検出: ${checkKeywords(message, settings)}`;
    } else if (checkRegex(message, settings)) {
      violationReason = `正規表現ルール違反: ${checkRegex(message, settings)}`;
    } else if (checkInviteLink(message, settings)) {
      violationReason = '招待リンク禁止';
    } else if (checkPhishing(message, settings)) {
      violationReason = 'フィッシングURL検出';
    } else if (checkLinkFilter(message, settings)) {
      violationReason = 'リンクフィルター違反';
    } else if (checkCaps(message, settings)) {
      violationReason = 'キャピタルロック違反';
    }

    if (violationReason && canDelete) {
      const count = addViolation(message.author.id, message.guildId!);
      await takeAction(message, settings, violationReason, count);

      if (settings.logEnabled && settings.logChannelId) {
        const logChannel = message.guild?.channels.cache.get(settings.logChannelId);
        if (logChannel?.isTextBased()) {
          await logChannel.send({
            embeds: [{
              title: '🚨 AutoMod 違反検出',
              description: `**ユーザー:** ${message.author}\n**理由:** ${violationReason}\n**違反回数:** ${count}回\n**メッセージ:** ${message.content.substring(0, 500)}`,
              color: 0xEF4444,
              timestamp: new Date().toISOString(),
            }],
          }).catch(() => {});
        }
      }
      return; // 違反メッセージは自動応答をスキップ
    }
  }

  // --- 自動応答チェック (#8) ---
  await checkAutoResponses(message).catch(() => {});
});
