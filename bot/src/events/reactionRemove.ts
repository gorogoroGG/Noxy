import { Events, MessageReaction, PartialMessageReaction, User, PartialUser } from 'discord.js';
import { client } from '../client';
import { supabase } from '../db';

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
  mode: string;
}

function toEmojiKey(reaction: MessageReaction | PartialMessageReaction): string {
  if (reaction.emoji.id) {
    const prefix = reaction.emoji.animated ? 'a' : '';
    return `<${prefix}:${reaction.emoji.name}:${reaction.emoji.id}>`;
  }
  return (reaction.emoji.name ?? '').replace(/️/g, '');
}

client.on(
  Events.MessageReactionRemove,
  async (reaction: MessageReaction | PartialMessageReaction, user: User | PartialUser) => {
    if (user.bot) return;

    if (reaction.partial) {
      try { await reaction.fetch(); } catch { return; }
    }

    const guild = reaction.message.guild;
    if (!guild) return;

    const emojiKey = toEmojiKey(reaction);

    const { data: configs, error } = await supabase
      .from('reaction_roles')
      .select('*')
      .eq('guild_id', guild.id)
      .eq('channel_id', reaction.message.channelId);

    if (error) {
      console.error('[ReactionRole] Supabase error:', error.message);
      return;
    }
    if (!configs?.length) return;

    for (const config of configs as ReactionRoleConfig[]) {
      // 認証・永続モードはリアクション解除でもロールを剥奪しない
      if (config.mode === '認証' || config.mode === '永続') continue;

      const pair = config.pairs.find(
        (p) => p.emoji.replace(/️/g, '') === emojiKey
      );
      if (!pair) continue;

      try {
        const member = await guild.members.fetch(user.id);
        await member.roles.remove(pair.role_id);
        console.log(
          `[ReactionRole] 🔴 ロール剥奪: ${pair.role_name} → ${member.user.tag}`
        );
      } catch (e) {
        console.error(`[ReactionRole] ロール剥奪失敗 (${pair.role_name}):`, e);
      }
    }
  }
);
