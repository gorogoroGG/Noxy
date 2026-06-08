import {
  Events,
  ButtonStyle,
  ActionRowBuilder,
  ButtonBuilder,
  PermissionFlagsBits,
  type Interaction,
  type ButtonInteraction,
  type VoiceChannel,
  type TextChannel,
} from 'discord.js';
import { client } from '../client.js';
import { supabase } from '../db.js';

async function sendDM(userId: string, content: string): Promise<void> {
  try {
    const user = await client.users.fetch(userId);
    await user.send(content);
  } catch { /* DM失敗は無視 */ }
}

function disabledRow(userId: string, tempChId: string, approved: boolean): ActionRowBuilder<ButtonBuilder> {
  return new ActionRowBuilder<ButtonBuilder>().addComponents(
    new ButtonBuilder()
      .setCustomId(`vc_wr_approve_${userId}_${tempChId}`)
      .setLabel(approved ? '✅ 承認済み' : '✅ 承認する')
      .setStyle(ButtonStyle.Success)
      .setDisabled(true),
    new ButtonBuilder()
      .setCustomId(`vc_wr_deny_${userId}_${tempChId}`)
      .setLabel(approved ? '❌ 拒否する' : '❌ 拒否済み')
      .setStyle(ButtonStyle.Danger)
      .setDisabled(true),
  );
}

async function handleApprove(
  interaction: ButtonInteraction,
  userId: string,
  tempChId: string,
): Promise<void> {
  await interaction.deferReply({ ephemeral: true });

  const guild      = interaction.guild!;
  const interactor = await guild.members.fetch(interaction.user.id).catch(() => null);
  if (!interactor) { await interaction.editReply({ content: '❌ エラーが発生しました。' }); return; }

  const { data: tempCh } = await supabase.from('temp_channels').select('*').eq('id', tempChId).single();
  if (!tempCh) { await interaction.editReply({ content: '❌ チャンネル情報が見つかりません（既に削除済みかもしれません）。' }); return; }

  // 権限チェック: メインVC内にいるか、ManageGuild 権限を持つ場合のみ操作可能
  const isInMainVC = interactor.voice.channelId === tempCh['vc_channel_id'];
  const isAdmin    = interactor.permissions.has(PermissionFlagsBits.ManageGuild);
  if (!isInMainVC && !isAdmin) {
    await interaction.editReply({ content: '❌ この操作はVCのメンバーまたはサーバー管理者のみ行えます。' });
    return;
  }

  const mainVC = guild.channels.cache.get(tempCh['vc_channel_id'] as string) as VoiceChannel | undefined
    ?? await guild.channels.fetch(tempCh['vc_channel_id'] as string).catch(() => null) as VoiceChannel | null;
  if (!mainVC) { await interaction.editReply({ content: '❌ メインVCが見つかりません（削除済みかもしれません）。' }); return; }

  // メインVCへの参加権限付与
  await mainVC.permissionOverwrites.edit(userId, {
    ViewChannel: true,
    Connect:     true,
    Speak:       true,
  }).catch(e => console.error('[WaitingRoom] VC権限付与失敗:', e));

  // ユーザーをメインVCへ移動
  const targetMember = await guild.members.fetch(userId).catch(() => null);
  if (targetMember !== null && targetMember.voice.channelId === tempCh['waiting_room_vc_id']) {
    await targetMember.voice.setChannel(mainVC).catch(() => {});
  }

  // テキストチャンネルへの参加権限付与と通知
  const textChannel = guild.channels.cache.get(tempCh['text_channel_id'] as string) as TextChannel | undefined
    ?? await guild.channels.fetch(tempCh['text_channel_id'] as string).catch(() => null) as TextChannel | null;
  if (textChannel) {
    await textChannel.permissionOverwrites.edit(userId, {
      ViewChannel:        true,
      SendMessages:       true,
      ReadMessageHistory: true,
      AttachFiles:        true,
    }).catch(() => {});
    await textChannel.send(`✅ ${targetMember?.toString() ?? `<@${userId}>`} の入室が承認されました。`).catch(() => {});
  }

  await interaction.message.edit({ components: [disabledRow(userId, tempChId, true)] }).catch(() => {});
  await sendDM(userId, `✅ **${guild.name}** のボイスチャンネルへの参加が承認されました！`);
  await interaction.editReply({ content: '✅ 承認しました。' });
  console.log(`[WaitingRoom] 承認: userId=${userId}, tempChId=${tempChId}`);
}

async function handleDeny(
  interaction: ButtonInteraction,
  userId: string,
  tempChId: string,
): Promise<void> {
  await interaction.deferReply({ ephemeral: true });

  const guild      = interaction.guild!;
  const interactor = await guild.members.fetch(interaction.user.id).catch(() => null);
  if (!interactor) { await interaction.editReply({ content: '❌ エラーが発生しました。' }); return; }

  const { data: tempCh } = await supabase.from('temp_channels').select('*').eq('id', tempChId).single();
  if (!tempCh) { await interaction.editReply({ content: '❌ チャンネル情報が見つかりません。' }); return; }

  const isInMainVC = interactor.voice.channelId === tempCh['vc_channel_id'];
  const isAdmin    = interactor.permissions.has(PermissionFlagsBits.ManageGuild);
  if (!isInMainVC && !isAdmin) {
    await interaction.editReply({ content: '❌ この操作はVCのメンバーまたはサーバー管理者のみ行えます。' });
    return;
  }

  // 待機室からキック
  const targetMember = await guild.members.fetch(userId).catch(() => null);
  if (targetMember !== null && targetMember.voice.channelId === tempCh['waiting_room_vc_id']) {
    await targetMember.voice.disconnect().catch(() => {});
  }

  // テキストチャンネルに拒否通知
  const textChannel = guild.channels.cache.get(tempCh['text_channel_id'] as string) as TextChannel | undefined
    ?? await guild.channels.fetch(tempCh['text_channel_id'] as string).catch(() => null) as TextChannel | null;
  if (textChannel) {
    const deniedUser = await client.users.fetch(userId).catch(() => null);
    await textChannel.send(`❌ ${deniedUser?.toString() ?? `<@${userId}>`} の入室が拒否されました。`).catch(() => {});
  }

  await interaction.message.edit({ components: [disabledRow(userId, tempChId, false)] }).catch(() => {});
  await sendDM(userId, `❌ **${guild.name}** のボイスチャンネルへの参加が拒否されました。サーバーの管理者にお問い合わせください。`);
  await interaction.editReply({ content: '拒否しました。' });
  console.log(`[WaitingRoom] 拒否: userId=${userId}, tempChId=${tempChId}`);
}

client.on(Events.InteractionCreate, async (interaction: Interaction) => {
  if (!interaction.isButton()) return;
  const id = interaction.customId;

  // フォーマット: vc_wr_approve_{userId}_{tempChId}
  // userId: Discordスノーフレーク（数字のみ）, tempChId: UUID（ハイフン含む、アンダースコアなし）
  if (id.startsWith('vc_wr_approve_')) {
    const rest  = id.slice('vc_wr_approve_'.length);
    const sep   = rest.indexOf('_');
    if (sep === -1) return;
    const userId    = rest.slice(0, sep);
    const tempChId  = rest.slice(sep + 1);
    try { await handleApprove(interaction as ButtonInteraction, userId, tempChId); }
    catch (e) { console.error('[WaitingRoom] approve error:', e); }
    return;
  }

  if (id.startsWith('vc_wr_deny_')) {
    const rest  = id.slice('vc_wr_deny_'.length);
    const sep   = rest.indexOf('_');
    if (sep === -1) return;
    const userId    = rest.slice(0, sep);
    const tempChId  = rest.slice(sep + 1);
    try { await handleDeny(interaction as ButtonInteraction, userId, tempChId); }
    catch (e) { console.error('[WaitingRoom] deny error:', e); }
    return;
  }
});
