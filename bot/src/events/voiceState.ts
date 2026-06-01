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

const lastRenameTime = new Map<string, number>();

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

async function handleVoiceJoin(state: VoiceState): Promise<void> {
  const vcChannelId = state.channelId!;
  const guild       = state.guild;
  const member      = state.member!;

  const { data: vcSources } = await supabase
    .from('temp_vc_sources')
    .select('*')
    .eq('guild_id', guild.id)
    .eq('enabled', true)
    .not('trigger_vc_id', 'is', null);

  if (!vcSources || vcSources.length === 0) return;

  const source = vcSources.find((s: TempVCSource) => s.trigger_vc_id === vcChannelId) as TempVCSource | undefined;
  if (!source) return;

  console.log(`[TempVC] トリガーVC参加検知: ${source.trigger_vc_name} (user: ${member.user.username})`);

  const { data: existing } = await supabase
    .from('temp_channels')
    .select('*')
    .eq('guild_id', guild.id)
    .eq('temp_vc_source_id', source.id)
    .single();

  if (existing) {
    const tempVC = guild.channels.cache.get(existing.vc_channel_id) as VoiceChannel | undefined;
    const textCh = guild.channels.cache.get(existing.text_channel_id) as TextChannel | undefined;

    if (tempVC && member) {
      await member.voice.setChannel(tempVC).catch((e) => {
        console.error('[TempVC] 既存VCへの移動失敗:', e);
      });
    }

    if (textCh) {
      await textCh.permissionOverwrites.edit(member.id, {
        ViewChannel:        true,
        SendMessages:       true,
        ReadMessageHistory: true,
        AttachFiles:        true,
      }).catch((e) => console.error('[TempVC] 権限編集失敗:', e));

      if (source.join_leave_notification) {
        await textCh.send(`👤 **${member.displayName}** が参加しました。`).catch(() => {});
      }
    }
    return;
  }

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

  await member.voice.setChannel(tempVC).catch(() => {});

  const { error: insertError } = await supabase.from('temp_channels').insert({
    guild_id:           guild.id,
    vc_channel_id:      tempVC.id,
    text_channel_id:    textChannel.id,
    temp_vc_source_id:  source.id,
  });

  if (insertError) {
    console.error('[TempVC] DB記録失敗:', insertError);
  }

  lastRenameTime.set(textChannel.id, Date.now());

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
  }).catch((e) => console.error('[TempVC] ウェルカムメッセージ送信失敗:', e));

  console.log(`[TempVC] 作成: ${vcName} (VC: ${tempVC.id}, Text: ${textChannel.id})`);
}

async function handleVoiceLeave(state: VoiceState): Promise<void> {
  const vcChannelId = state.channelId!;
  const guild       = state.guild;
  const member      = state.member;

  console.log(`[TempVC] 退出チェック: vcChannelId=${vcChannelId}, guild=${guild.id}`);

  const { data: tempCh, error: queryError } = await supabase
    .from('temp_channels')
    .select('*')
    .eq('guild_id', guild.id)
    .eq('vc_channel_id', vcChannelId)
    .not('temp_vc_source_id', 'is', null)
    .single();

  if (queryError || !tempCh) {
    console.log(`[TempVC] 一時チャンネルレコードなし: ${vcChannelId}`);
    return;
  }

  console.log(`[TempVC] 一時チャンネル発見: text=${tempCh.text_channel_id}, source=${tempCh.temp_vc_source_id}`);

  // テキストチャンネルをキャッシュまたはfetchで取得
  let textChannel: TextChannel | null = guild.channels.cache.get(tempCh.text_channel_id) as TextChannel | undefined ?? null;
  if (!textChannel) {
    textChannel = await guild.channels.fetch(tempCh.text_channel_id).catch(() => null) as TextChannel | null;
    if (!textChannel) {
      console.log('[TempVC] テキストチャンネルが見つからない（削除済み？）');
    }
  }

  // VCをfetchで最新を取得
  const vcChannel = await guild.channels.fetch(vcChannelId).catch(() => null) as VoiceChannel | null;
  if (!vcChannel) {
    console.log('[TempVC] VCが見つからない（削除済み？）');
    // DBレコードだけ削除
    await supabase.from('temp_channels').delete().eq('id', tempCh.id);
    return;
  }

  // 退室メンバーの権限剥奪
  if (textChannel && member) {
    await textChannel.permissionOverwrites.edit(member.id, {
      ViewChannel: false,
    }).catch((e) => console.error('[TempVC] 権限剥奪失敗:', e));

    const { data: srcForNotif } = await supabase
      .from('temp_vc_sources')
      .select('*')
      .eq('id', tempCh.temp_vc_source_id)
      .single();

    if (srcForNotif && (srcForNotif as TempVCSource).join_leave_notification) {
      await textChannel.send(`🚪 **${member.displayName}** が退室しました。`).catch((e) => console.error('[TempVC] 退出通知失敗:', e));
    }
  }

  // VCが空になったか確認（fetchで最新を取得）
  const freshVc = await guild.channels.fetch(vcChannelId).catch(() => null) as VoiceChannel | null;
  const remaining = freshVc?.type === ChannelType.GuildVoice ? freshVc.members.size : 0;
  console.log(`[TempVC] 退出後人数: ${remaining}`);

  const { data: source } = await supabase
    .from('temp_vc_sources')
    .select('*')
    .eq('id', tempCh.temp_vc_source_id)
    .single();

  if (!source) {
    console.log('[TempVC] ソース設定なし');
    return;
  }
  const src = source as TempVCSource;

  if (remaining === 0 && src.auto_delete) {
    console.log(`[TempVC] 削除開始: delay=${src.delete_delay_minutes}分, auto_delete=${src.auto_delete}`);

    const delayMs    = src.delete_delay_minutes * 60 * 1000;
    const delayLabel = String(src.delete_delay_minutes);

    const deleteFn = async () => {
      if (delayMs <= 0) {
        await textChannel?.send('🗑️ VC が空になりました。チャンネルを削除します。').catch(() => {});
        await new Promise(r => setTimeout(r, 3000));
      } else {
        await textChannel?.send(
          `🗑️ VC が空になりました。**${delayLabel}分後**にこのチャンネルを削除します。`
        ).catch(() => {});

        if (delayMs >= 2 * 60 * 1000) {
          await new Promise(r => setTimeout(r, delayMs - 60 * 1000));
          const vc = await guild.channels.fetch(vcChannelId).catch(() => null) as VoiceChannel | null;
          if (vc?.type === ChannelType.GuildVoice && vc.members.size > 0) {
            console.log(`[TempVC] 再入室のため削除キャンセル (人数: ${vc.members.size})`);
            return;
          }
          await textChannel?.send('⚠️ **1分後にこのチャンネルを削除します。**').catch(() => {});
          await new Promise(r => setTimeout(r, 60 * 1000));
        } else {
          await new Promise(r => setTimeout(r, delayMs));
        }
      }

      // 最終確認
      const vc = await guild.channels.fetch(vcChannelId).catch(() => null) as VoiceChannel | null;
      if (vc?.type === ChannelType.GuildVoice && vc.members.size > 0) {
        console.log(`[TempVC] 再入室のため削除キャンセル（最終確認, 人数: ${vc.members.size}）`);
        return;
      }

      // テキストチャンネルとVCの両方を削除
      // 再度取得（削除前に存在するか確認）
      const textChToDelete = textChannel ?? await guild.channels.fetch(tempCh.text_channel_id).catch(() => null);
      const vcToDelete = vcChannel ?? await guild.channels.fetch(tempCh.vc_channel_id).catch(() => null);

      if (textChToDelete) {
        await textChToDelete.delete('一時VC退室により削除').catch((e) => console.error('[TempVC] テキストチャンネル削除失敗:', e));
        console.log('[TempVC] テキストチャンネル削除完了');
      }
      if (vcToDelete) {
        await vcToDelete.delete('一時VC退室により削除').catch((e) => console.error('[TempVC] VC削除失敗:', e));
        console.log('[TempVC] VC削除完了');
      }
      await supabase.from('temp_channels').delete().eq('id', tempCh.id);
      lastRenameTime.delete(tempCh.text_channel_id);
      console.log(`[TempVC] 削除完了: VC=${tempCh.vc_channel_id}, Text=${tempCh.text_channel_id}`);
    };

    deleteFn().catch(e => console.error('[TempVC] 削除失敗:', e));
  } else {
    console.log(`[TempVC] 削除スキップ: remaining=${remaining}, auto_delete=${src.auto_delete}`);
  }
}

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
