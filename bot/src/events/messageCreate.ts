import { Events, type Message } from 'discord.js';
import { client } from '../client.js';
import { supabase } from '../db.js';

client.on(Events.MessageCreate, async (message: Message) => {
  if (message.author.bot) return;
  if (!message.guildId)   return;

  // --- 動作確認用ピンポン ---
  if (message.content === '!ping') {
    await message.reply('pong 🏓');
    return;
  }

  // --- チケットチャンネルへの返信を Supabase に記録 ---
  const { data: ticket } = await supabase
    .from('tickets')
    .select('id, status')
    .eq('channel_id', message.channelId)
    .single();

  if (ticket && ticket.status !== 'closed') {
    await supabase.from('ticket_messages').insert({
      ticket_id: ticket.id,
      user_id:   message.author.id,
      username:  message.author.username,
      content:   message.content || '[添付ファイル]',
      is_staff:  false,
    });
    await supabase.from('tickets').update({
      last_message_at: new Date().toISOString(),
    }).eq('id', ticket.id);
    // message_count は DB 側で increment できないため +1 は個別取得後に更新
    const { data: current } = await supabase.from('tickets').select('message_count').eq('id', ticket.id).single();
    if (current) {
      await supabase.from('tickets').update({ message_count: current.message_count + 1 }).eq('id', ticket.id);
    }
  }
});
