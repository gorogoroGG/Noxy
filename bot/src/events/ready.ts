import { Events } from 'discord.js';
import { client } from '../client';

// Bot が Discord に接続・ログイン完了したときに1回だけ呼ばれる
client.once(Events.ClientReady, (c) => {
  console.log(`✅ ログイン完了: ${c.user.tag}`);
  console.log(`   参加サーバー数: ${c.guilds.cache.size}`);
});
