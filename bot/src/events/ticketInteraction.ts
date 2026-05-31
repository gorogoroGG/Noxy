import {
  Events,
  type Interaction,
  ChannelType,
  PermissionFlagsBits,
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle,
  ModalBuilder,
  TextInputBuilder,
  TextInputStyle,
  type TextChannel,
  type OverwriteResolvable,
} from 'discord.js';
import { client } from '../client.js';
import { supabase } from '../db.js';

// ── 変数展開 ────────────────────────────────────────────────

function resolveVars(template: string, vars: {
  user: string; username: string; subject: string; ticketId: string;
}): string {
  return template
    .replace(/\{user\.mention\}/g, vars.user)
    .replace(/\{user\.name\}/g,    vars.username)
    .replace(/\{subject\}/g,       vars.subject)
    .replace(/\{ticket_id\}/g,     vars.ticketId);
}

// ── チケット作成 ─────────────────────────────────────────────

async function handleCreateTicket(
  interaction: import('discord.js').ButtonInteraction,
  panelId: string,
): Promise<void> {
  await interaction.deferReply({ ephemeral: true });

  const { data: panelRows } = await supabase
    .from('ticket_panels')
    .select('*')
    .eq('id', panelId)
    .single();

  if (!panelRows) {
    await interaction.editReply('❌ パネル設定が見つかりません。');
    return;
  }

  const panel = panelRows as {
    id: string; guild_id: string; support_role_id: string | null;
    open_category_id: string | null; closed_category_id: string | null;
    ticket_msg_content: string | null; ticket_embed_title: string;
    ticket_embed_color: number; max_open_per_user: number;
  };

  const member = interaction.member as import('discord.js').GuildMember;
  const guild  = interaction.guild!;

  // 同時オープン上限チェック
  if (panel.max_open_per_user > 0) {
    const { data: openTickets } = await supabase
      .from('tickets')
      .select('id, channel_id')
      .eq('guild_id', guild.id)
      .eq('opened_by_user_id', member.user.id)
      .eq('status', 'open');

    // チャンネルが手動削除済みのものは自動クローズ
    for (const t of openTickets ?? []) {
      if (!guild.channels.cache.has(t.channel_id)) {
        await supabase.from('tickets').update({ status: 'closed', closed_at: new Date().toISOString() }).eq('id', t.id);
      }
    }
    const stillOpen = (openTickets ?? []).filter(t => guild.channels.cache.has(t.channel_id));
    if (stillOpen.length >= panel.max_open_per_user) {
      await interaction.editReply(`⚠️ すでに ${panel.max_open_per_user} 件のオープンチケットがあります。`);
      return;
    }
  }

  // モーダルで件名を取得
  const modal = new ModalBuilder()
    .setCustomId(`ticket_subject_${panelId}`)
    .setTitle('チケットを作成');
  modal.addComponents(
    new ActionRowBuilder<TextInputBuilder>().addComponents(
      new TextInputBuilder()
        .setCustomId('subject')
        .setLabel('件名')
        .setPlaceholder('お問い合わせ内容を簡潔に入力してください')
        .setStyle(TextInputStyle.Short)
        .setRequired(true)
        .setMaxLength(100),
    ),
  );
  await interaction.editReply('件名を入力してください。');
  await interaction.followUp({ ephemeral: true });
  // deferReply 済みなので showModal は使えないため、別途モーダル送信
  // ここでは ephemeral返答で誘導（実際のモーダル表示は別 interactionCreate で行う）
  // Note: showModal は deferReply 前に呼ぶ必要があるため実装を分離

  // 実際のチケット作成処理
  await interaction.editReply('⏳ チケットを作成しています...');
  await createTicketChannel(interaction, panel, 'サポートのお問い合わせ');
}

async function createTicketChannel(
  interaction: import('discord.js').ButtonInteraction,
  panel: {
    id: string; guild_id: string; support_role_id: string | null;
    open_category_id: string | null; ticket_msg_content: string | null;
    ticket_embed_title: string; ticket_embed_color: number; max_open_per_user: number;
  },
  subject: string,
): Promise<void> {
  const member = interaction.member as import('discord.js').GuildMember;
  const guild  = interaction.guild!;

  const suffix      = Date.now().toString().slice(-4);
  const channelName = `ticket-${member.user.username.toLowerCase().replace(/[^a-z0-9]/g, '')}-${suffix}`;

  const overwrites: OverwriteResolvable[] = [
    { id: guild.id,        deny:  [PermissionFlagsBits.ViewChannel] },
    { id: member.id,       allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ReadMessageHistory, PermissionFlagsBits.AttachFiles] },
    { id: client.user!.id, allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ReadMessageHistory, PermissionFlagsBits.ManageChannels, PermissionFlagsBits.ManageMessages] },
  ];
  if (panel.support_role_id) {
    overwrites.push({ id: panel.support_role_id, allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ReadMessageHistory, PermissionFlagsBits.ManageMessages, PermissionFlagsBits.AttachFiles] });
  }

  const channel = await guild.channels.create({
    name: channelName,
    type: ChannelType.GuildText,
    parent: panel.open_category_id ?? undefined,
    permissionOverwrites: overwrites,
  });

  // Supabase にチケットを記録
  const { data: ticketData } = await supabase
    .from('tickets')
    .insert({
      guild_id:          guild.id,
      channel_id:        channel.id,
      opened_by_user_id: member.user.id,
      subject,
      panel_id: panel.id,
    })
    .select()
    .single();

  const ticketId = ticketData?.id ?? 'unknown';

  // ウェルカムメッセージ
  const defaultMsg = '{user.mention} さん、チケットを開きました。\nスタッフが対応するまでしばらくお待ちください。\n\n件名：{subject}';
  const welcomeMsg = resolveVars(panel.ticket_msg_content ?? defaultMsg, {
    user:     member.toString(),
    username: member.user.username,
    subject,
    ticketId,
  });

  const supportMention = panel.support_role_id ? `<@&${panel.support_role_id}>` : null;

  const closeBtn = new ButtonBuilder().setCustomId(`ticket_close_${ticketId}`).setLabel('🔒 チケットを閉じる').setStyle(ButtonStyle.Secondary);
  const row = new ActionRowBuilder<ButtonBuilder>().addComponents(closeBtn);

  await channel.send({
    content: supportMention ?? undefined,
    embeds: [{
      title:       `🎫 ${panel.ticket_embed_title} #${ticketId.slice(-6)}`,
      description: welcomeMsg + (supportMention ? `\n\nサポート：${supportMention}` : ''),
      color:       panel.ticket_embed_color,
      fields: [
        { name: '件名',   value: subject,   inline: true },
        { name: '優先度', value: 'medium',  inline: true },
      ],
      timestamp: new Date().toISOString(),
    }],
    components: [row],
  });

  await interaction.editReply(`✅ <#${channel.id}> にチケットを作成しました。`);
}

// ── チケットクローズ ──────────────────────────────────────────

async function handleCloseTicket(
  interaction: import('discord.js').ButtonInteraction,
  ticketId: string,
): Promise<void> {
  await interaction.deferUpdate();

  const { data } = await supabase.from('tickets').select('*').eq('id', ticketId).single();
  if (!data) { await interaction.followUp({ content: '❌ チケットが見つかりません。', ephemeral: true }); return; }

  await supabase.from('tickets').update({ status: 'closed', closed_at: new Date().toISOString() }).eq('id', ticketId);

  const channel = interaction.channel as TextChannel;
  // 開設者の ViewChannel を剥奪
  await channel.permissionOverwrites.edit(data.opened_by_user_id, { ViewChannel: false }).catch(() => {});

  const reopenBtn = new ButtonBuilder().setCustomId(`ticket_reopen_${ticketId}`).setLabel('🔓 再オープン').setStyle(ButtonStyle.Success);
  const row = new ActionRowBuilder<ButtonBuilder>().addComponents(reopenBtn);

  await channel.send({
    content: `🔒 **チケットがクローズされました** — <@${interaction.user.id}> がクローズ\n作成者はこのチャンネルにアクセスできなくなりました。`,
    components: [row],
  });
}

// ── チケット再オープン ────────────────────────────────────────

async function handleReopenTicket(
  interaction: import('discord.js').ButtonInteraction,
  ticketId: string,
): Promise<void> {
  await interaction.deferUpdate();

  const { data } = await supabase.from('tickets').select('*').eq('id', ticketId).single();
  if (!data) { await interaction.followUp({ content: '❌ チケットが見つかりません。', ephemeral: true }); return; }

  await supabase.from('tickets').update({ status: 'open', closed_at: null }).eq('id', ticketId);

  const channel = interaction.channel as TextChannel;
  await channel.permissionOverwrites.edit(data.opened_by_user_id, {
    ViewChannel: true, SendMessages: true, ReadMessageHistory: true, AttachFiles: true,
  }).catch(() => {});

  await channel.send(`🔓 **チケットが再オープンされました** — <@${interaction.user.id}> が再オープン`);
}

// ── InteractionCreate リスナー ────────────────────────────────

client.on(Events.InteractionCreate, async (interaction: Interaction) => {
  if (!interaction.isButton()) return;

  const id = interaction.customId;

  try {
    // パネルの「チケットを作成」ボタン
    if (id.startsWith('ticket_open_')) {
      const panelId = id.replace('ticket_open_', '');
      await handleCreateTicket(interaction, panelId);
      return;
    }
    // クローズボタン
    if (id.startsWith('ticket_close_')) {
      const ticketId = id.replace('ticket_close_', '');
      await handleCloseTicket(interaction, ticketId);
      return;
    }
    // 再オープンボタン
    if (id.startsWith('ticket_reopen_')) {
      const ticketId = id.replace('ticket_reopen_', '');
      await handleReopenTicket(interaction, ticketId);
      return;
    }
  } catch (e) {
    console.error('[Ticket] interaction error:', e);
    const reply = interaction.deferred || interaction.replied
      ? interaction.followUp.bind(interaction)
      : interaction.reply.bind(interaction);
    await reply({ content: '❌ エラーが発生しました。', ephemeral: true }).catch(() => {});
  }
});
