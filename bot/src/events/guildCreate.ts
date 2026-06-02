import { Events, EmbedBuilder, ActionRowBuilder, ButtonBuilder, ButtonStyle, ChannelType } from 'discord.js';
import { client } from '../client';

client.on(Events.GuildCreate, async (guild) => {
  console.log(`[GuildJoin] ${guild.name} (${guild.id}) に参加しました。メンバー数: ${guild.memberCount}`);

  const discordServerUrl = process.env.DISCORD_SERVER_URL || 'https://discord.gg/your-server';
  const appStoreUrl = process.env.APP_STORE_URL || 'https://apps.apple.com/app/your-app';

  // 招待したユーザーを取得（最新のメンバーから探す）
  let owner = guild.ownerId ? await guild.members.fetch(guild.ownerId).catch(() => null) : null;

  // オーナーが見つからない場合は、最近参加したメンバーを探す
  if (!owner) {
    const members = await guild.members.fetch({ limit: 100 }).catch(() => []);
    const humanMembers = members.filter(m => !m.user.bot);
    if (humanMembers.size > 0) {
      owner = humanMembers.first();
    }
  }

  // 招待者にDM送信
  if (owner) {
    try {
      const dmEmbed = new EmbedBuilder()
        .setColor(0x5865f2)
        .setTitle('🎉 Noxy をご利用いただきありがとうございます！')
        .setDescription(
          '**Noxy** は Discord サーバーをより便利にする多機能ボットです。\n\n' +
          '🎫 **チケットシステム** - サポート対応を自動化\n' +
          '🛒 **ショップ機能** - 商品販売と注文管理\n' +
          '🎙️ **一時チャンネル** - VC参加で自動作成\n' +
          '📝 **リアクションロール** - 簡単ロール付与\n' +
          '⏰ **予約投稿** - メッセージ自動投稿\n' +
          '👋 **入退室メッセージ** - 参加/退出を自動通知\n\n' +
          'アプリからさらに便利な機能をご利用いただけます！'
        )
        .addFields(
          { name: '📱 アプリをダウンロード', value: `[App Store で開く](${appStoreUrl})`, inline: false },
          { name: '💬 公式サポートサーバー', value: `[参加する](${discordServerUrl})`, inline: false },
          { name: '📖 ドキュメント', value: 'アプリ内で機能の使い方をご確認いただけます。', inline: false }
        )
        .setFooter({ text: 'Noxy • Discord Bot' })
        .setTimestamp();

      const dmButtons = new ActionRowBuilder<ButtonBuilder>()
        .addComponents(
          new ButtonBuilder()
            .setLabel('📱 アプリを開く')
            .setStyle(ButtonStyle.Link)
            .setURL(appStoreUrl),
          new ButtonBuilder()
            .setLabel('💬 サポートサーバー')
            .setStyle(ButtonStyle.Link)
            .setURL(discordServerUrl)
        );

      await owner.send({ embeds: [dmEmbed], components: [dmButtons] });
      console.log(`[GuildJoin] ${owner.user.tag} にDMを送信しました。`);
    } catch (e) {
      console.log(`[GuildJoin] ${owner.user.tag} へのDM送信に失敗しました（DM拒否？）:`, e);
    }
  }

  // システムチャンネルにメッセージ送信
  const systemChannel = guild.systemChannel ??
    guild.channels.cache.find(ch =>
      ch.type === ChannelType.GuildText &&
      ch.permissionsFor(guild.members.me!)?.has(['ViewChannel', 'SendMessages'])
    );

  if (systemChannel && 'send' in systemChannel) {
    try {
      const welcomeEmbed = new EmbedBuilder()
        .setColor(0x5865f2)
        .setTitle('👋 Noxy がサーバーに参加しました！')
        .setDescription(
          'こんにちは！**Noxy** です。\n\n' +
          '以下の機能がご利用いただけます：\n\n' +
          '🎫 **チケットシステム** - サポート対応を自動化\n' +
          '🛒 **ショップ機能** - 商品販売と注文管理\n' +
          '🎙️ **一時チャンネル** - VC参加で自動作成\n' +
          '📝 **リアクションロール** - 簡単ロール付与\n' +
          '⏰ **予約投稿** - メッセージ自動投稿\n' +
          '👋 **入退室メッセージ** - 参加/退出を自動通知\n\n' +
          '📱 **アプリ** からさらに簡単に設定できます！'
        )
        .addFields(
          { name: '🔧 設定方法', value: 'アプリをダウンロードして、サーバーを選択してください。', inline: false },
          { name: '💬 サポート', value: `公式サーバー: [参加する](${discordServerUrl})`, inline: false }
        )
        .setFooter({ text: 'Noxy • Discord Bot' })
        .setTimestamp();

      const welcomeButtons = new ActionRowBuilder<ButtonBuilder>()
        .addComponents(
          new ButtonBuilder()
            .setLabel('📱 アプリをダウンロード')
            .setStyle(ButtonStyle.Link)
            .setURL(appStoreUrl),
          new ButtonBuilder()
            .setLabel('💬 サポートサーバー')
            .setStyle(ButtonStyle.Link)
            .setURL(discordServerUrl)
        );

      await systemChannel.send({ embeds: [welcomeEmbed], components: [welcomeButtons] });
      console.log(`[GuildJoin] システムチャンネルにウェルカムメッセージを送信しました。`);
    } catch (e) {
      console.log('[GuildJoin] システムチャンネルへの送信に失敗しました:', e);
    }
  }
});
