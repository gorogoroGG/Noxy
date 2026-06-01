import {
  Events,
  ChannelType,
  PermissionFlagsBits,
  type VoiceState,
  type TextChannel,
  type OverwriteResolvable,
} from 'discord.js';
import { client } from '../client.js';
import { supabase } from '../db.js';

// ── 設定型 ──────────────────────────────────────────────────

interface TempChannelSettings {
  id: string;
  guild_id: string;
  enabled: boolean;
  category_id: string | null;
  channel_name_format: string;
  auto_delete: boolean;
  delete_delay_minutes: number;
  join_leave_notification: boolean;
  watch_all_vcs: boolean;
  watch_vc_ids: string[];
  min_members: number;
}

// ── チャンネル名生成 ──────────────────────────────────────────

function buildChannelName(format: string, vcName: string, userName: string, count: number): string {
  return format
    .replace(/\{vc-name\}/g,    vcName.toLowerCase().replace(/[^a-z0-9ぁ-んァ-ヶ一-龠]/g, '-').replace(/-+/g, '-').slice(0, 32))
    .replace(/\{user-name\}/g,  userName.toLowerCase().replace(/[^a-z0-9]/g, ''))
    .replace(/\{count\}/g,      String(count))
    .toLowerCase()
    .slice(0, 100);
}

// ── VC参加処理 ───────────────────────────────────────────────

async function handleVoiceJoin(state: VoiceState, settings: TempChannelSettings): Promise<void> {
  const vcChannelId = state.channelId!;
  const guild       = state.guild;
  const member      = state.member!;

  // 特定VC監視モードのチェック
  if (!settings.watch_all_vcs && !settings.watch_vc_ids.includes(vcChannelId)) return;

  // VC チャンネルを取得
  const vcChannel = guild.channels.cache.get(vcChannelId);
  if (!vcChannel || vcChannel.type !== ChannelType.GuildVoice) return;

  const memberCount = vcChannel.members.size;

  // 最小参加人数チェック
  if (memberCount < settings.min_members) return;

  // 既存の一時チャンネルを確認
  const { data: existing } = await supabase
    .from('temp_channels')
    .select('*')
    .eq('guild_id', guild.id)
    .eq('vc_channel_id', vcChannelId)
    .single();

  if (existing) {
    // 既存チャンネルに参加ユーザーの権限を追加
    const textCh = guild.channels.cache.get(existing.text_channel_id) as TextChannel | undefined;
    if (textCh) {
      await textCh.permissionOverwrites.edit(member.id, {
        ViewChannel: true, SendMessages: true, ReadMessageHistory: true, AttachFiles: true,
      }).catch(() => {});

      if (settings.join_leave_notification) {
        await textCh.send(`👤 **${member.displayName}** が <#${vcChannelId}> に参加しました。`).catch(() => {});
      }
    }
    return;
  }

  // 新規一時チャンネルを作成
  const channelName = buildChannelName(
    settings.channel_name_format,
    vcChannel.name,
    member.user.username,
    memberCount,
  );

  // 全員分の権限オーバーライドを用意
  const overwrites: OverwriteResolvable[] = [
    { id: guild.id,        deny:  [PermissionFlagsBits.ViewChannel] },
    { id: client.user!.id, allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ReadMessageHistory, PermissionFlagsBits.ManageChannels, PermissionFlagsBits.ManageMessages] },
  ];
  for (const [, m] of vcChannel.members) {
    overwrites.push({
      id: m.id,
      allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ReadMessageHistory, PermissionFlagsBits.AttachFiles],
    });
  }

  let textChannel: TextChannel;
  try {
    textChannel = await guild.channels.create({
      name:                 channelName,
      type:                 ChannelType.GuildText,
      parent:               settings.category_id ?? undefined,
      topic:                `🎙️ ${vcChannel.name} を使用中のメンバー専用チャンネル`,
      permissionOverwrites: overwrites,
    }) as TextChannel;
  } catch (e) {
    console.error('[TempChannel] チャンネル作成失敗:', e);
    return;
  }

  // Supabase に記録
  await supabase.from('temp_channels').insert({
    guild_id:        guild.id,
    vc_channel_id:   vcChannelId,
    text_channel_id: textChannel.id,
  });

  // ウェルカムメッセージ
  const memberMentions = [...vcChannel.members.values()].map(m => m.toString()).join(' ');
  await textChannel.send({
    content: memberMentions,
    embeds: [{
      title:       `🎙️ ${vcChannel.name} の一時チャンネル`,
      description: 'このチャンネルは VC に参加しているメンバー専用です。\n全員が退室すると自動的に削除されます。',
      color:       0x5865f2,
      fields: [
        { name: 'VC',         value: `<#${vcChannelId}>`, inline: true },
        { name: '参加者',     value: String(memberCount),  inline: true },
      ],
      timestamp: new Date().toISOString(),
    }],
  }).catch(() => {});

  console.log(`[TempChannel] 作成: ${channelName} (VC: ${vcChannel.name})`);
}

// ── VC退室処理 ───────────────────────────────────────────────

async function handleVoiceLeave(state: VoiceState, settings: TempChannelSettings): Promise<void> {
  const vcChannelId = state.channelId!;
  const guild       = state.guild;
  const member      = state.member ?? null;

  // 一時チャンネルを確認
  const { data: tempCh } = await supabase
    .from('temp_channels')
    .select('*')
    .eq('guild_id', guild.id)
    .eq('vc_channel_id', vcChannelId)
    .single();

  if (!tempCh) return;

  const textChannel = guild.channels.cache.get(tempCh.text_channel_id) as TextChannel | undefined;

  // 退室メンバーの閲覧権限を明示的に DENY
  // （delete だとロールの allow が残る場合があるため、ViewChannel: false を明示する）
  if (textChannel && member) {
    await textChannel.permissionOverwrites.edit(member.id, {
      ViewChannel: false,
    }).catch(() => {});
    if (settings.join_leave_notification) {
      await textChannel.send(`🚪 **${member.displayName}** が退室しました。`).catch(() => {});
    }
  }

  // VC が空になったか確認
  const vcChannel = guild.channels.cache.get(vcChannelId);
  const remaining = vcChannel?.type === ChannelType.GuildVoice ? vcChannel.members.size : 0;

  if (remaining === 0 && settings.auto_delete) {
    const delayMs = (settings.delete_delay_minutes ?? 0) * 60 * 1000;

    const deleteFn = async () => {
      // 削除前に再確認（猶予中に再入室した場合はスキップ）
      const vc = guild.channels.cache.get(vcChannelId);
      if (vc?.type === ChannelType.GuildVoice && vc.members.size > 0) return;

      if (textChannel) {
        if (delayMs > 0) {
          await textChannel.send(`🗑️ VC が空になりました。${settings.delete_delay_minutes}分後にこのチャンネルを削除します。`).catch(() => {});
        }
        await new Promise(r => setTimeout(r, delayMs));
        await textChannel.delete('VC 退室により一時チャンネルを削除').catch(() => {});
      }
      await supabase.from('temp_channels').delete().eq('id', tempCh.id);
      console.log(`[TempChannel] 削除: ${tempCh.text_channel_id} (VC: ${vcChannelId})`);
    };

    deleteFn().catch(e => console.error('[TempChannel] 削除失敗:', e));
  }
}

// ── メインリスナー ───────────────────────────────────────────

client.on(Events.VoiceStateUpdate, async (oldState: VoiceState, newState: VoiceState) => {
  const guild = newState.guild;

  // 設定を取得
  const { data: settings } = await supabase
    .from('temp_channel_settings')
    .select('*')
    .eq('guild_id', guild.id)
    .eq('enabled', true)
    .single();

  if (!settings) return;

  const s = settings as TempChannelSettings;

  try {
    const joined = newState.channelId !== oldState.channelId && newState.channelId !== null;
    const left   = oldState.channelId !== newState.channelId && oldState.channelId !== null;

    if (joined) await handleVoiceJoin(newState, s);
    if (left)   await handleVoiceLeave({ ...oldState, channelId: oldState.channelId } as VoiceState, s);
  } catch (e) {
    console.error('[TempChannel] VoiceStateUpdate error:', e);
  }
});

// ── Bot 起動時にゾンビ一時チャンネルを清掃 ──────────────────

client.once(Events.ClientReady, async () => {
  const { data: orphans } = await supabase.from('temp_channels').select('*');
  if (!orphans) return;

  for (const row of orphans) {
    const guild = client.guilds.cache.get(row.guild_id);
    if (!guild) continue;

    const vc = guild.channels.cache.get(row.vc_channel_id);
    const isEmpty = !vc || vc.type !== ChannelType.GuildVoice || vc.members.size === 0;

    if (isEmpty) {
      const textCh = guild.channels.cache.get(row.text_channel_id);
      if (textCh) await textCh.delete('Bot再起動時の孤立一時チャンネル清掃').catch(() => {});
      await supabase.from('temp_channels').delete().eq('id', row.id);
      console.log(`[TempChannel] 孤立チャンネル削除: ${row.text_channel_id}`);
    }
  }
});
