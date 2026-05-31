import 'dotenv/config';
import { client } from './client';

// イベントハンドラをすべて読み込む
// 新しいイベントファイルを追加したらここに import を足す
import './events/ready';
import './events/messageCreate';
import './events/reactionAdd';
import './events/reactionRemove';
import './events/guildMemberAdd';
import './events/guildMemberRemove';
import './events/ticketInteraction';

const token = process.env.DISCORD_BOT_TOKEN;
if (!token) {
  console.error('❌ DISCORD_BOT_TOKEN が未設定です。.env を確認してください。');
  process.exit(1);
}

client.login(token);
