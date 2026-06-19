import { Events, EmbedBuilder, ActionRowBuilder, ButtonBuilder, ButtonStyle } from 'discord.js';
import { client } from '../client';
import { supabase } from '../db';

client.on(Events.GuildDelete, async (guild) => {
  console.log(`[GuildDelete] ${guild.name} (${guild.id}) から退出/削除されました`);

  try {
    // 削除されたサーバーを記録
    await supabase.from('deleted_guilds').upsert({
      guild_id: guild.id,
      owner_id: guild.ownerId,
      guild_name: guild.name,
      deleted_at: new Date().toISOString(),
      notified: false,
    }, { onConflict: 'guild_id' });

    // オーナーにDMで復旧案内
    if (guild.ownerId) {
      try {
        const owner = await client.users.fetch(guild.ownerId);
        const appStoreUrl = process.env.APP_STORE_URL || 'https://apps.apple.com/app/your-app';

        const embed = new EmbedBuilder()
          .setColor(0xef4444)
          .setTitle('🚨 サーバーが削除されました')
          .setDescription(
            `**${guild.name}** が削除されたか、Noxyがサーバーから削除されました。\n\n` +
            'サーバー復旧機能を使うと、OAuth2認証済みのメンバーを新しいサーバーに自動参加させることができます。'
          )
          .addFields(
            { name: '📱 復旧方法', value: 'Noxyアプリを開き、「サーバー復旧」から復旧先のサーバーを選択してください。', inline: false },
            { name: '⚠️ 注意', value: '自動参加できるのは、OAuth2認証を済ませたメンバーのみです。', inline: false }
          )
          .setFooter({ text: 'Noxy • 災害復旧' })
          .setTimestamp();

        const buttons = new ActionRowBuilder<ButtonBuilder>()
          .addComponents(
            new ButtonBuilder()
              .setLabel('📱 アプリを開く')
              .setStyle(ButtonStyle.Link)
              .setURL(appStoreUrl)
          );

        await owner.send({ embeds: [embed], components: [buttons] });

        // 通知済みに更新
        await supabase.from('deleted_guilds')
          .update({ notified: true })
          .eq('guild_id', guild.id);

        console.log(`[GuildDelete] オーナー ${owner.tag} に復旧案内DMを送信しました`);
      } catch (dmErr) {
        console.log('[GuildDelete] オーナーへのDM送信に失敗しました:', dmErr);
      }
    }
  } catch (e) {
    console.error('[GuildDelete] 削除記録に失敗しました:', e);
  }
});
