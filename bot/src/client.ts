import { Client, GatewayIntentBits, Partials } from 'discord.js';

// 受け取りたいイベントの種類をここで宣言する
// 機能を増やすときは Intents と Partials を追加する
export const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
    GatewayIntentBits.GuildMembers,
  ],
  partials: [Partials.Message, Partials.Channel],
});
