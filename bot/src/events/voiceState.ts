import {
  Events,
  ChannelType,
  PermissionFlagsBits,
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle,
  type VoiceState,
  type TextChannel,
  type VoiceChannel,
  type OverwriteResolvable,
} from 'discord.js';
import { client } from '../client.js';
import { supabase } from '../db.js';

// ── 設定型 ──────────────────────────────────────────────────

interface TempVCSource {
  id: string;
  guild_id: string;
  trigger_vc_id: string | null;
  trigger_vc_name: string;
  vc_category_id: string;
  text_channel_category_id: string;
  vc_name_format: string;
  channel_name_format: string;
  user_limit: number;
  auto_delete: boolean;
  delete_delay_minutes: number;
  join_leave_notification: boolean;
  enabled: boolean;
}

// ── チャンネル名レートリミット管理（Discord: 2回/10分）──────

const lastRenameTime = new Map<string, number>();

// ── ユーティリティ ───────────────────────────────────────────

function buildChannelName(format: string, vcName: string, userName: string, count: number): string {
  return format
    .replace(/\{vc-name\}/g,   vcName.toLowerCase().replace(/[^a-z0-9ぁ-んァ-ヶ一-龠]/g, '-').replace(/-+/g, '-').slice(0, 32))
    .replace(/\{user-name\}/g, userName.toLowerCase().replace(/[^a-z0-9]/g, ''))
    .replace(/\{count\}/g,     String(count))
    .toLowerCase()
    .slice(0, 100);
}

function buildVCName(format: string, userName: string, count: number): string {
  return format
    .replace(/\{user-name\}/g, userName.toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 32))
    .replace(/\{count\}/g,     String(count))
    .slice(0, 100);
}

// ── VC参加処理 ───────────────────────────────────────────────

async function handleVoiceJoin(state: VoiceState): Promise<void> {
  const vcChannelId = state.channelId!;
  const guild       = state.guild;
  const member      = state.member!;

  // 一時VCのトリガーかチェック
  const { data: vcSources } = await supabase
    .from('temp_vc_sources')
    .select('*')
    .eq('guild_id', guild.id)
    .eq('enabled', true)
    .not('trigger_vc_id', 'is', null);

  if (!vcSources || vcSources.length === 0) return;

  const source = vcSources.find((s: TempVCSource) => s.trigger_vc_id === vcChannelId) as TempVCSource | undefined;
  if (!source) return;

  // 既に一時VCが存在するかチェック
  const { data: existing } = await supabase
    .from('temp_channels')
    .select('*')
    .eq('guild_id', guild.id)
    .eq('temp_vc_source_id', source.id)
    .single();

  if (existing) {
    // 既存の一時VCに参加者を追加
    const tempVC = guild.channels.cache.get(existing.vc_channel_id) as VoiceChannel | undefined;
    const textCh = guild.channels.cache.get(existing.text_channel_id) as TextChannel | undefined;

    if (tempVC && member) {
      await member.voice.setChannel(tempVC).catch(() => {});
    }

    if (textCh) {
      await textCh.permissionOverwrites.edit(member.id, {
        ViewChannel:        true,
        SendMessages:       true,
        ReadMessageHistory: true,
        AttachFiles:        true,
      }).catch(() => {});

      if (source.join_leave_notification) {
        await textCh.send(`👤 **${member.displayName}** が参加しました。`).catch(() => {});
      }
    }
    return;
  }

  // 新規作成
  const vcName = buildVCName(source.vc_name_format, member.user.username, 1);
  const channelName = buildChannelName(
    source.channel_name_format,
    vcName,
    member.user.username,
    1,
  );

  const overwrites: OverwriteResolvable[] = [
    { id: guild.id,        deny:  [PermissionFlagsBits.ViewChannel] },
    { id: client.user!.id, allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ReadMessageHistory, PermissionFlagsBits.ManageChannels, PermissionFlagsBits.ManageMessages] },
    { id: member.id,       allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ReadMessageHistory, PermissionFlagsBits.AttachFiles, PermissionFlagsBits.Connect, PermissionFlagsBits.Speak] },
  ];

  // VC作成
  let tempVC: VoiceChannel;
  try {
    tempVC = await guild.channels.create({
      name:                 vcName,
      type:                 ChannelType.GuildVoice,
      parent:               source.vc_category_id,
      userLimit:            source.user_limit || undefined,
      permissionOverwrites: overwrites,
    }) as VoiceChannel;
  } catch (e) {
    console.error('[TempVC] VC作成失敗:', e);
    return;
  }

  // テキストチャンネル作成
  const topic = `🎙️ ${vcName} | 参加中: ${member.displayName}`;
  let textChannel: TextChannel;
  try {
    textChannel = await guild.channels.create({
      name:                 channelName,
      type:                 ChannelType.GuildText,
      parent:               source.text_channel_category_id,
      topic,
      permissionOverwrites: overwrites,
    }) as TextChannel;
  } catch (e) {
    console.error('[TempVC] テキストチャンネル作成失敗:', e);
    await tempVC.delete().catch(() => {});
    return;
  }

  // ユーザーを新しいVCに移動
  await member.voice.setChannel(tempVC).catch(() => {});

  // Supabaseに記録
  await supabase.from('temp_channels').insert({
    guild_id:           guild.id,
    vc_channel_id:      tempVC.id,
    text_channel_id:    textChannel.id,
    temp_vc_source_id:  source.id,
  });

  lastRenameTime.set(textChannel.id, Date.now());

  // ウェルカムメッセージ
  const joinBtn = new ButtonBuilder()
    .setStyle(ButtonStyle.Link)
    .setLabel(`🎙️ ${vcName} に参加する`)
    .setURL(`https://discord.com/channels/${guild.id}/${tempVC.id}`);
  const row = new ActionRowBuilder<ButtonBuilder>().addComponents(joinBtn);

  await textChannel.send({
    content: member.toString(),
    embeds: [{
      title:       `🎙️ ${vcName}`,
      description: 'このチャンネルは VC に参加しているメンバー専用です。\n全員が退室すると自動的に削除されます。',
      color:       0x5865f2,
      fields: [
        { name: 'VC',     value: `<#${tempVC.id}>`, inline: true },
        { name: '参加者', value: '1',               inline: true },
      ],
      timestamp: new Date().toISOString(),
    }],
    components: [row],
  }).catch(() => {});

  console.log(`[TempVC] 作成: ${vcName} (Source: ${source.trigger_vc_name})`);
}

// ── VC退室処理 ───────────────────────────────────────────────

async function handleVoiceLeave(state: VoiceState): Promise<void> {
  const vcChannelId = state.channelId!;
  const guild       = state.guild;
  const member      = state.member;

  const { data: tempCh } = await supabase
    .from('temp_channels')
    .select('*')
    .eq('guild_id', guild.id)
    .eq('vc_channel_id', vcChannelId)
    .not('temp_vc_source_id', 'is', null)
    .single();

  if (!tempCh) return;

  const textChannel = guild.channels.cache.get(tempCh.text_channel_id) as TextChannel | undefined;
  const vcChannel   = guild.channels.cache.get(vcChannelId) as VoiceChannel | undefined;

  // 退室メンバーの権限剥奪
  if (textChannel && member) {
    await textChannel.permissionOverwrites.edit(member.id, {
      ViewChannel: false,
    }).catch(() => {});

    const { data: srcForNotif } = await supabase
      .from('temp_vc_sources')
      .select('*')
      .eq('id', tempCh.temp_vc_source_id)
      .single();

    if (srcForNotif && (srcForNotif as TempVCSource).join_leave_notification) {
      await textChannel.send(`🚪 **${member.displayName}** が退室しました。`).catch(() => {});
    }
  }

  // VCが空になったか確認
  const remaining = vcChannel?.type === ChannelType.GuildVoice ? vcChannel.members.size : 0;

  const { data: source } = await supabase
    .from('temp_vc_sources')
    .select('*')
    .eq('id', tempCh.temp_vc_source_id)
    .single();

  if (!source) return;
  const src = source as TempVCSource;

  if (remaining === 0 && src.auto_delete) {
    const delayMs    = src.delete_delay_minutes * 60 * 1000;
    const delayLabel = src.delete_delay_minutes;

    const deleteFn = async () => {
      if (delayMs === 0) {
        await textChannel?.send('🗑️ VC が空になりました。チャンネルを削除します。').catch(() => {});
        await new Promise(r => setTimeout(r, 3000));
      } else {
        await textChannel?.send(
          `🗑️ VC が空になりました。**${delayLabel}分後**にこのチャンネルを削除します。`
        ).catch(() => {});

        if (delayMs >= 2 * 60 * 1000) {
          await new Promise(r => setTimeout(r, delayMs - 60 * 1000));
          const vc = guild.channels.cache.get(vcChannelId) as VoiceChannel | undefined;
          if (vc?.type === ChannelType.GuildVoice && vc.members.size > 0) return;
          await textChannel?.send('⚠️ **1分後にこのチャンネルを削除します。**').catch(() => {});
          await new Promise(r => setTimeout(r, 60 * 1000));
        } else {
          await new Promise(r => setTimeout(r, delayMs));
        }
      }

      // 最終確認
      const vc = guild.channels.cache.get(vcChannelId) as VoiceChannel | undefined;
      if (vc?.type === ChannelType.GuildVoice && vc.members.size > 0) return;

      // テキストチャンネルとVCの両方を削除
      await textChannel?.delete('一時VC退室により削除').catch(() => {});
      await vc?.delete('一時VC退室により削除').catch(() => {});
      await supabase.from('temp_channels').delete().eq('id', tempCh.id);
      lastRenameTime.delete(tempCh.text_channel_id);
      console.log(`[TempVC] 削除: ${tempCh.vc_channel_id}`);
    };

    deleteFn().catch(e => console.error('[TempVC] 削除失敗:', e));
  }
}

// ── メインリスナー ───────────────────────────────────────────

client.on(Events.VoiceStateUpdate, async (oldState: VoiceState, newState: VoiceState) => {
  const guild = newState.guild;

  const joined = newState.channelId !== oldState.channelId && newState.channelId !== null;
  const left   = oldState.channelId !== newState.channelId && oldState.channelId !== null;

  if (joined) {
    try {
      await handleVoiceJoin(newState);
    } catch (e) {
      console.error('[TempVC] VoiceStateUpdate error (join):', e);
    }
  }

  if (left) {
    try {
      await handleVoiceLeave({ ...oldState, channelId: oldState.channelId } as VoiceState);
    } catch (e) {
      console.error('[TempVC] VoiceStateUpdate error (leave):', e);
    }
  }
});

// ── Bot 起動時にゾンビ一時チャンネルを清掃 ──────────────────

client.once(Events.ClientReady, async () => {
  const { data: orphans } = await supabase.from('temp_channels').select('*').not('temp_vc_source_id', 'is', null);
  if (!orphans) return;

  for (const row of orphans) {
    const guild = client.guilds.cache.get(row.guild_id);
    if (!guild) continue;

    const vc      = guild.channels.cache.get(row.vc_channel_id);
    const isEmpty = !vc || vc.type !== ChannelType.GuildVoice || vc.members.size === 0;

    if (isEmpty) {
      const textCh = guild.channels.cache.get(row.text_channel_id);
      if (textCh) await textCh.delete('Bot再起動時の孤立一時チャンネル清掃').catch(() => {});
      await vc?.delete('Bot再起動時の孤立一時VC清掃').catch(() => {});
      await supabase.from('temp_channels').delete().eq('id', row.id);
      console.log(`[TempVC] 孤立チャンネル削除: ${row.text_channel_id}`);
    }
  }
});
