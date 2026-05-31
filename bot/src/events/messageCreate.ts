import { Events, Message } from 'discord.js';
import { client } from '../client';
import { supabase } from '../db';

// 誰かがメッセージを投稿するたびに呼ばれる
// ここに「メッセージに反応する機能」を追加していく
client.on(Events.MessageCreate, async (message: Message) => {
  // Bot自身のメッセージは無視
  if (message.author.bot) return;

  // --- 動作確認用ピンポン（実装できたら削除してOK） ---
  if (message.content === '!ping') {
    await message.reply('pong 🏓');
    return;
  }

  // --- ここから実際の機能を追加していく ---
  // 例: supabase を使いたいときは下記のように
  // const { data, error } = await supabase.from('...').select('...');
});
