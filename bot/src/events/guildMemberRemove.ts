import { Events, GuildMember, PartialGuildMember } from 'discord.js';
import { client } from '../client';
import { supabase } from '../db';

interface GreetingSettings {
  guild_id: string;
  goodbye_enabled: boolean;
  goodbye_channel_id: string;
  goodbye_message: string;
  goodbye_dm_enabled: boolean;
  goodbye_dm_message: string;
}

function substituteVariables(template: string, member: GuildMember | PartialGuildMember): string {
  return template
    .replace(/{user\.mention}/g, member.user?.username ?? 'Unknown') // 退室時 mention 不可
    .replace(/{user\.name}/g,    member.user?.username ?? 'Unknown')
    .replace(/{server\.name}/g,  member.guild.name)
    .replace(/{member\.count}/g, member.guild.memberCount.toLocaleString('ja-JP'));
}

client.on(Events.GuildMemberRemove, async (member: GuildMember | PartialGuildMember) => {
  console.log(`[Goodbye] 退室: ${member.user?.tag ?? 'Unknown'} ← ${member.guild.name}`);

  const { data, error } = await supabase
    .from('greeting_settings')
    .select('*')
    .eq('guild_id', member.guild.id)
    .single();

  if (error || !data) {
    console.log(`[Goodbye] 設定なし (guild: ${member.guild.id})`);
    return;
  }

  const settings = data as GreetingSettings;
  if (!settings.goodbye_enabled) return;

  // 1. DM 送信（チャンネル送信より前に行う）
  if (settings.goodbye_dm_enabled && settings.goodbye_dm_message) {
    try {
      const dmText = substituteVariables(settings.goodbye_dm_message, member);
      await member.send(dmText);
      console.log(`[Goodbye] ✅ DM送信完了: ${member.user?.tag}`);
    } catch (e) {
      console.warn('[Goodbye] DM送信失敗:', e);
    }
  }

  // 2. チャンネルに退室メッセージを送信
  if (settings.goodbye_channel_id) {
    try {
      const channel = await member.guild.channels.fetch(settings.goodbye_channel_id);
      if (channel?.isTextBased()) {
        const text = substituteVariables(settings.goodbye_message, member);
        await channel.send(text);
        console.log(`[Goodbye] ✅ チャンネル送信完了: #${channel.name}`);
      }
    } catch (e) {
      console.error('[Goodbye] チャンネル送信失敗:', e);
    }
  }
});
