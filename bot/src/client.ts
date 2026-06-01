import { Client, GatewayIntentBits, Partials } from 'discord.js';

// 受け取りたいイベントの種類をここで宣言する
// 機能を増やすときは Intents と Partials を追加する
export const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
    GatewayIntentBits.GuildMembers,
    GatewayIntentBits.GuildMessageReactions, // リアクションロールに必要
    GatewayIntentBits.GuildMembers,          // 入退室イベントに必要（Privileged Intent）
    GatewayIntentBits.GuildVoiceStates,      // 一時チャンネル：VC参加/退出検知に必要
  ],
  partials: [Partials.Message, Partials.Channel, Partials.Reaction], // 古いメッセージへの対応
});
