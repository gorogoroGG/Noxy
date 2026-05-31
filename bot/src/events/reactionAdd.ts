import { Events, MessageReaction, PartialMessageReaction, User, PartialUser } from 'discord.js';
import { client } from '../client';
import { supabase } from '../db';

// ── 型定義 ───────────────────────────────────────────────────

interface ReactionPair {
  id: string;
  emoji: string;
  role_id: string;
  role_name: string;
}

interface ReactionRoleConfig {
  id: string;
  guild_id: string;
  channel_id: string;
  pairs: ReactionPair[];
  mode: string; // "通常" | "認証" | "永続"
}

// ── ユーティリティ ────────────────────────────────────────────

// カスタム絵文字 <:name:id> / <a:name:id> とUnicode絵文字を統一フォーマットに変換
function toEmojiKey(reaction: MessageReaction | PartialMessageReaction): string {
  if (reaction.emoji.id) {
    const prefix = reaction.emoji.animated ? 'a' : '';
    return `<${prefix}:${reaction.emoji.name}:${reaction.emoji.id}>`;
  }
  return (reaction.emoji.name ?? '').replace(/️/g, ''); // variation selector除去
}

// ── イベントハンドラ ──────────────────────────────────────────

client.on(
  Events.MessageReactionAdd,
  async (reaction: MessageReaction | PartialMessageReaction, user: User | PartialUser) => {
    console.log(`[ReactionRole] 🔔 イベント受信 emoji=${reaction.emoji.name} user=${user.id}`);

    // Bot自身のリアクションは無視
    if (user.bot) return;

    // Partialの場合はフル情報を取得（古いメッセージへの対応）
    if (reaction.partial) {
      try { await reaction.fetch(); } catch { return; }
    }

    const guild = reaction.message.guild;
    if (!guild) { console.log('[ReactionRole] guild なし（DM？）'); return; }

    const emojiKey = toEmojiKey(reaction);
    console.log(`[ReactionRole] emojiKey=${emojiKey} channelId=${reaction.message.channelId} guildId=${guild.id}`);

    // Supabaseからこのチャンネルのリアクションロール設定を取得
    const { data: configs, error } = await supabase
      .from('reaction_roles')
      .select('*')
      .eq('guild_id', guild.id)
      .eq('channel_id', reaction.message.channelId);

    console.log(`[ReactionRole] Supabase結果: ${configs?.length ?? 0}件`, error?.message ?? '');

    if (error) {
      console.error('[ReactionRole] Supabase error:', error.message);
      return;
    }
    if (!configs?.length) return;

    for (const config of configs as ReactionRoleConfig[]) {
      // 絵文字が一致するペアを探す
      const pair = config.pairs.find(
        (p) => p.emoji.replace(/️/g, '') === emojiKey
      );
      if (!pair) continue;

      try {
        const member = await guild.members.fetch(user.id);
        await member.roles.add(pair.role_id);
        console.log(
          `[ReactionRole] ✅ ロール付与: ${pair.role_name} → ${member.user.tag}`
        );
      } catch (e) {
        console.error(`[ReactionRole] ロール付与失敗 (${pair.role_name}):`, e);
      }
    }
  }
);
