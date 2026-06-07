import {
  Events, ChannelType, PermissionFlagsBits,
  ActionRowBuilder, ButtonBuilder, ButtonStyle,
  ModalBuilder, TextInputBuilder, TextInputStyle,
  type Interaction, type TextChannel, type GuildMember,
  type StringSelectMenuInteraction, type ButtonInteraction,
} from 'discord.js';
import { client } from '../client.js';
import { supabase } from '../db.js';

// ── 型 ──────────────────────────────────────────────────────

interface ShopRow { id: string; guild_id: string; name: string; description: string; color: number; footer_text: string;
  order_category_id: string|null; archive_category_id: string|null; support_role_id: string|null;
  review_enabled: boolean; review_channel_id: string|null; disabled_message: string|null;
  welcome_image_url: string|null; welcome_thumbnail_url: string|null;
  welcome_fields: Array<{name: string; value: string; inline: boolean}>;
  welcome_footer_text: string|null; welcome_footer_icon_url: string|null;
  welcome_show_timestamp: boolean; }
interface ProductRow { id: string; shop_id: string; name: string; description: string;
  price_display: string; stock: number|null; reward_type: string; reward_content: string|null;
  reward_role_id: string|null; reward_dm_content: string|null; }
interface OrderRow { id: string; shop_id: string; product_id: string; channel_id: string;
  buyer_user_id: string; buyer_username: string; product_name: string; product_price_display: string;
  status: string; buyer_confirmed: boolean; seller_confirmed: boolean; buyer_cancel_requested: boolean;
  payment_url: string|null; payment_submitted_at: string|null; }

// ── 変数展開 ─────────────────────────────────────────────────

function expandVariables(text: string, vars: Record<string, string>): string {
  let result = text;
  for (const [key, value] of Object.entries(vars)) {
    result = result.replaceAll(`{${key}}`, value);
  }
  return result;
}

function buildOrderVars(buyer: GuildMember, product: ProductRow, shop: ShopRow, orderId: string): Record<string, string> {
  return {
    'buyer.mention': buyer.toString(),
    'buyer.username': buyer.user.username,
    'buyer.id': buyer.user.id,
    'product.name': product.name,
    'product.description': product.description ?? '',
    'product.price': product.price_display,
    'shop.name': shop.name,
    'order.id': orderId,
    'order.id.short': orderId.slice(-6),
  };
}

// ── ユーティリティ ───────────────────────────────────────────

function hasStaffPermission(member: GuildMember, supportRoleId: string|null): boolean {
  if (member.permissions.has(PermissionFlagsBits.Administrator)) return true;
  if (member.permissions.has(PermissionFlagsBits.ManageChannels)) return true;
  if (supportRoleId && member.roles.cache.has(supportRoleId)) return true;
  return false;
}

async function archiveChannel(guild: import('discord.js').Guild, channelId: string, buyerUserId: string, archiveCategoryId: string|null): Promise<void> {
  const ch = guild.channels.cache.get(channelId) as TextChannel|undefined;
  if (!ch) return;
  await ch.permissionOverwrites.edit(buyerUserId, { ViewChannel: false }).catch(() => {});
  if (archiveCategoryId) await ch.setParent(archiveCategoryId, { lockPermissions: false }).catch(() => {});
  if (!ch.name.startsWith('archive-')) await ch.setName(`archive-${ch.name}`).catch(() => {});
}

async function deliverRewardBot(guild: import('discord.js').Guild, channel: TextChannel, order: OrderRow, product: ProductRow, shop: ShopRow, vars: Record<string, string>): Promise<void> {
  const footerText = shop.welcome_footer_text ?? shop.footer_text;
  const embedBase = {
    color: shop.color,
    footer: footerText ? { text: expandVariables(footerText, vars) } : undefined,
    timestamp: shop.welcome_show_timestamp ? new Date().toISOString() : undefined,
  };
  switch (product.reward_type) {
    case 'text': case 'url':
      await channel.send({ embeds: [{ ...embedBase, title: '📦 商品をお届けします',
        description: expandVariables(product.reward_content ?? '（内容なし）', vars) }] });
      break;
    case 'role': {
      if (product.reward_role_id) {
        const member = await guild.members.fetch(order.buyer_user_id).catch(() => null);
        if (member) await member.roles.add(product.reward_role_id).catch(() => {});
        await channel.send({ embeds: [{ ...embedBase, title: '🎭 ロールを付与しました',
          description: expandVariables(`<@&${product.reward_role_id}> を付与しました。`, vars) }] });
      }
      break;
    }
    case 'dm': {
      const member = await guild.members.fetch(order.buyer_user_id).catch(() => null);
      if (member) {
        await member.send({ embeds: [{ ...embedBase, title: '📦 商品のお届け',
          description: expandVariables(product.reward_dm_content ?? '（内容なし）', vars) }] }).catch(() => {});
      }
      await channel.send({ embeds: [{ ...embedBase, title: '📩 DMで商品をお届けしました' }] });
      break;
    }
  }
}

// ── Step1: セレクトメニューで商品選択 ─────────────────────────

async function handleProductSelect(interaction: StringSelectMenuInteraction, shopId: string): Promise<void> {
  const productId = interaction.values[0];
  await interaction.deferReply({ ephemeral: true });

  const { data: product } = await supabase.from('products').select('*').eq('id', productId).single();
  if (!product) { await interaction.editReply('❌ 商品が見つかりません。'); return; }
  const p = product as ProductRow;

  if (p.stock !== null && p.stock <= 0) {
    await interaction.editReply('❌ この商品は現在売り切れです。'); return;
  }

  const rewardLabels: Record<string, string> = { text: 'テキスト', url: 'URL', role: 'ロール付与', dm: 'DM送信', manual: '手動配達' };

  const confirmBtn = new ButtonBuilder().setCustomId(`shop_buy_${shopId}_${productId}`)
    .setLabel('✅ 購入する').setStyle(ButtonStyle.Success);
  const cancelBtn  = new ButtonBuilder().setCustomId('shop_cancel')
    .setLabel('キャンセル').setStyle(ButtonStyle.Secondary);
  const row = new ActionRowBuilder<ButtonBuilder>().addComponents(confirmBtn, cancelBtn);

  await interaction.editReply({
    embeds: [{
      title:  `🛒 ${p.name}`,
      description: p.description || undefined,
      color:  0x6366f1,
      fields: [
        { name: '価格',     value: p.price_display, inline: true },
        { name: '在庫',     value: p.stock === null ? '無制限' : `残り ${p.stock} 個`, inline: true },
        { name: '対価タイプ', value: rewardLabels[p.reward_type] ?? p.reward_type, inline: true },
      ],
    }],
    components: [row],
  });
}

// ── Step2: 購入ボタン → モーダルを表示 ─────────────────────────

async function handleBuyButton(interaction: ButtonInteraction, shopId: string, productId: string): Promise<void> {
  const modal = new ModalBuilder()
    .setCustomId(`order_buy_modal_${shopId}_${productId}`)
    .setTitle('購入の確認');
  modal.addComponents(new ActionRowBuilder<TextInputBuilder>().addComponents(
    new TextInputBuilder()
      .setCustomId('payment_url')
      .setLabel('支払いURL（任意）')
      .setPlaceholder('https://... 省略可能')
      .setStyle(TextInputStyle.Short)
      .setRequired(false)
      .setMaxLength(500),
  ));
  await interaction.showModal(modal);
}

// ── Step3: 購入モーダル送信 → 注文チャンネル作成 ──────────────

async function handleBuyModalSubmit(interaction: import('discord.js').ModalSubmitInteraction, shopId: string, productId: string): Promise<void> {
  const paymentUrl = interaction.fields.getTextInputValue('payment_url').trim();
  await interaction.deferReply({ ephemeral: true });
  const guild  = interaction.guild!;
  const buyer  = interaction.member as GuildMember;

  const { data: shopData }    = await supabase.from('shops').select('*').eq('id', shopId).single();
  const { data: productData } = await supabase.from('products').select('*').eq('id', productId).single();
  if (!shopData || !productData) {
    await interaction.editReply('❌ データが見つかりません。'); return;
  }
  const shop    = shopData    as ShopRow;
  const product = productData as ProductRow;

  if (product.stock !== null && product.stock <= 0) {
    await interaction.editReply('❌ 購入手続き中に売り切れとなりました。'); return;
  }
  if (product.stock !== null) {
    await supabase.from('products').update({ stock: product.stock - 1 }).eq('id', productId);
  }

  const insertData: Record<string, unknown> = {
    shop_id: shopId, product_id: productId, guild_id: guild.id,
    buyer_user_id: buyer.user.id, buyer_username: buyer.user.username,
    product_name: product.name, product_price_display: product.price_display,
  };
  if (paymentUrl) { insertData['payment_url'] = paymentUrl; insertData['payment_submitted_at'] = new Date().toISOString(); }

  const { data: order } = await supabase.from('orders').insert(insertData).select().single();
  if (!order) { await interaction.editReply('❌ 注文の作成に失敗しました。'); return; }

  const orderId = (order as OrderRow).id;
  const vars = buildOrderVars(buyer, product, shop, orderId);

  const overwrites = [
    { id: guild.id,        deny:  [PermissionFlagsBits.ViewChannel] },
    { id: buyer.id,        allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ReadMessageHistory, PermissionFlagsBits.AttachFiles] },
    { id: client.user!.id, allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ReadMessageHistory, PermissionFlagsBits.ManageChannels, PermissionFlagsBits.ManageMessages] },
  ];
  if (shop.support_role_id) {
    overwrites.push({ id: shop.support_role_id, allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ReadMessageHistory, PermissionFlagsBits.ManageMessages] });
  }
  const channelName = `order-${buyer.user.username.toLowerCase().replace(/[^a-z0-9]/g,'')}-${orderId.slice(-4)}`;
  let channel: TextChannel;
  try {
    channel = await guild.channels.create({
      name: channelName, type: ChannelType.GuildText,
      parent: shop.order_category_id ?? undefined,
      permissionOverwrites: overwrites,
    }) as TextChannel;
  } catch {
    await interaction.editReply('❌ チャンネルの作成に失敗しました。'); return;
  }
  await supabase.from('orders').update({ channel_id: channel.id }).eq('id', orderId);

  const welcomeFooter = shop.welcome_footer_text ?? shop.footer_text;
  const welcomeFields = (shop.welcome_fields && shop.welcome_fields.length > 0)
    ? shop.welcome_fields.map(f => ({ name: expandVariables(f.name, vars), value: expandVariables(f.value, vars), inline: f.inline }))
    : [
        { name: '商品', value: expandVariables(product.name, vars), inline: true },
        { name: '価格', value: expandVariables(product.price_display, vars), inline: true },
        { name: '購入者', value: buyer.toString(), inline: true },
      ];

  const welcomeEmbed: Record<string, unknown> = {
    title: expandVariables(`🛒 注文 #{order.id.short}`, vars),
    description: expandVariables(`${buyer.toString()} から注文が届きました。`, vars),
    color: shop.color,
    fields: welcomeFields,
    footer: welcomeFooter ? { text: expandVariables(welcomeFooter, vars), icon_url: shop.welcome_footer_icon_url ?? undefined } : undefined,
    timestamp: shop.welcome_show_timestamp ? new Date().toISOString() : undefined,
  };
  if (shop.welcome_image_url) welcomeEmbed['image'] = { url: shop.welcome_image_url };
  if (shop.welcome_thumbnail_url) welcomeEmbed['thumbnail'] = { url: shop.welcome_thumbnail_url };

  const closeBtn = new ButtonBuilder().setCustomId(`order_close_${orderId}`)
    .setLabel('🔒 クローズ').setStyle(ButtonStyle.Danger);
  const closeRow = new ActionRowBuilder<ButtonBuilder>().addComponents(closeBtn);
  const supportMention = shop.support_role_id ? `<@&${shop.support_role_id}> ` : '';

  // 支払いURLが提供された場合はウェルカムメッセージに追記
  if (paymentUrl) {
    (welcomeEmbed['fields'] as unknown[]).push({ name: '💳 支払いURL', value: paymentUrl, inline: false });
  }

  await channel.send({
    content: expandVariables(`${supportMention}${buyer.toString()}`, vars),
    embeds: [welcomeEmbed],
    components: [closeRow],
  });

  // 管理者宛て支払い確認ボタン
  const payBtn = new ButtonBuilder().setCustomId(`order_pay_${orderId}`)
    .setLabel('✅ 支払いを確認しました').setStyle(ButtonStyle.Success);
  const payRow = new ActionRowBuilder<ButtonBuilder>().addComponents(payBtn);
  const payDesc = paymentUrl
    ? `支払いURLを確認後、下のボタンを押してください。\n> \`${paymentUrl}\``
    : '支払いを確認したら下のボタンを押してください。';
  await channel.send({
    content: `${supportMention}`,
    embeds: [{ title: '📋 管理者アクション', description: payDesc, color: 0x6366f1 }],
    components: [payRow],
  });

  await interaction.editReply(`✅ 注文チャンネルを作成しました → <#${channel.id}>`);
  console.log(`[Shop] 注文作成: ${orderId} (${product.name} by ${buyer.user.username})`);
}

// ── 支払い確認（管理者）→ 対価を送信 ─────────────────────────

async function handleConfirmPayment(interaction: ButtonInteraction, orderId: string): Promise<void> {
  await interaction.deferUpdate();
  const guild  = interaction.guild!;
  const member = interaction.member as GuildMember;

  const { data: orderData } = await supabase.from('orders').select('*').eq('id', orderId).single();
  if (!orderData) { await interaction.followUp({ content: '❌ 注文が見つかりません。', ephemeral: true }); return; }
  const order = orderData as OrderRow;

  const { data: shopData } = await supabase.from('shops').select('*').eq('id', order.shop_id).single();
  if (!hasStaffPermission(member, (shopData as ShopRow|null)?.support_role_id ?? null)) {
    await interaction.followUp({ content: '❌ 権限がありません。', ephemeral: true }); return;
  }
  if (order.status !== 'open') {
    await interaction.followUp({ content: `この注文はすでに ${order.status} 状態です。`, ephemeral: true }); return;
  }

  const { data: productData } = await supabase.from('products').select('*').eq('id', order.product_id).single();
  const product = productData as ProductRow;
  const channel = guild.channels.cache.get(order.channel_id) as TextChannel | undefined;
  const buyer   = await guild.members.fetch(order.buyer_user_id).catch(() => null);
  const vars    = buyer ? buildOrderVars(buyer, product, shopData as ShopRow, orderId) : {};
  const shop    = shopData as ShopRow;
  const now     = new Date().toISOString();
  const buyerMention  = buyer?.toString() ?? '<購入者>';
  const supportMention = shop.support_role_id ? `<@&${shop.support_role_id}>` : '';

  if (product.reward_type === 'manual') {
    // 手動配達: paid状態に移行し、管理者に配送ボタンを表示
    await supabase.from('orders').update({ status: 'paid', paid_at: now }).eq('id', orderId);
    if (channel) {
      const manualDeliveredBtn = new ButtonBuilder()
        .setCustomId(`order_manual_delivered_${orderId}`)
        .setLabel('📦 対価を送信しました').setStyle(ButtonStyle.Primary);
      const cancelReqBtn = new ButtonBuilder().setCustomId(`order_cancel_req_${orderId}`)
        .setLabel('⚠️ キャンセルを申し出る').setStyle(ButtonStyle.Secondary);
      const row = new ActionRowBuilder<ButtonBuilder>().addComponents(manualDeliveredBtn, cancelReqBtn);
      await channel.send({
        content: `${buyerMention} ${supportMention}`,
        embeds: [{ title: '💳 支払い確認済', color: 0x6366f1, timestamp: now,
          description: `${buyerMention} 支払いが確認されました。管理者が対価を準備しています。しばらくお待ちください。` }],
        components: [row],
      });
    }
    await buyer?.send(`💳 **${order.product_name}** の支払いが確認されました。管理者が対価を準備中です。今しばらくお待ちください。`).catch(() => {});
  } else {
    // 自動配達: 対価を即送信して delivered に移行
    if (channel && productData) {
      await deliverRewardBot(guild, channel, order, product, shop, vars);
    }
    await supabase.from('orders').update({ status: 'delivered', paid_at: now, delivered_at: now }).eq('id', orderId);
    if (channel) {
      await sendDeliveredMessage(channel, orderId, buyerMention, supportMention, now, shop.review_enabled);
    }
    await buyer?.send(`✅ **${order.product_name}** の商品をお届けしました。受け取り確認をお願いします。\n注文チャンネルで「✅ 取引完了」ボタンを押してください。`).catch(() => {});
  }
  console.log(`[Shop] 支払確認: ${orderId} (reward_type=${product.reward_type})`);
}

// 配送後の完了案内メッセージを送信（共通化）
async function sendDeliveredMessage(channel: TextChannel, orderId: string, buyerMention: string, supportMention: string, timestamp: string, _reviewEnabled: boolean): Promise<void> {
  const buyerDoneBtn = new ButtonBuilder().setCustomId(`order_done_buyer_${orderId}`)
    .setLabel('✅ 取引完了').setStyle(ButtonStyle.Success);
  const cancelReqBtn = new ButtonBuilder().setCustomId(`order_cancel_req_${orderId}`)
    .setLabel('⚠️ キャンセルを申し出る').setStyle(ButtonStyle.Secondary);
  const doneRow = new ActionRowBuilder<ButtonBuilder>().addComponents(buyerDoneBtn, cancelReqBtn);
  await channel.send({
    content: `${buyerMention} ${supportMention}`,
    embeds: [{ title: '📦 商品をお届けしました', color: 0x10b981, timestamp,
      description: `${buyerMention} 商品をお届けしました。受け取り確認ができたら「✅ 取引完了」を押してください。\n\n⏰ **48時間後に自動的に取引完了となります。**` }],
    components: [doneRow],
  });
}

// ── 手動配達完了（管理者）────────────────────────────────────

async function handleManualDelivered(interaction: ButtonInteraction, orderId: string): Promise<void> {
  await interaction.deferUpdate();
  const guild  = interaction.guild!;
  const member = interaction.member as GuildMember;

  const { data: orderData } = await supabase.from('orders').select('*').eq('id', orderId).single();
  if (!orderData) { await interaction.followUp({ content: '❌ 注文が見つかりません。', ephemeral: true }); return; }
  const order = orderData as OrderRow;

  const { data: shopData } = await supabase.from('shops').select('*').eq('id', order.shop_id).single();
  if (!hasStaffPermission(member, (shopData as ShopRow|null)?.support_role_id ?? null)) {
    await interaction.followUp({ content: '❌ 管理者のみ押せます。', ephemeral: true }); return;
  }
  if (order.status !== 'paid') {
    await interaction.followUp({ content: `この注文は ${order.status} 状態です。`, ephemeral: true }); return;
  }

  const now = new Date().toISOString();
  await supabase.from('orders').update({ status: 'delivered', delivered_at: now }).eq('id', orderId);

  const shop    = shopData as ShopRow;
  const channel = guild.channels.cache.get(order.channel_id) as TextChannel | undefined;
  const buyer   = await guild.members.fetch(order.buyer_user_id).catch(() => null);
  const buyerMention   = buyer?.toString() ?? '<購入者>';
  const supportMention = shop.support_role_id ? `<@&${shop.support_role_id}>` : '';

  if (channel) {
    await sendDeliveredMessage(channel, orderId, buyerMention, supportMention, now, shop.review_enabled);
  }
  await buyer?.send(`📦 **${order.product_name}** の対価が送信されました。受け取り確認をお願いします。`).catch(() => {});
  console.log(`[Shop] 手動配達完了: ${orderId}`);
}

// ── 取引完了ボタン（購入者のみ）───────────────────────────────

async function handleOrderDone(interaction: ButtonInteraction, orderId: string): Promise<void> {
  await interaction.deferUpdate();
  const guild  = interaction.guild!;
  const member = interaction.member as GuildMember;

  const { data: orderData } = await supabase.from('orders').select('*').eq('id', orderId).single();
  if (!orderData) { await interaction.followUp({ content: '❌ 注文が見つかりません。', ephemeral: true }); return; }
  const order = orderData as OrderRow;

  if (member.user.id !== order.buyer_user_id) {
    await interaction.followUp({ content: '❌ 購入者のみ押せます。', ephemeral: true }); return;
  }
  if (order.status !== 'delivered') {
    await interaction.followUp({ content: `この注文は ${order.status} 状態です。`, ephemeral: true }); return;
  }

  const now = new Date().toISOString();
  await supabase.from('orders').update({ status: 'completed', completed_at: now, buyer_confirmed: true }).eq('id', orderId);

  const { data: shopData } = await supabase.from('shops').select('*').eq('id', order.shop_id).single();
  const shop = shopData as ShopRow|null;
  const channel = guild.channels.cache.get(order.channel_id) as TextChannel|undefined;

  if (channel) {
    await sendCompletedMessage(channel, orderId, now, shop);
  }

  const buyer = await guild.members.fetch(order.buyer_user_id).catch(() => null);
  await buyer?.send(`🎉 **${order.product_name}** の取引が完了しました。ありがとうございました！`).catch(() => {});
  console.log(`[Shop] 取引完了: ${orderId}`);
}

// 取引完了メッセージ（閉じる・レビューボタン付き）
async function sendCompletedMessage(channel: TextChannel, orderId: string, timestamp: string, shop: ShopRow|null): Promise<void> {
  const closeBtn = new ButtonBuilder().setCustomId(`order_complete_close_${orderId}`)
    .setLabel('🔒 チャンネルを閉じる').setStyle(ButtonStyle.Secondary);
  const btns = [closeBtn];
  if (shop?.review_enabled && shop?.review_channel_id) {
    btns.push(new ButtonBuilder().setCustomId(`order_review_${orderId}`)
      .setLabel('⭐ レビューする').setStyle(ButtonStyle.Primary));
  }
  const row = new ActionRowBuilder<ButtonBuilder>().addComponents(btns);
  await channel.send({
    embeds: [{ title: '🎉 取引完了', color: 0x10b981, timestamp,
      description: '取引が完了しました。チャンネルを閉じる場合は下のボタンを押してください。' +
        (shop?.review_enabled ? '\nレビューもぜひお願いします！' : '') }],
    components: [row],
  });
}

// ── クローズ（管理者が進行中の注文をキャンセル）───────────────

async function handleOrderClose(interaction: ButtonInteraction, orderId: string): Promise<void> {
  await interaction.deferUpdate();
  const guild  = interaction.guild!;
  const member = interaction.member as GuildMember;

  const { data: orderData } = await supabase.from('orders').select('*').eq('id', orderId).single();
  if (!orderData) { await interaction.followUp({ content: '❌ 注文が見つかりません。', ephemeral: true }); return; }
  const order = orderData as OrderRow;

  const { data: shopData } = await supabase.from('shops').select('*').eq('id', order.shop_id).single();
  if (!hasStaffPermission(member, (shopData as ShopRow|null)?.support_role_id ?? null)) {
    await interaction.followUp({ content: '❌ 管理者のみクローズできます。', ephemeral: true }); return;
  }

  if (order.status !== 'completed') {
    await supabase.from('orders').update({ status: 'cancelled', cancelled_at: new Date().toISOString() }).eq('id', orderId);
  }
  const channel = guild.channels.cache.get(order.channel_id) as TextChannel|undefined;
  if (channel) {
    await channel.send({ embeds: [{ title: '🔒 チャンネルをクローズします', color: 0xef4444, timestamp: new Date().toISOString() }] });
  }
  await archiveChannel(guild, order.channel_id, order.buyer_user_id, (shopData as ShopRow|null)?.archive_category_id ?? null);
  console.log(`[Shop] クローズ: ${orderId}`);
}

// ── 取引完了後のチャンネルを閉じる（購入者・管理者どちらでも）─

async function handleCompletionClose(interaction: ButtonInteraction, orderId: string): Promise<void> {
  await interaction.deferUpdate();
  const guild  = interaction.guild!;
  const member = interaction.member as GuildMember;

  const { data: orderData } = await supabase.from('orders').select('*').eq('id', orderId).single();
  if (!orderData) { await interaction.followUp({ content: '❌ 注文が見つかりません。', ephemeral: true }); return; }
  const order = orderData as OrderRow;

  const { data: shopData } = await supabase.from('shops').select('*').eq('id', order.shop_id).single();
  const isStaff = hasStaffPermission(member, (shopData as ShopRow|null)?.support_role_id ?? null);
  const isBuyer = member.user.id === order.buyer_user_id;
  if (!isStaff && !isBuyer) {
    await interaction.followUp({ content: '❌ 購入者または管理者のみ閉じられます。', ephemeral: true }); return;
  }

  const channel = guild.channels.cache.get(order.channel_id) as TextChannel|undefined;
  if (channel) {
    await channel.send({ embeds: [{ title: '🔒 チャンネルを閉じます', color: 0x6b7280, timestamp: new Date().toISOString() }] });
  }
  await archiveChannel(guild, order.channel_id, order.buyer_user_id, (shopData as ShopRow|null)?.archive_category_id ?? null);
  console.log(`[Shop] 完了後クローズ: ${orderId}`);
}

// ── レビューボタン → モーダル表示 ─────────────────────────────

async function handleReviewButton(interaction: ButtonInteraction, orderId: string): Promise<void> {
  const modal = new ModalBuilder()
    .setCustomId(`order_review_modal_${orderId}`)
    .setTitle('レビューを投稿する');
  modal.addComponents(
    new ActionRowBuilder<TextInputBuilder>().addComponents(
      new TextInputBuilder().setCustomId('rating').setLabel('⭐ 評価（1〜5の数字）')
        .setPlaceholder('5').setStyle(TextInputStyle.Short).setRequired(true).setMaxLength(1),
    ),
    new ActionRowBuilder<TextInputBuilder>().addComponents(
      new TextInputBuilder().setCustomId('comment').setLabel('💬 コメント（任意）')
        .setPlaceholder('取引の感想をご記入ください。')
        .setStyle(TextInputStyle.Paragraph).setRequired(false).setMaxLength(500),
    ),
  );
  await interaction.showModal(modal);
}

// ── レビューモーダル送信 ──────────────────────────────────────

async function handleReviewModalSubmit(interaction: import('discord.js').ModalSubmitInteraction, orderId: string): Promise<void> {
  const ratingStr = interaction.fields.getTextInputValue('rating').trim();
  const comment   = interaction.fields.getTextInputValue('comment').trim();
  await interaction.deferReply({ ephemeral: true });

  const rating = parseInt(ratingStr, 10);
  if (isNaN(rating) || rating < 1 || rating > 5) {
    await interaction.editReply('❌ 評価は1〜5の数字で入力してください。'); return;
  }

  const { data: orderData } = await supabase.from('orders').select('*').eq('id', orderId).single();
  if (!orderData) { await interaction.editReply('❌ 注文が見つかりません。'); return; }
  const order = orderData as OrderRow;

  if (interaction.user.id !== order.buyer_user_id) {
    await interaction.editReply('❌ 購入者のみレビューできます。'); return;
  }

  const { data: shopData } = await supabase.from('shops').select('*').eq('id', order.shop_id).single();
  const shop = shopData as ShopRow|null;
  if (!shop?.review_channel_id) {
    await interaction.editReply('❌ レビュー投稿先チャンネルが設定されていません。'); return;
  }

  const stars = '⭐'.repeat(rating) + '☆'.repeat(5 - rating);
  const reviewChannel = interaction.guild?.channels.cache.get(shop.review_channel_id) as TextChannel|undefined;
  if (!reviewChannel) {
    await interaction.editReply('❌ レビューチャンネルが見つかりません。'); return;
  }

  await reviewChannel.send({
    embeds: [{
      title: '⭐ 新しいレビュー',
      color: 0xf59e0b,
      fields: [
        { name: '評価', value: `${stars} (${rating}/5)`, inline: true },
        { name: '商品', value: order.product_name, inline: true },
        { name: '購入者', value: `<@${order.buyer_user_id}> (${order.buyer_username})`, inline: true },
        ...(comment ? [{ name: 'コメント', value: comment, inline: false }] : []),
      ],
      timestamp: new Date().toISOString(),
    }],
  });

  await interaction.editReply('✅ レビューを投稿しました。ありがとうございました！');
  console.log(`[Shop] レビュー投稿: ${orderId} 評価=${rating}`);
}

// ── 購入者のキャンセル申請 ─────────────────────────────────────

async function handleCancelRequest(interaction: ButtonInteraction, orderId: string): Promise<void> {
  await interaction.deferUpdate();
  const member = interaction.member as GuildMember;

  const { data: orderData } = await supabase.from('orders').select('*').eq('id', orderId).single();
  if (!orderData) { await interaction.followUp({ content: '❌ 注文が見つかりません。', ephemeral: true }); return; }
  const order = orderData as OrderRow;

  if (member.user.id !== order.buyer_user_id) {
    await interaction.followUp({ content: '❌ 購入者のみキャンセルを申し出られます。', ephemeral: true }); return;
  }

  await supabase.from('orders').update({ buyer_cancel_requested: true }).eq('id', orderId);

  const channel = interaction.channel as TextChannel|undefined;
  if (channel) {
    const confirmBtn = new ButtonBuilder().setCustomId(`order_cancel_ok_${orderId}`)
      .setLabel('✅ キャンセルを承認する').setStyle(ButtonStyle.Danger);
    const row = new ActionRowBuilder<ButtonBuilder>().addComponents(confirmBtn);
    await channel.send({
      embeds: [{ title: '⚠️ キャンセル申請', description: `${member.toString()} がキャンセルを申し出ました。管理者は承認するか、引き続き対応してください。`, color: 0xf59e0b }],
      components: [row],
    });
  }
}

// ── 管理者のキャンセル承認 ─────────────────────────────────────

async function handleCancelConfirm(interaction: ButtonInteraction, orderId: string): Promise<void> {
  await interaction.deferUpdate();
  const guild  = interaction.guild!;
  const member = interaction.member as GuildMember;

  const { data: orderData } = await supabase.from('orders').select('*').eq('id', orderId).single();
  if (!orderData) { await interaction.followUp({ content: '❌ 注文が見つかりません。', ephemeral: true }); return; }
  const order = orderData as OrderRow;

  const { data: shopData } = await supabase.from('shops').select('*').eq('id', order.shop_id).single();
  if (!hasStaffPermission(member, (shopData as ShopRow|null)?.support_role_id ?? null)) {
    await interaction.followUp({ content: '❌ 管理者のみ承認できます。', ephemeral: true }); return;
  }

  await supabase.from('orders').update({ status: 'cancelled', cancelled_at: new Date().toISOString() }).eq('id', orderId);
  const channel = guild.channels.cache.get(order.channel_id) as TextChannel|undefined;
  if (channel) {
    await channel.send({ embeds: [{ title: '❌ キャンセルが承認されました', description: 'チャンネルをアーカイブします。', color: 0xef4444 }] });
  }
  await archiveChannel(guild, order.channel_id, order.buyer_user_id, (shopData as ShopRow|null)?.archive_category_id ?? null);
}

// ── 異議申し立て ─────────────────────────────────────────────

async function handleDisputeButton(interaction: ButtonInteraction, shopId: string): Promise<void> {
  const modal = new ModalBuilder().setCustomId(`shop_dispute_modal_${shopId}`).setTitle('異議申し立て');
  modal.addComponents(new ActionRowBuilder<TextInputBuilder>().addComponents(
    new TextInputBuilder().setCustomId('dispute_description').setLabel('内容・注文ID（わかれば）')
      .setPlaceholder('注文ID: abc123\n問題の内容: 商品を受け取れませんでした。')
      .setStyle(TextInputStyle.Paragraph).setRequired(true).setMaxLength(500),
  ));
  await interaction.showModal(modal);
}

async function handleDisputeModalSubmit(interaction: import('discord.js').ModalSubmitInteraction, shopId: string): Promise<void> {
  const description = interaction.fields.getTextInputValue('dispute_description');
  await interaction.deferReply({ ephemeral: true });

  const guild  = interaction.guild!;
  const member = interaction.member as GuildMember;

  const { data: shopData } = await supabase.from('shops').select('*').eq('id', shopId).single();
  const shop = shopData as ShopRow|null;

  const overwrites = [
    { id: guild.id,        deny:  [PermissionFlagsBits.ViewChannel] },
    { id: member.id,       allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ReadMessageHistory] },
    { id: client.user!.id, allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ManageChannels] },
  ];
  if (shop?.support_role_id) overwrites.push({ id: shop.support_role_id, allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ReadMessageHistory, PermissionFlagsBits.ManageMessages] });

  const channel = await guild.channels.create({
    name: `dispute-${member.user.username.toLowerCase().replace(/[^a-z0-9]/g,'')}`,
    type: ChannelType.GuildText, parent: shop?.order_category_id ?? undefined,
    permissionOverwrites: overwrites,
  }) as TextChannel;

  const supportMention = shop?.support_role_id ? `<@&${shop.support_role_id}>` : '';
  await channel.send({
    content: `${supportMention} ${member.toString()}`,
    embeds: [{ title: '⚠️ 異議申し立て', description: description, color: 0xf59e0b,
      fields: [{ name: '申立者', value: member.toString(), inline: true }],
      footer: shop?.footer_text ? { text: shop.footer_text } : undefined,
      timestamp: new Date().toISOString() }],
  });
  await interaction.editReply(`⚠️ 異議チャンネルを作成しました → <#${channel.id}>`);
}

// ── メインリスナー ───────────────────────────────────────────

client.on(Events.InteractionCreate, async (interaction: Interaction) => {
  try {
    // セレクトメニュー
    if (interaction.isStringSelectMenu() && interaction.customId.startsWith('shop_select_')) {
      await handleProductSelect(interaction, interaction.customId.replace('shop_select_', ''));
      return;
    }

    // ボタン
    if (interaction.isButton()) {
      const id = interaction.customId;
      if (id === 'shop_cancel') { await interaction.update({ content: 'キャンセルしました。', embeds: [], components: [] }); return; }

      const buyMatch = id.match(/^shop_buy_([^_]+)_(.+)$/);
      if (buyMatch) { await handleBuyButton(interaction, buyMatch[1], buyMatch[2]); return; }

      if (id.startsWith('order_pay_'))              { await handleConfirmPayment(interaction, id.replace('order_pay_', '')); return; }
      if (id.startsWith('order_manual_delivered_')) { await handleManualDelivered(interaction, id.replace('order_manual_delivered_', '')); return; }
      if (id.startsWith('order_done_buyer_'))       { await handleOrderDone(interaction, id.replace('order_done_buyer_', '')); return; }
      if (id.startsWith('order_complete_close_'))   { await handleCompletionClose(interaction, id.replace('order_complete_close_', '')); return; }
      if (id.startsWith('order_review_'))           { await handleReviewButton(interaction, id.replace('order_review_', '')); return; }
      if (id.startsWith('order_close_'))            { await handleOrderClose(interaction, id.replace('order_close_', '')); return; }
      if (id.startsWith('order_cancel_req_'))       { await handleCancelRequest(interaction, id.replace('order_cancel_req_', '')); return; }
      if (id.startsWith('order_cancel_ok_'))        { await handleCancelConfirm(interaction, id.replace('order_cancel_ok_', '')); return; }
      if (id.startsWith('shop_dispute_'))           { await handleDisputeButton(interaction, id.replace('shop_dispute_', '')); return; }
    }

    // モーダル送信
    if (interaction.isModalSubmit()) {
      const buyModalMatch = interaction.customId.match(/^order_buy_modal_([^_]+)_(.+)$/);
      if (buyModalMatch) { await handleBuyModalSubmit(interaction, buyModalMatch[1], buyModalMatch[2]); return; }

      const reviewModalMatch = interaction.customId.match(/^order_review_modal_(.+)$/);
      if (reviewModalMatch) { await handleReviewModalSubmit(interaction, reviewModalMatch[1]); return; }

      const disputeModalMatch = interaction.customId.match(/^shop_dispute_modal_(.+)$/);
      if (disputeModalMatch) { await handleDisputeModalSubmit(interaction, disputeModalMatch[1]); return; }
    }
  } catch (e) {
    console.error('[Shop] interaction error:', e);
    try {
      if (!interaction.isRepliable()) return;
      const fn = (interaction.deferred || interaction.replied)
        ? interaction.followUp.bind(interaction) : interaction.reply.bind(interaction);
      await fn({ content: '❌ エラーが発生しました。しばらくしてからお試しください。', ephemeral: true });
    } catch { /* ignore */ }
  }
});
