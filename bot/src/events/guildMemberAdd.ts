import { Events, GuildMember } from 'discord.js';
import { client } from '../client';
import { supabase } from '../db';

interface GreetingSettings {
  guild_id: string;
  welcome_enabled: boolean;
  welcome_channel_id: string;
  welcome_message: string;
  welcome_dm_enabled: boolean;
  welcome_dm_message: string;
  welcome_role_enabled: boolean;
  welcome_role_id: string;
}

// 変数を実際の値に置換する
function substituteVariables(template: string, member: GuildMember): string {
  return template
    .replace(/{user\.mention}/g, `<@${member.id}>`)
    .replace(/{user\.name}/g,    member.user.username)
    .replace(/{server\.name}/g,  member.guild.name)
    .replace(/{member\.count}/g, member.guild.memberCount.toLocaleString('ja-JP'));
}

client.on(Events.GuildMemberAdd, async (member: GuildMember) => {
  console.log(`[Welcome] 参加: ${member.user.tag} → ${member.guild.name}`);

  // Supabase から入退室設定を取得
  const { data, error } = await supabase
    .from('greeting_settings')
    .select('*')
    .eq('guild_id', member.guild.id)
    .single();

  if (error || !data) {
    console.log(`[Welcome] 設定なし (guild: ${member.guild.id})`);
    return;
  }

  const settings = data as GreetingSettings;
  if (!settings.welcome_enabled) return;

  // 1. チャンネルにウェルカムメッセージを送信
  if (settings.welcome_channel_id) {
    try {
      const channel = await member.guild.channels.fetch(settings.welcome_channel_id);
      if (channel?.isTextBased()) {
        const text = substituteVariables(settings.welcome_message, member);
        await channel.send(text);
        console.log(`[Welcome] ✅ チャンネル送信完了: #${channel.name}`);
      }
    } catch (e) {
      console.error('[Welcome] チャンネル送信失敗:', e);
    }
  }

  // 2. DM 送信
  if (settings.welcome_dm_enabled && settings.welcome_dm_message) {
    try {
      const dmText = substituteVariables(settings.welcome_dm_message, member)
        .replace(/{user\.mention}/g, member.user.username); // DM では mention 不可
      await member.send(dmText);
      console.log(`[Welcome] ✅ DM送信完了: ${member.user.tag}`);
    } catch (e) {
      console.warn('[Welcome] DM送信失敗（プライバシー設定の可能性）:', e);
    }
  }

  // 3. ロール付与
  if (settings.welcome_role_enabled && settings.welcome_role_id) {
    try {
      await member.roles.add(settings.welcome_role_id);
      console.log(`[Welcome] ✅ ロール付与完了: ${member.user.tag}`);
    } catch (e) {
      console.error('[Welcome] ロール付与失敗:', e);
    }
  }
});
