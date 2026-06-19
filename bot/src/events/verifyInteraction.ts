import {
  Events, ButtonStyle, ActionRowBuilder, ButtonBuilder,
  type Interaction, type ButtonInteraction, type Guild,
} from 'discord.js';
import { createHmac } from 'node:crypto';
import { client } from '../client.js';
import { supabase } from '../db.js';

// ── 型 ──────────────────────────────────────────────────────

interface VerifyPanelRow {
  id: string; guild_id: string; name: string; role_id: string;
  enabled: boolean; verify_type: string; reaction_emoji: string;
  manual_channel_id: string | null;
}

// ── ユーティリティ ───────────────────────────────────────────

const WORKER_URL    = process.env.WORKER_URL    ?? 'https://noxy-scheduler.watch-yugo.workers.dev';
const API_SECRET    = process.env.WORKER_API_SECRET ?? '';

function makeVerifyUrl(panelId: string, userId: string, guildId: string): string {
  const exp = String(Date.now() + 10 * 60 * 1000);
  const sig = createHmac('sha256', API_SECRET).update(`${panelId}:${userId}:${guildId}:${exp}`).digest('hex');
  return `${WORKER_URL}/verify/${panelId}?u=${userId}&g=${guildId}&exp=${exp}&sig=${sig}`;
}

async function grantRole(guild: Guild, userId: string, roleId: string): Promise<boolean> {
  try {
    const member = await guild.members.fetch(userId);
    await member.roles.add(roleId);
    return true;
  } catch { return false; }
}

async function sendDM(userId: string, content: string): Promise<void> {
  try {
    const user = await client.users.fetch(userId);
    await user.send(content);
  } catch { /* DM 失敗は無視 */ }
}

// ── 認証タイプ別ハンドラ ─────────────────────────────────────

// CAPTCHA: 署名付きURL を ephemeral 送信
async function handleCaptchaVerify(interaction: ButtonInteraction, panel: VerifyPanelRow): Promise<void> {
  const verifyUrl = makeVerifyUrl(panel.id, interaction.user.id, interaction.guildId!);
  const btn = new ButtonBuilder().setLabel('🔐 認証ページを開く').setStyle(ButtonStyle.Link).setURL(verifyUrl);
  await interaction.editReply({
    embeds: [{
      title: '✅ 認証を開始します',
      description: '下のボタンからブラウザを開き、認証を完了してください。\n\n⏰ このリンクは **10分間** 有効です。',
      color: 0x10b981,
    }],
    components: [new ActionRowBuilder<ButtonBuilder>().addComponents(btn)],
  });
}

// ワンクリック: 即時ロール付与
async function handleButtonVerify(interaction: ButtonInteraction, panel: VerifyPanelRow): Promise<void> {
  const ok = await grantRole(interaction.guild!, interaction.user.id, panel.role_id);
  if (ok) {
    await interaction.editReply({
      embeds: [{ title: '✅ 認証完了', description: 'ロールが付与されました！', color: 0x10b981 }],
      components: [],
    });
  } else {
    await interaction.editReply({ content: '❌ ロールの付与に失敗しました。管理者にお問い合わせください。' });
  }
}

// リアクション: 案内メッセージを送信
async function handleReactionVerify(interaction: ButtonInteraction, panel: VerifyPanelRow): Promise<void> {
  await interaction.editReply({
    embeds: [{
      title: '✅ リアクション認証',
      description: `パネルメッセージの **${panel.reaction_emoji}** にリアクションすることで認証されます。`,
      color: 0xf59e0b,
    }],
    components: [],
  });
}

// OAuth2: Worker の OAuth2 認証ページへ誘導
async function handleOAuth2Verify(interaction: ButtonInteraction, panel: VerifyPanelRow): Promise<void> {
  const oauthUrl = `${WORKER_URL}/oauth2/start?panel_id=${panel.id}&user_id=${interaction.user.id}&guild_id=${interaction.guildId!}`;
  const btn = new ButtonBuilder().setLabel('🔐 OAuth2認証を行う').setStyle(ButtonStyle.Link).setURL(oauthUrl);
  await interaction.editReply({
    embeds: [{
      title: '🔐 OAuth2認証を開始します',
      description: '下のボタンからブラウザを開き、Discord認証を完了してください。\n\n' +
        '認証によりロールが付与され、万が一の際のサーバー復旧にも利用できるようになります。',
      color: 0x5865f2,
    }],
    components: [new ActionRowBuilder<ButtonBuilder>().addComponents(btn)],
  });
}

// 手動認証: リクエスト作成 + 管理者通知
async function handleManualVerify(interaction: ButtonInteraction, panel: VerifyPanelRow): Promise<void> {
  const user = interaction.user;

  // 既存の pending リクエストがあれば案内して終了
  const { data: existing } = await supabase
    .from('verify_requests')
    .select('id')
    .eq('panel_id', panel.id)
    .eq('user_id', user.id)
    .eq('status', 'pending')
    .single();

  if (existing) {
    await interaction.editReply({ content: '⏳ すでに申請が送信されています。管理者の承認をお待ちください。' });
    return;
  }

  // リクエスト作成
  const avatarUrl = user.displayAvatarURL({ size: 64 });
  const { data: reqData, error } = await supabase
    .from('verify_requests')
    .insert({
      panel_id:   panel.id,
      guild_id:   interaction.guildId!,
      user_id:    user.id,
      username:   user.username,
      avatar_url: avatarUrl,
    })
    .select()
    .single();

  if (error || !reqData) {
    await interaction.editReply({ content: '❌ 申請の送信に失敗しました。' });
    return;
  }

  const reqId = reqData.id as string;

  // 管理者通知チャンネルに送信
  if (panel.manual_channel_id) {
    try {
      const ch = await interaction.guild!.channels.fetch(panel.manual_channel_id);
      if (ch?.isTextBased()) {
        const approveBtn = new ButtonBuilder()
          .setCustomId(`verify_approve_${reqId}`).setLabel('✅ 承認').setStyle(ButtonStyle.Success);
        const denyBtn = new ButtonBuilder()
          .setCustomId(`verify_deny_${reqId}`).setLabel('❌ 拒否').setStyle(ButtonStyle.Danger);
        const row = new ActionRowBuilder<ButtonBuilder>().addComponents(approveBtn, denyBtn);

        await (ch as import('discord.js').TextChannel).send({
          embeds: [{
            title: '🔔 認証申請',
            description: `${user.toString()} が認証を申請しました。`,
            thumbnail: { url: avatarUrl },
            fields: [
              { name: 'ユーザー', value: `@${user.username} (${user.id})`, inline: true },
              { name: '申請ID', value: `\`${reqId.slice(-8)}\``, inline: true },
            ],
            color: 0xf59e0b,
            timestamp: new Date().toISOString(),
          }],
          components: [row],
        });
      }
    } catch { /* チャンネル送信失敗は無視 */ }
  }

  await interaction.editReply({
    embeds: [{
      title: '⏳ 申請を送信しました',
      description: '管理者が確認後、ロールが付与されます。\n承認/拒否の結果はDMでお知らせします。',
      color: 0xf59e0b,
    }],
    components: [],
  });
}

// ── 承認 / 拒否ボタン処理 ────────────────────────────────────

async function handleApprove(interaction: ButtonInteraction, reqId: string): Promise<void> {
  await interaction.deferUpdate();

  const { data: reqData } = await supabase.from('verify_requests').select('*, verify_panels(role_id)').eq('id', reqId).single();
  if (!reqData) { await interaction.followUp({ content: '❌ リクエストが見つかりません。', ephemeral: true }); return; }

  const roleId = (reqData['verify_panels'] as { role_id: string } | null)?.role_id ?? '';
  if (roleId) {
    const ok = await grantRole(interaction.guild!, reqData['user_id'] as string, roleId);
    if (!ok) { await interaction.followUp({ content: '❌ ロール付与に失敗しました。', ephemeral: true }); return; }
  }

  await supabase.from('verify_requests').update({ status: 'approved', resolved_at: new Date().toISOString() }).eq('id', reqId);
  await sendDM(reqData['user_id'] as string, '✅ **認証が承認されました！** ロールが付与されました。');

  // ボタンを無効化
  const disabledApprove = ButtonBuilder.from(interaction.component).setDisabled(true).setLabel('✅ 承認済');
  await interaction.message.edit({ components: [new ActionRowBuilder<ButtonBuilder>().addComponents(disabledApprove)] });
  await interaction.followUp({ content: `✅ 承認しました。`, ephemeral: true });
}

async function handleDeny(interaction: ButtonInteraction, reqId: string): Promise<void> {
  await interaction.deferUpdate();

  const { data: reqData } = await supabase.from('verify_requests').select('user_id').eq('id', reqId).single();
  if (!reqData) { await interaction.followUp({ content: '❌ リクエストが見つかりません。', ephemeral: true }); return; }

  await supabase.from('verify_requests').update({ status: 'denied', resolved_at: new Date().toISOString() }).eq('id', reqId);
  await sendDM(reqData['user_id'] as string, '❌ **認証が拒否されました。** 詳細はサーバーの管理者にお問い合わせください。');

  const disabledDeny = ButtonBuilder.from(interaction.component).setDisabled(true).setLabel('❌ 拒否済');
  await interaction.message.edit({ components: [new ActionRowBuilder<ButtonBuilder>().addComponents(disabledDeny)] });
  await interaction.followUp({ content: `拒否しました。`, ephemeral: true });
}

// ── メインリスナー ────────────────────────────────────────────

client.on(Events.InteractionCreate, async (interaction: Interaction) => {
  if (!interaction.isButton()) return;
  const id = interaction.customId;

  // 承認・拒否ボタン
  if (id.startsWith('verify_approve_')) {
    try { await handleApprove(interaction as ButtonInteraction, id.replace('verify_approve_', '')); } catch (e) { console.error('[Verify] approve error:', e); }
    return;
  }
  if (id.startsWith('verify_deny_')) {
    try { await handleDeny(interaction as ButtonInteraction, id.replace('verify_deny_', '')); } catch (e) { console.error('[Verify] deny error:', e); }
    return;
  }

  // 認証開始ボタン
  if (!id.startsWith('verify_start_')) return;
  const panelId = id.replace('verify_start_', '');

  try {
    await (interaction as ButtonInteraction).deferReply({ ephemeral: true });
    const btn = interaction as ButtonInteraction;

    const { data: panelData } = await supabase.from('verify_panels').select('*').eq('id', panelId).single();
    if (!panelData) { await btn.editReply('❌ 認証パネルが見つかりません。'); return; }
    const panel = panelData as VerifyPanelRow;

    if (!panel.enabled) { await btn.editReply('❌ この認証パネルは現在無効です。'); return; }

    // すでに認証済みチェック
    if (panel.role_id) {
      const member = await btn.guild!.members.fetch(btn.user.id).catch(() => null);
      if (member?.roles.cache.has(panel.role_id)) {
        await btn.editReply('✅ すでに認証済みです！'); return;
      }
    }

    switch (panel.verify_type) {
      case 'captcha':   await handleCaptchaVerify(btn, panel); break;
      case 'button':    await handleButtonVerify(btn, panel); break;
      case 'reaction':  await handleReactionVerify(btn, panel); break;
      case 'manual':    await handleManualVerify(btn, panel); break;
      case 'oauth2':    await handleOAuth2Verify(btn, panel); break;
      default: await btn.editReply('❌ 不明な認証タイプです。');
    }
  } catch (e) {
    console.error('[Verify] interaction error:', e);
    try {
      const fn = (interaction as ButtonInteraction).replied || (interaction as ButtonInteraction).deferred
        ? (interaction as ButtonInteraction).followUp.bind(interaction as ButtonInteraction)
        : (interaction as ButtonInteraction).reply.bind(interaction as ButtonInteraction);
      await fn({ content: '❌ エラーが発生しました。', ephemeral: true });
    } catch { /* ignore */ }
  }
});
