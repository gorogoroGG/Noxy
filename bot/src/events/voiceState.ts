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

interface TempVCSource {
  id: string;
  guild_id: string;
  source_vc_id: string;
  name: string;
  category_id: string;
  vc_name_format: string;
  channel_name_format: string;
  user_limit: number;
  auto_delete: boolean;
  delete_delay_minutes: number;
  join_leave_notification: boolean;
  enabled: boolean;
}

// ── #2 チャンネル名レートリミット管理（Discord: 2回/10分）──────
// 5分経過後のみ rename を許可する

const lastRenameTime = new Map<string, number>(); // textChannelId → timestamp

// ── ユーティリティ ───────────────────────────────────────────

function buildChannelName(format: string, vcName: string, userName: string, count: number): string {
  return format
    .replace(/\{vc-name\}/g,   vcName.toLowerCase().replace(/[^a-z0-9ぁ-んァ-ヶ一-龠]/g, '-').replace(/-+/g, '-').slice(0, 32))
    .replace(/\{user-name\}/g, userName.toLowerCase().replace(/[^a-z0-9]/g, ''))
    .replace(/\{count\}/g,     String(count))
    .toLowerCase()
    .slice(0, 100);
}

// #2 チャンネル名を更新（レートリミット付き）
async function tryRenameChannel(textChannel: TextChannel, settings: TempChannelSettings, vcChannel: VoiceChannel): Promise<void> {
  if (!settings.channel_name_format.includes('{count}')) return;

  const now  = Date.now();
  const last = lastRenameTime.get(textChannel.id) ?? 0;
  if (now - last < 5 * 60 * 1000) return; // 5分以内はスキップ

  const newName = buildChannelName(
    settings.channel_name_format,
    vcChannel.name,
    '',
    vcChannel.members.size,
  );
  await textChannel.setName(newName).catch(() => {});
  lastRenameTime.set(textChannel.id, now);
}

// #4 チャンネルトピックを参加者一覧で更新
async function updateTopic(textChannel: TextChannel, vcChannel: VoiceChannel): Promise<void> {
  const names = [...vcChannel.members.values()].map(m => m.displayName).join('、');
  const topic = `🎙️ ${vcChannel.name} | 参加中: ${names || 'なし'}`;
  await textChannel.setTopic(topic).catch(() => {});
}

// ── Join-to-Create: VC名ビルド ──────────────────────────────

function buildVCName(format: string, userName: string, count: number): string {
  return format
    .replace(/\{user-name\}/g, userName.toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 32))
    .replace(/\{count\}/g,     String(count))
    .slice(0, 100);
}

// ── VC参加処理 ───────────────────────────────────────────────

async function handleVoiceJoin(state: VoiceState, settings: TempChannelSettings): Promise<void> {
  const vcChannelId = state.channelId!;
  const guild       = state.guild;
  const member      = state.member!;

  // ── Join-to-Create チェック（優先） ──────────────────────
  const { data: vcSources } = await supabase
    .from('temp_vc_sources')
    .select('*')
    .eq('guild_id', guild.id)
    .eq('source_vc_id', vcChannelId)
    .eq('enabled', true);

  if (vcSources && vcSources.length > 0) {
    await handleJoinToCreate(state, vcSources[0] as TempVCSource);
    return;
  }

  // ── 既存の一時チャンネル処理 ────────────────────────────
  if (!settings.watch_all_vcs && !settings.watch_vc_ids.includes(vcChannelId)) return;

  const vcChannel = guild.channels.cache.get(vcChannelId) as VoiceChannel | undefined;
  if (!vcChannel || vcChannel.type !== ChannelType.GuildVoice) return;

  const memberCount = vcChannel.members.size;
  if (memberCount < settings.min_members) return;

  // 既存の一時チャンネルを確認
  const { data: existing } = await supabase
    .from('temp_channels')
    .select('*')
    .eq('guild_id', guild.id)
    .eq('vc_channel_id', vcChannelId)
    .single();

  if (existing) {
    // ────────────────────────────────────────────────
    // #1 再入室: ViewChannel を明示的に ALLOW に戻す
    //    (以前 deny にしたまま残っているため上書きが必要)
    // ────────────────────────────────────────────────
    const textCh = guild.channels.cache.get(existing.text_channel_id) as TextChannel | undefined;
    if (textCh) {
      await textCh.permissionOverwrites.edit(member.id, {
        ViewChannel:        true,
        SendMessages:       true,
        ReadMessageHistory: true,
        AttachFiles:        true,
      }).catch(() => {});

      if (settings.join_leave_notification) {
        await textCh.send(`👤 **${member.displayName}** が参加しました。`).catch(() => {});
      }

      // #2 チャンネル名を人数に合わせて更新
      await tryRenameChannel(textCh, settings, vcChannel);
      // #4 トピックを更新
      await updateTopic(textCh, vcChannel);
    }
    return;
  }

  // ─────────────────────────────────────────
  // 新規一時チャンネルを作成
  // ─────────────────────────────────────────

  const channelName = buildChannelName(
    settings.channel_name_format,
    vcChannel.name,
    member.user.username,
    memberCount,
  );

  // 参加者全員の権限
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

  // #8 カテゴリ: 設定があればそれ、なければ VC と同じカテゴリ
  const parentId = settings.category_id ?? vcChannel.parentId ?? undefined;

  // #4 初期トピック（参加者リスト）
  const memberNames = [...vcChannel.members.values()].map(m => m.displayName).join('、');
  const topic = `🎙️ ${vcChannel.name}　|　参加中: ${memberNames}`;

  let textChannel: TextChannel;
  try {
    textChannel = await guild.channels.create({
      name:                 channelName,
      type:                 ChannelType.GuildText,
      parent:               parentId,
      topic,
      permissionOverwrites: overwrites,
    }) as TextChannel;
  } catch (e) {
    console.error('[TempChannel] チャンネル作成失敗:', e);
    return;
  }

  // #8 VCチャンネルの直下（rawPosition + 1）に配置
  try {
    await textChannel.setPosition(vcChannel.rawPosition + 1);
  } catch {
    // 位置設定失敗は無視（カテゴリ順が変わるだけ）
  }

  // Supabase に記録
  await supabase.from('temp_channels').insert({
    guild_id:        guild.id,
    vc_channel_id:   vcChannelId,
    text_channel_id: textChannel.id,
  });

  lastRenameTime.set(textChannel.id, Date.now());

  // #3 VCへの誘導ボタン付きウェルカムメッセージ
  const joinBtn = new ButtonBuilder()
    .setStyle(ButtonStyle.Link)
    .setLabel(`🎙️ ${vcChannel.name} に参加する`)
    .setURL(`https://discord.com/channels/${guild.id}/${vcChannelId}`);
  const row = new ActionRowBuilder<ButtonBuilder>().addComponents(joinBtn);

  const memberMentions = [...vcChannel.members.values()].map(m => m.toString()).join(' ');
  await textChannel.send({
    content: memberMentions,
    embeds: [{
      title:       `🎙️ ${vcChannel.name} の一時チャンネル`,
      description: 'このチャンネルは VC に参加しているメンバー専用です。\n全員が退室すると自動的に削除されます。',
      color:       0x5865f2,
      fields: [
        { name: 'VC',     value: `<#${vcChannelId}>`, inline: true },
        { name: '参加者', value: String(memberCount),  inline: true },
      ],
      timestamp: new Date().toISOString(),
    }],
    components: [row],
  }).catch(() => {});

  console.log(`[TempChannel] 作成: ${channelName} (VC: ${vcChannel.name})`);
}

// ── Join-to-Create: 新規VC+チャンネル作成 ────────────────────

async function handleJoinToCreate(state: VoiceState, source: TempVCSource): Promise<void> {
  const guild       = state.guild;
  const member      = state.member!;
  const sourceVC    = guild.channels.cache.get(source.source_vc_id) as VoiceChannel | undefined;
  if (!sourceVC) return;

  // 既に一時VCが存在するかチェック
  const { data: existing } = await supabase
    .from('temp_channels')
    .select('*')
    .eq('guild_id', guild.id)
    .eq('temp_vc_id', source.id)
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
      parent:               source.category_id,
      userLimit:            source.user_limit || undefined,
      permissionOverwrites: overwrites,
    }) as VoiceChannel;
  } catch (e) {
    console.error('[JoinToCreate] VC作成失敗:', e);
    return;
  }

  // テキストチャンネル作成
  const topic = `🎙️ ${vcName} | 参加中: ${member.displayName}`;
  let textChannel: TextChannel;
  try {
    textChannel = await guild.channels.create({
      name:                 channelName,
      type:                 ChannelType.GuildText,
      parent:               source.category_id,
      topic,
      permissionOverwrites: overwrites,
    }) as TextChannel;
  } catch (e) {
    console.error('[JoinToCreate] テキストチャンネル作成失敗:', e);
    await tempVC.delete().catch(() => {});
    return;
  }

  // ユーザーを新しいVCに移動
  await member.voice.setChannel(tempVC).catch(() => {});

  // Supabaseに記録
  await supabase.from('temp_channels').insert({
    guild_id:        guild.id,
    vc_channel_id:   tempVC.id,
    text_channel_id: textChannel.id,
    temp_vc_id:      source.id,
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

  console.log(`[JoinToCreate] 作成: ${vcName} (Source: ${source.name})`);
}

// ── Join-to-Create: 退室処理 ────────────────────────────────

async function handleTempVCLeave(state: VoiceState, tempVcSourceId: string): Promise<void> {
  const vcChannelId = state.channelId!;
  const guild       = state.guild;
  const member      = state.member;

  const { data: tempCh } = await supabase
    .from('temp_channels')
    .select('*')
    .eq('guild_id', guild.id)
    .eq('vc_channel_id', vcChannelId)
    .eq('temp_vc_id', tempVcSourceId)
    .single();

  if (!tempCh) return;

  const textChannel = guild.channels.cache.get(tempCh.text_channel_id) as TextChannel | undefined;
  const vcChannel   = guild.channels.cache.get(vcChannelId) as VoiceChannel | undefined;

  // 退室メンバーの権限剥奪
  if (textChannel && member) {
    await textChannel.permissionOverwrites.edit(member.id, {
      ViewChannel: false,
    }).catch(() => {});

    // ソース設定を取得
    const { data: source } = await supabase
      .from('temp_vc_sources')
      .select('*')
      .eq('id', tempVcSourceId)
      .single();

    if (source && (source as TempVCSource).join_leave_notification) {
      await textChannel.send(`🚪 **${member.displayName}** が退室しました。`).catch(() => {});
    }
  }

  // VCが空になったか確認
  const remaining = vcChannel?.type === ChannelType.GuildVoice ? vcChannel.members.size : 0;

  const { data: source } = await supabase
    .from('temp_vc_sources')
    .select('*')
    .eq('id', tempVcSourceId)
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
      await textChannel?.delete('Join-to-Create 退室により削除').catch(() => {});
      await vc?.delete('Join-to-Create 退室により削除').catch(() => {});
      await supabase.from('temp_channels').delete().eq('id', tempCh.id);
      lastRenameTime.delete(tempCh.text_channel_id);
      console.log(`[JoinToCreate] 削除: ${tempCh.vc_channel_id} (Source: ${tempVcSourceId})`);
    };

    deleteFn().catch(e => console.error('[JoinToCreate] 削除失敗:', e));
  }
}

// ── VC退室処理 ───────────────────────────────────────────────

async function handleVoiceLeave(state: VoiceState, settings: TempChannelSettings): Promise<void> {
  const vcChannelId = state.channelId!;
  const guild       = state.guild;
  const member      = state.member ?? null;

  // temp_vc_idがあるかチェック（Join-to-Createで作成されたVC）
  const { data: tempCh } = await supabase
    .from('temp_channels')
    .select('*')
    .eq('guild_id', guild.id)
    .eq('vc_channel_id', vcChannelId)
    .single();

  if (tempCh && tempCh.temp_vc_id) {
    await handleTempVCLeave(state, tempCh.temp_vc_id);
    return;
  }

  // 既存の一時チャンネル処理
  if (!tempCh) return;

  if (!tempCh) return;

  const textChannel = guild.channels.cache.get(tempCh.text_channel_id) as TextChannel | undefined;

  // 退室メンバーの閲覧権限を明示的に DENY
  if (textChannel && member) {
    await textChannel.permissionOverwrites.edit(member.id, {
      ViewChannel: false,
    }).catch(() => {});

    if (settings.join_leave_notification) {
      await textChannel.send(`🚪 **${member.displayName}** が退室しました。`).catch(() => {});
    }

    // #2 チャンネル名を人数に合わせて更新
    const vcCh = guild.channels.cache.get(vcChannelId) as VoiceChannel | undefined;
    if (vcCh) {
      await tryRenameChannel(textChannel, settings, vcCh);
      // #4 トピックを更新
      await updateTopic(textChannel, vcCh);
    }
  }

  // VC が空になったか確認
  const vcChannel = guild.channels.cache.get(vcChannelId) as VoiceChannel | undefined;
  const remaining  = vcChannel?.type === ChannelType.GuildVoice ? vcChannel.members.size : 0;

  if (remaining === 0 && settings.auto_delete) {
    const delayMs    = (settings.delete_delay_minutes ?? 0) * 60 * 1000;
    const delayLabel = settings.delete_delay_minutes;

    const deleteFn = async () => {
      // #5 ─────────────────────────────────────────────
      // 削除前カウントダウン通知
      // ─────────────────────────────────────────────────

      if (delayMs === 0) {
        // 即削除
        await textChannel?.send('🗑️ VC が空になりました。チャンネルを削除します。').catch(() => {});
        await new Promise(r => setTimeout(r, 3000)); // 3秒猶予

      } else {
        // 猶予あり: まず「X分後に削除」を通知
        await textChannel?.send(
          `🗑️ VC が空になりました。**${delayLabel}分後**にこのチャンネルを削除します。`
        ).catch(() => {});

        // 1分前警告（猶予が 2分以上の場合のみ）
        if (delayMs >= 2 * 60 * 1000) {
          await new Promise(r => setTimeout(r, delayMs - 60 * 1000));

          // 猶予中に再入室した場合はキャンセル
          const vc = guild.channels.cache.get(vcChannelId) as VoiceChannel | undefined;
          if (vc?.type === ChannelType.GuildVoice && vc.members.size > 0) return;

          await textChannel?.send('⚠️ **1分後にこのチャンネルを削除します。**').catch(() => {});
          await new Promise(r => setTimeout(r, 60 * 1000));

        } else {
          await new Promise(r => setTimeout(r, delayMs));
        }
      }

      // 最終確認: 猶予中に再入室した場合はキャンセル
      const vc = guild.channels.cache.get(vcChannelId) as VoiceChannel | undefined;
      if (vc?.type === ChannelType.GuildVoice && vc.members.size > 0) return;

      await textChannel?.delete('VC 退室により一時チャンネルを削除').catch(() => {});
      await supabase.from('temp_channels').delete().eq('id', tempCh.id);
      lastRenameTime.delete(tempCh.text_channel_id);
      console.log(`[TempChannel] 削除: ${tempCh.text_channel_id} (VC: ${vcChannelId})`);
    };

    deleteFn().catch(e => console.error('[TempChannel] 削除失敗:', e));
  }
}

// ── メインリスナー ───────────────────────────────────────────

client.on(Events.VoiceStateUpdate, async (oldState: VoiceState, newState: VoiceState) => {
  const guild = newState.guild;
  console.log(`[TempChannel] VoiceStateUpdate: guild=${guild.id}, oldCh=${oldState.channelId}, newCh=${newState.channelId}`);

  // Join-to-Create用のソースをチェック（settingsがなくても実行）
  const joined = newState.channelId !== oldState.channelId && newState.channelId !== null;
  if (joined) {
    const { data: vcSources } = await supabase
      .from('temp_vc_sources')
      .select('*')
      .eq('guild_id', guild.id)
      .eq('source_vc_id', newState.channelId)
      .eq('enabled', true);

    if (vcSources && vcSources.length > 0) {
      try {
        await handleJoinToCreate(newState, vcSources[0] as TempVCSource);
        return;
      } catch (e) {
        console.error('[JoinToCreate] VoiceStateUpdate error:', e);
      }
    }
  }

  // 既存の一時チャンネル処理
  const { data: settings } = await supabase
    .from('temp_channel_settings')
    .select('*')
    .eq('guild_id', guild.id)
    .eq('enabled', true)
    .single();

  console.log(`[TempChannel] settings for guild=${guild.id}:`, settings ? 'found' : 'not found');

  if (!settings) return;

  const s = settings as TempChannelSettings;

  try {
    const left   = oldState.channelId !== newState.channelId && oldState.channelId !== null;

    console.log(`[TempChannel] joined=${joined}, left=${left}`);

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

    const vc      = guild.channels.cache.get(row.vc_channel_id);
    const isEmpty = !vc || vc.type !== ChannelType.GuildVoice || vc.members.size === 0;

    if (isEmpty) {
      const textCh = guild.channels.cache.get(row.text_channel_id);
      if (textCh) await textCh.delete('Bot再起動時の孤立一時チャンネル清掃').catch(() => {});

      // Join-to-Createで作成されたVCも削除
      if (row.temp_vc_id) {
        await vc?.delete('Bot再起動時の孤立一時VC清掃').catch(() => {});
      }

      await supabase.from('temp_channels').delete().eq('id', row.id);
      console.log(`[TempChannel] 孤立チャンネル削除: ${row.text_channel_id}`);
    }
  }
});
