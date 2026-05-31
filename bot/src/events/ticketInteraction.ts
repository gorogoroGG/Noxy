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
  type ModalSubmitInteraction,
  type GuildMember,
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

// ── Step 1: ボタン押下 → モーダル表示 ────────────────────────
// ⚠️ showModal() は deferReply/reply の前に呼ぶ必要がある

async function handleOpenPanelButton(
  interaction: import('discord.js').ButtonInteraction,
  panelId: string,
): Promise<void> {
  // deferReply や reply は一切せず、いきなり showModal
  const modal = new ModalBuilder()
    .setCustomId(`ticket_subject_${panelId}`)
    .setTitle('チケットを作成');

  modal.addComponents(
    new ActionRowBuilder<TextInputBuilder>().addComponents(
      new TextInputBuilder()
        .setCustomId('subject')
        .setLabel('お問い合わせの件名')
        .setPlaceholder('例: ログインできない、機能のリクエストなど')
        .setStyle(TextInputStyle.Short)
        .setRequired(true)
        .setMaxLength(100),
    ),
  );

  await interaction.showModal(modal);
}

// ── Step 2: モーダル送信 → チケット作成 ─────────────────────

async function handleSubjectModalSubmit(
  interaction: ModalSubmitInteraction,
  panelId: string,
): Promise<void> {
  const subject = interaction.fields.getTextInputValue('subject').trim();

  // モーダル送信後は deferReply OK
  await interaction.deferReply({ ephemeral: true });

  const guild  = interaction.guild!;
  const member = interaction.member as GuildMember;

  // Supabase からパネル設定を取得
  const { data: panelData, error: panelError } = await supabase
    .from('ticket_panels')
    .select('*')
    .eq('id', panelId)
    .single();

  if (panelError || !panelData) {
    await interaction.editReply('❌ パネル設定が見つかりません。管理者にお問い合わせください。');
    return;
  }

  const panel = panelData as {
    id: string; guild_id: string; support_role_id: string | null;
    open_category_id: string | null; closed_category_id: string | null;
    ticket_msg_content: string | null; ticket_embed_title: string;
    ticket_embed_color: number; max_open_per_user: number;
  };

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
        await supabase.from('tickets')
          .update({ status: 'closed', closed_at: new Date().toISOString() })
          .eq('id', t.id);
      }
    }
    const stillOpen = (openTickets ?? []).filter(t => guild.channels.cache.has(t.channel_id));
    if (stillOpen.length >= panel.max_open_per_user) {
      await interaction.editReply(`⚠️ すでに ${panel.max_open_per_user} 件のオープンチケットがあります。既存のチケットを確認してください。`);
      return;
    }
  }

  // Discord チャンネルを作成
  const suffix      = Date.now().toString().slice(-4);
  const channelName = `ticket-${member.user.username.toLowerCase().replace(/[^a-z0-9]/g, '')}-${suffix}`;

  const overwrites: OverwriteResolvable[] = [
    { id: guild.id,        deny:  [PermissionFlagsBits.ViewChannel] },
    { id: member.id,       allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ReadMessageHistory, PermissionFlagsBits.AttachFiles] },
    { id: client.user!.id, allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ReadMessageHistory, PermissionFlagsBits.ManageChannels, PermissionFlagsBits.ManageMessages] },
  ];

  if (panel.support_role_id) {
    overwrites.push({
      id: panel.support_role_id,
      allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ReadMessageHistory, PermissionFlagsBits.ManageMessages, PermissionFlagsBits.AttachFiles],
    });
  }

  let channel: TextChannel;
  try {
    channel = await guild.channels.create({
      name: channelName,
      type: ChannelType.GuildText,
      parent: panel.open_category_id ?? undefined,
      permissionOverwrites: overwrites,
    }) as TextChannel;
  } catch (e) {
    console.error('[Ticket] チャンネル作成失敗:', e);
    await interaction.editReply('❌ チャンネルの作成に失敗しました。Botの権限（チャンネルの管理）を確認してください。');
    return;
  }

  // Supabase にチケットを記録
  const { data: ticketData, error: ticketError } = await supabase
    .from('tickets')
    .insert({
      guild_id:          guild.id,
      channel_id:        channel.id,
      opened_by_user_id: member.user.id,
      subject,
      panel_id:          panelId,
    })
    .select()
    .single();

  if (ticketError || !ticketData) {
    console.error('[Ticket] Supabase 記録失敗:', ticketError);
    await interaction.editReply('❌ チケットの記録に失敗しました。管理者にお問い合わせください。');
    return;
  }

  const ticketId = ticketData.id as string;

  // ウェルカムメッセージの変数展開
  const defaultMsg = '{user.mention} さん、チケットを開きました。\nスタッフが対応するまでしばらくお待ちください。\n\n**件名：** {subject}';
  const welcomeMsg = resolveVars(panel.ticket_msg_content ?? defaultMsg, {
    user:     member.toString(),
    username: member.user.username,
    subject,
    ticketId,
  });

  const supportMention = panel.support_role_id ? `<@&${panel.support_role_id}>` : null;

  // 閉じるボタン
  const closeBtn = new ButtonBuilder()
    .setCustomId(`ticket_close_${ticketId}`)
    .setLabel('🔒 チケットを閉じる')
    .setStyle(ButtonStyle.Secondary);

  const row = new ActionRowBuilder<ButtonBuilder>().addComponents(closeBtn);

  try {
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
  } catch (e) {
    console.error('[Ticket] ウェルカムメッセージ送信失敗:', e);
  }

  await interaction.editReply(`✅ <#${channel.id}> にチケットを作成しました。`);
  console.log(`[Ticket] 作成: ${member.user.tag} → ${channelName} (${ticketId})`);
}

// ── チケットクローズ ──────────────────────────────────────────

async function handleCloseTicket(
  interaction: import('discord.js').ButtonInteraction,
  ticketId: string,
): Promise<void> {
  await interaction.deferUpdate();

  const { data } = await supabase.from('tickets').select('*').eq('id', ticketId).single();
  if (!data) {
    await interaction.followUp({ content: '❌ チケットが見つかりません。', ephemeral: true });
    return;
  }

  await supabase.from('tickets')
    .update({ status: 'closed', closed_at: new Date().toISOString() })
    .eq('id', ticketId);

  const channel = interaction.channel as TextChannel;
  await channel.permissionOverwrites.edit(data.opened_by_user_id, { ViewChannel: false }).catch(() => {});

  const reopenBtn = new ButtonBuilder()
    .setCustomId(`ticket_reopen_${ticketId}`)
    .setLabel('🔓 再オープン')
    .setStyle(ButtonStyle.Success);

  const row = new ActionRowBuilder<ButtonBuilder>().addComponents(reopenBtn);

  await channel.send({
    content: `🔒 **チケットがクローズされました** — <@${interaction.user.id}> がクローズ\n作成者はこのチャンネルにアクセスできなくなりました。`,
    components: [row],
  }).catch(() => {});

  console.log(`[Ticket] クローズ: ${ticketId}`);
}

// ── チケット再オープン ────────────────────────────────────────

async function handleReopenTicket(
  interaction: import('discord.js').ButtonInteraction,
  ticketId: string,
): Promise<void> {
  await interaction.deferUpdate();

  const { data } = await supabase.from('tickets').select('*').eq('id', ticketId).single();
  if (!data) {
    await interaction.followUp({ content: '❌ チケットが見つかりません。', ephemeral: true });
    return;
  }

  await supabase.from('tickets')
    .update({ status: 'open', closed_at: null })
    .eq('id', ticketId);

  const channel = interaction.channel as TextChannel;
  await channel.permissionOverwrites.edit(data.opened_by_user_id, {
    ViewChannel: true, SendMessages: true, ReadMessageHistory: true, AttachFiles: true,
  }).catch(() => {});

  await channel.send(`🔓 **チケットが再オープンされました** — <@${interaction.user.id}> が再オープン`).catch(() => {});

  console.log(`[Ticket] 再オープン: ${ticketId}`);
}

// ── InteractionCreate リスナー ────────────────────────────────

client.on(Events.InteractionCreate, async (interaction: Interaction) => {
  try {
    // ボタン操作
    if (interaction.isButton()) {
      const id = interaction.customId;

      if (id.startsWith('ticket_open_')) {
        await handleOpenPanelButton(interaction, id.replace('ticket_open_', ''));
        return;
      }
      if (id.startsWith('ticket_close_')) {
        await handleCloseTicket(interaction, id.replace('ticket_close_', ''));
        return;
      }
      if (id.startsWith('ticket_reopen_')) {
        await handleReopenTicket(interaction, id.replace('ticket_reopen_', ''));
        return;
      }
    }

    // モーダル送信
    if (interaction.isModalSubmit()) {
      if (interaction.customId.startsWith('ticket_subject_')) {
        const panelId = interaction.customId.replace('ticket_subject_', '');
        await handleSubjectModalSubmit(interaction, panelId);
        return;
      }
    }
  } catch (e) {
    console.error('[Ticket] interaction error:', e);
    try {
      if (!interaction.isRepliable()) return;
      const fn = (interaction.deferred || interaction.replied)
        ? interaction.followUp.bind(interaction)
        : interaction.reply.bind(interaction);
      await fn({ content: '❌ エラーが発生しました。しばらくしてからお試しください。', ephemeral: true });
    } catch { /* ignore */ }
  }
});
