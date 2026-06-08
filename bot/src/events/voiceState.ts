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
  waiting_room_enabled: boolean;
}

const lastRenameTime = new Map<string, number>();

// 日本語ユーザー名を含めてVC名を構築
function buildVCName(format: string, userName: string, count: number): string {
  const safeName = userName
    .replace(/[^\w぀-鿿豈-﫿]/g, '')
    .slice(0, 32);
  return format
    .replace(/\{user-name\}/g, safeName || 'ユーザー')
    .replace(/\{count\}/g, String(count))
    .slice(0, 100);
}

// 日本語ユーザー名を含めてテキストチャンネル名を構築
function buildChannelName(format: string, vcName: string, userName: string, count: number): string {
  const safeVcName = vcName
    .toLowerCase()
    .replace(/[^a-z0-9぀-鿿豈-﫿]/g, '-')
    .replace(/-+/g, '-')
    .slice(0, 32);
  const safeUserName = userName
    .replace(/[^\w぀-鿿豈-﫿]/g, '')
    .slice(0, 32) || 'user';
  return format
    .replace(/\{vc-name\}/g,   safeVcName)
    .replace(/\{user-name\}/g, safeUserName)
    .replace(/\{count\}/g,     String(count))
    .slice(0, 100);
}

// 待機室への入室リクエスト通知を送信
async function sendWaitingRoomApprovalRequest(state: VoiceState, tempCh: Record<string, unknown>): Promise<void> {
  const guild  = state.guild;
  const member = state.member!;

  let textChannel: TextChannel | null = guild.channels.cache.get(tempCh['text_channel_id'] as string) as TextChannel | undefined ?? null;
  if (!textChannel) {
    textChannel = await guild.channels.fetch(tempCh['text_channel_id'] as string).catch(() => null) as TextChannel | null;
  }
  if (!textChannel) {
    console.log('[TempVC] 待機室申請通知失敗: テキストチャンネルが見つからない');
    return;
  }

  const tempChId = tempCh['id'] as string;
  const approveBtn = new ButtonBuilder()
    .setCustomId(`vc_wr_approve_${member.id}_${tempChId}`)
    .setLabel('✅ 承認する')
    .setStyle(ButtonStyle.Success);
  const denyBtn = new ButtonBuilder()
    .setCustomId(`vc_wr_deny_${member.id}_${tempChId}`)
    .setLabel('❌ 拒否する')
    .setStyle(ButtonStyle.Danger);
  const row = new ActionRowBuilder<ButtonBuilder>().addComponents(approveBtn, denyBtn);

  await textChannel.send({
    embeds: [{
      title:       '🚪 入室リクエスト',
      description: `${member.toString()} が待機室に入りました。\nVC参加を承認しますか？`,
      thumbnail:   { url: member.user.displayAvatarURL({ size: 64 }) },
      fields: [
        { name: 'ユーザー', value: `@${member.user.username} (${member.id})`, inline: true },
      ],
      color:     0xf59e0b,
      timestamp: new Date().toISOString(),
    }],
    components: [row],
  }).catch(e => console.error('[TempVC] 待機室申請メッセージ送信失敗:', e));

  console.log(`[TempVC] 待機室申請: ${member.user.username} → tempCh=${tempChId}`);
}

async function handleVoiceJoin(state: VoiceState): Promise<void> {
  const vcChannelId = state.channelId!;
  const guild       = state.guild;
  const member      = state.member!;

  // 待機室への参加チェック（待機室の場合は承認リクエストを送信して終了）
  const { data: waitingRoomRecord } = await supabase
    .from('temp_channels')
    .select('*')
    .eq('guild_id', guild.id)
    .eq('waiting_room_vc_id', vcChannelId)
    .maybeSingle();

  if (waitingRoomRecord) {
    await sendWaitingRoomApprovalRequest(state, waitingRoomRecord as Record<string, unknown>);
    return;
  }

  // トリガーVC チェック
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

  // 既存チャンネルがあれば移動先を決定
  const { data: existing } = await supabase
    .from('temp_channels')
    .select('*')
    .eq('guild_id', guild.id)
    .eq('temp_vc_source_id', source.id)
    .single();

  if (existing) {
    const existingRec = existing as Record<string, unknown>;

    // 待機室モードかつ待機室VCが存在する場合は待機室へ移動
    if (source.waiting_room_enabled && existingRec['waiting_room_vc_id']) {
      const waitingRoomVC = guild.channels.cache.get(existingRec['waiting_room_vc_id'] as string) as VoiceChannel | undefined
        ?? await guild.channels.fetch(existingRec['waiting_room_vc_id'] as string).catch(() => null) as VoiceChannel | null;
      if (waitingRoomVC && member) {
        await member.voice.setChannel(waitingRoomVC).catch(e => console.error('[TempVC] 待機室への移動失敗:', e));
      }
      // 待機室への移動でVoiceStateUpdateが再発火し、待機室申請ロジックが実行される
      return;
    }

    // 待機室なし: 既存メインVCへ移動
    const tempVC  = guild.channels.cache.get(existingRec['vc_channel_id'] as string) as VoiceChannel | undefined;
    const textCh  = guild.channels.cache.get(existingRec['text_channel_id'] as string) as TextChannel | undefined;

    if (tempVC && member) {
      await member.voice.setChannel(tempVC).catch(e => console.error('[TempVC] 既存VCへの移動失敗:', e));
    }

    if (textCh) {
      await textCh.permissionOverwrites.edit(member.id, {
        ViewChannel:        true,
        SendMessages:       true,
        ReadMessageHistory: true,
        AttachFiles:        true,
      }).catch(e => console.error('[TempVC] 権限編集失敗:', e));

      if (source.join_leave_notification) {
        await textCh.send(`👤 **${member.displayName}** が参加しました。`).catch(() => {});
      }
    }
    return;
  }

  // ── 新規チャンネル作成 ──────────────────────────────────────

  const vcName      = buildVCName(source.vc_name_format, member.user.username, 1);
  const channelName = buildChannelName(source.channel_name_format, vcName, member.user.username, 1);

  const mainVCOverwrites: OverwriteResolvable[] = [
    {
      id:   guild.id,
      deny: [PermissionFlagsBits.ViewChannel],
    },
    {
      id:    client.user!.id,
      allow: [
        PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages,
        PermissionFlagsBits.ReadMessageHistory, PermissionFlagsBits.ManageChannels,
        PermissionFlagsBits.ManageMessages, PermissionFlagsBits.MoveMembers,
      ],
    },
    {
      id:    member.id,
      allow: [
        PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages,
        PermissionFlagsBits.ReadMessageHistory, PermissionFlagsBits.AttachFiles,
        PermissionFlagsBits.Connect, PermissionFlagsBits.Speak,
      ],
    },
  ];

  let tempVC: VoiceChannel;
  try {
    tempVC = await guild.channels.create({
      name:                 vcName,
      type:                 ChannelType.GuildVoice,
      parent:               source.vc_category_id,
      userLimit:            source.user_limit || undefined,
      permissionOverwrites: mainVCOverwrites,
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
      parent:               source.text_channel_category_id || source.vc_category_id,
      topic,
      permissionOverwrites: mainVCOverwrites,
    }) as TextChannel;
  } catch (e) {
    console.error('[TempVC] テキストチャンネル作成失敗:', e);
    await tempVC.delete().catch(() => {});
    return;
  }

  // ── 待機室VC作成（waiting_room_enabled 時）──────────────────

  let waitingRoomVcId: string | null = null;

  if (source.waiting_room_enabled) {
    const waitingRoomOverwrites: OverwriteResolvable[] = [
      {
        id:    guild.id,
        allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.Connect],
      },
      {
        id:    client.user!.id,
        allow: [
          PermissionFlagsBits.ViewChannel, PermissionFlagsBits.Connect,
          PermissionFlagsBits.MoveMembers, PermissionFlagsBits.ManageChannels,
        ],
      },
      {
        // 作成者は待機室には入れない（直接メインVCへ）
        id:   member.id,
        deny: [PermissionFlagsBits.Connect],
      },
    ];

    try {
      const waitingRoomVC = await guild.channels.create({
        name:                 `${vcName}-待機室`,
        type:                 ChannelType.GuildVoice,
        parent:               source.vc_category_id,
        permissionOverwrites: waitingRoomOverwrites,
      }) as VoiceChannel;
      waitingRoomVcId = waitingRoomVC.id;
      console.log(`[TempVC] 待機室作成: ${waitingRoomVC.name} (${waitingRoomVC.id})`);
    } catch (e) {
      console.error('[TempVC] 待機室作成失敗:', e);
      // 待機室なしで続行
    }
  }

  // 作成者をメインVCへ移動
  await member.voice.setChannel(tempVC).catch(() => {});

  // DB 記録
  const insertData: Record<string, unknown> = {
    guild_id:          guild.id,
    vc_channel_id:     tempVC.id,
    text_channel_id:   textChannel.id,
    temp_vc_source_id: source.id,
  };
  if (waitingRoomVcId !== null) {
    insertData['waiting_room_vc_id'] = waitingRoomVcId;
  }

  const { error: insertError } = await supabase.from('temp_channels').insert(insertData);
  if (insertError) {
    console.error('[TempVC] DB記録失敗:', insertError);
  }

  lastRenameTime.set(textChannel.id, Date.now());

  // ウェルカムメッセージ
  const joinBtn = new ButtonBuilder()
    .setStyle(ButtonStyle.Link)
    .setLabel(`🎙️ ${vcName} に参加する`)
    .setURL(`https://discord.com/channels/${guild.id}/${tempVC.id}`);

  const row = new ActionRowBuilder<ButtonBuilder>().addComponents(joinBtn);

  if (waitingRoomVcId) {
    const waitingRoomBtn = new ButtonBuilder()
      .setStyle(ButtonStyle.Link)
      .setLabel('🚪 待機室')
      .setURL(`https://discord.com/channels/${guild.id}/${waitingRoomVcId}`);
    row.addComponents(waitingRoomBtn);
  }

  const description = source.waiting_room_enabled
    ? 'このチャンネルはVC管理者専用です。\n一般参加者は **待機室** から入室リクエストを送ってください。'
    : 'このチャンネルはVCに参加しているメンバー専用です。\n全員が退室すると自動的に削除されます。';

  const embedFields: { name: string; value: string; inline: boolean }[] = [
    { name: 'VC',     value: `<#${tempVC.id}>`, inline: true },
    { name: '参加者', value: '1',               inline: true },
  ];
  if (waitingRoomVcId) {
    embedFields.push({ name: '待機室', value: `<#${waitingRoomVcId}>`, inline: true });
  }

  await textChannel.send({
    content: member.toString(),
    embeds: [{
      title:       `🎙️ ${vcName}`,
      description,
      color:       0x5865f2,
      fields:      embedFields,
      timestamp:   new Date().toISOString(),
    }],
    components: [row],
  }).catch(e => console.error('[TempVC] ウェルカムメッセージ送信失敗:', e));

  console.log(`[TempVC] 作成: ${vcName} (VC: ${tempVC.id}, Text: ${textChannel.id}${waitingRoomVcId ? `, 待機室: ${waitingRoomVcId}` : ''})`);
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

  console.log(`[TempVC] 一時チャンネル発見: text=${tempCh['text_channel_id']}, source=${tempCh['temp_vc_source_id']}`);

  let textChannel: TextChannel | null = guild.channels.cache.get(tempCh['text_channel_id'] as string) as TextChannel | undefined ?? null;
  if (!textChannel) {
    textChannel = await guild.channels.fetch(tempCh['text_channel_id'] as string).catch(() => null) as TextChannel | null;
  }

  const vcChannel = await guild.channels.fetch(vcChannelId).catch(() => null) as VoiceChannel | null;
  if (!vcChannel) {
    console.log('[TempVC] VCが見つからない（削除済み？）');
    await supabase.from('temp_channels').delete().eq('id', tempCh['id']);
    return;
  }

  // 退室メンバーのテキストチャンネル権限剥奪
  if (textChannel && member) {
    await textChannel.permissionOverwrites.edit(member.id, {
      ViewChannel: false,
    }).catch(e => console.error('[TempVC] 権限剥奪失敗:', e));

    const { data: srcForNotif } = await supabase
      .from('temp_vc_sources')
      .select('*')
      .eq('id', tempCh['temp_vc_source_id'])
      .single();

    if (srcForNotif && (srcForNotif as TempVCSource).join_leave_notification) {
      await textChannel.send(`🚪 **${member.displayName}** が退室しました。`).catch(e => console.error('[TempVC] 退出通知失敗:', e));
    }
  }

  const freshVc    = await guild.channels.fetch(vcChannelId).catch(() => null) as VoiceChannel | null;
  const remaining  = freshVc?.type === ChannelType.GuildVoice ? freshVc.members.size : 0;
  console.log(`[TempVC] 退出後人数: ${remaining}`);

  const { data: source } = await supabase
    .from('temp_vc_sources')
    .select('*')
    .eq('id', tempCh['temp_vc_source_id'])
    .single();

  if (!source) {
    console.log('[TempVC] ソース設定なし');
    return;
  }
  const src = source as TempVCSource;

  if (remaining === 0 && src.auto_delete) {
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

      const vc = await guild.channels.fetch(vcChannelId).catch(() => null) as VoiceChannel | null;
      if (vc?.type === ChannelType.GuildVoice && vc.members.size > 0) {
        console.log(`[TempVC] 再入室のため削除キャンセル（最終確認, 人数: ${vc.members.size}）`);
        return;
      }

      const textChToDelete  = textChannel ?? await guild.channels.fetch(tempCh['text_channel_id'] as string).catch(() => null);
      const vcToDelete      = vcChannel   ?? await guild.channels.fetch(tempCh['vc_channel_id'] as string).catch(() => null);
      const waitingRoomVcId = tempCh['waiting_room_vc_id'] as string | undefined;

      if (textChToDelete) {
        await textChToDelete.delete('一時VC退室により削除').catch(e => console.error('[TempVC] テキストチャンネル削除失敗:', e));
        console.log('[TempVC] テキストチャンネル削除完了');
      }
      if (waitingRoomVcId) {
        const waitingRoomCh = guild.channels.cache.get(waitingRoomVcId)
          ?? await guild.channels.fetch(waitingRoomVcId).catch(() => null);
        if (waitingRoomCh) {
          await waitingRoomCh.delete('一時VC退室により削除').catch(e => console.error('[TempVC] 待機室削除失敗:', e));
          console.log('[TempVC] 待機室削除完了');
        }
      }
      if (vcToDelete) {
        await vcToDelete.delete('一時VC退室により削除').catch(e => console.error('[TempVC] VC削除失敗:', e));
        console.log('[TempVC] VC削除完了');
      }

      await supabase.from('temp_channels').delete().eq('id', tempCh['id']);
      lastRenameTime.delete(tempCh['text_channel_id'] as string);
      console.log(`[TempVC] 削除完了: VC=${tempCh['vc_channel_id']}, Text=${tempCh['text_channel_id']}`);
    };

    deleteFn().catch(e => console.error('[TempVC] 削除失敗:', e));
  } else {
    console.log(`[TempVC] 削除スキップ: remaining=${remaining}, auto_delete=${src.auto_delete}`);
  }
}

// ── VC接続人数をSupabaseに記録（統計チャンネル用）──────────────
async function updateGuildVcStats(guildId: string): Promise<void> {
  const guild = client.guilds.cache.get(guildId);
  if (!guild) return;

  const vcUserCount = guild.channels.cache
    .filter(ch => ch.type === ChannelType.GuildVoice)
    .reduce((sum, ch) => {
      if (ch.type === ChannelType.GuildVoice) return sum + ch.members.size;
      return sum;
    }, 0);

  const { error } = await supabase
    .from('guild_stats')
    .upsert(
      { guild_id: guildId, vc_user_count: vcUserCount, updated_at: new Date().toISOString() },
      { onConflict: 'guild_id' }
    );
  if (error) console.error('[VcStats] 更新失敗:', error.message);
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

  await updateGuildVcStats(guild.id).catch(() => {});
});

client.once(Events.ClientReady, async () => {
  const { data: orphans } = await supabase.from('temp_channels').select('*').not('temp_vc_source_id', 'is', null);
  if (!orphans) return;

  for (const row of orphans) {
    const guild = client.guilds.cache.get(row['guild_id'] as string);
    if (!guild) continue;

    const vc      = guild.channels.cache.get(row['vc_channel_id'] as string);
    const isEmpty = !vc || vc.type !== ChannelType.GuildVoice || vc.members.size === 0;

    if (isEmpty) {
      const textCh        = guild.channels.cache.get(row['text_channel_id'] as string);
      const waitingRoomCh = row['waiting_room_vc_id']
        ? guild.channels.cache.get(row['waiting_room_vc_id'] as string)
        : undefined;

      if (textCh)        await textCh.delete('Bot再起動時の孤立一時チャンネル清掃').catch(() => {});
      if (waitingRoomCh) await waitingRoomCh.delete('Bot再起動時の孤立待機室清掃').catch(() => {});
      await vc?.delete('Bot再起動時の孤立一時VC清掃').catch(() => {});
      await supabase.from('temp_channels').delete().eq('id', row['id']);
      console.log(`[TempVC] 孤立チャンネル削除: ${row['text_channel_id']}`);
    }
  }
});
