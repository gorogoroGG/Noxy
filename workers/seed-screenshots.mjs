// ────────────────────────────────────────────────────────────────
// App Store スクリーンショット用 シードスクリプト
//
//   対象 Discord サーバー: 1515731172205002893
//
// 使い方:
//   1. workers/.dev.vars に以下を設定:
//        SUPABASE_URL=https://byvwidopvpedslzwuksq.supabase.co
//        SUPABASE_SERVICE_KEY=<service_role キー>
//        DISCORD_BOT_TOKEN=<Bot トークン>   （実チャンネル/ロール解決・任意）
//   2. cd workers && node seed-screenshots.mjs
//
// Node 18+（global fetch 使用、依存パッケージ不要）
// ────────────────────────────────────────────────────────────────

import { readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';

const GUILD_ID = '1515731172205002893';

// ── .dev.vars 読み込み ───────────────────────────────────────────
function loadEnv() {
  const env = {};
  try {
    const raw = readFileSync(new URL('./.dev.vars', import.meta.url), 'utf8');
    for (const line of raw.split('\n')) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
      if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
    }
  } catch (e) {
    console.error('❌ workers/.dev.vars が読み込めません:', e.message);
    process.exit(1);
  }
  return env;
}

const env = loadEnv();
const SUPABASE_URL = env.SUPABASE_URL || 'https://byvwidopvpedslzwuksq.supabase.co';
const KEY = env.SUPABASE_SERVICE_KEY;
const BOT = env.DISCORD_BOT_TOKEN;

if (!KEY) {
  console.error('❌ SUPABASE_SERVICE_KEY が .dev.vars にありません（service_role キーが必要）');
  process.exit(1);
}

// ── Supabase PostgREST ヘルパ ────────────────────────────────────
async function sb(path, { method = 'GET', body, prefer } = {}) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1${path}`, {
    method,
    headers: {
      apikey: KEY,
      Authorization: `Bearer ${KEY}`,
      'Content-Type': 'application/json',
      Prefer: prefer || 'return=representation',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json; try { json = text ? JSON.parse(text) : null; } catch { json = text; }
  return { ok: res.ok, status: res.status, json };
}

// INSERT（失敗時に minimal で再試行）。成功した行を返す。
async function insert(table, full, minimal) {
  let r = await sb(`/${table}`, { method: 'POST', body: full });
  if (!r.ok && r.status === 400 && minimal) {
    console.warn(`   ⚠️  ${table}: フル投入失敗 → 最小カラムで再試行 (${JSON.stringify(r.json).slice(0, 120)})`);
    r = await sb(`/${table}`, { method: 'POST', body: minimal });
  }
  if (!r.ok) {
    console.error(`   ❌ ${table} 失敗 [${r.status}]: ${JSON.stringify(r.json).slice(0, 200)}`);
    return null;
  }
  return Array.isArray(r.json) ? r.json[0] : r.json;
}

// ── Discord API（任意：実チャンネル/ロール解決）──────────────────
async function discord(path) {
  if (!BOT) return null;
  try {
    const res = await fetch(`https://discord.com/api/v10${path}`, {
      headers: { Authorization: `Bot ${BOT}` },
    });
    if (!res.ok) { console.warn(`   ⚠️  Discord ${path} → ${res.status}`); return null; }
    return await res.json();
  } catch (e) { console.warn(`   ⚠️  Discord ${path} 例外: ${e.message}`); return null; }
}

const PH = '000000000000000000'; // プレースホルダ ID（Discord 解決できないとき）

async function main() {
  console.log(`\n🌱 シード開始: guild=${GUILD_ID}\n`);

  // ── Discord からチャンネル/ロールを取得（あれば名前がきれいに出る）──
  const guild    = await discord(`/guilds/${GUILD_ID}`);
  const channels = (await discord(`/guilds/${GUILD_ID}/channels`)) || [];
  const roles    = (await discord(`/guilds/${GUILD_ID}/roles`)) || [];

  const textChs  = channels.filter(c => c.type === 0);
  const voiceChs = channels.filter(c => c.type === 2);
  const cats     = channels.filter(c => c.type === 4);
  const pickRole = roles.filter(r => r.name !== '@everyone' && !r.managed);

  const textCh   = textChs[0]?.id  ?? PH;
  const textCh2  = textChs[1]?.id  ?? textCh;
  const vc1      = voiceChs[0]?.id ?? PH;
  const vc2      = voiceChs[1]?.id ?? vc1;
  const vc3      = voiceChs[2]?.id ?? vc1;
  const cat      = cats[0]?.id     ?? null;
  const role1    = pickRole[0]?.id ?? PH;
  const role1Nm  = pickRole[0]?.name ?? 'VIP';
  const ownerId  = guild?.owner_id ?? null;

  if (guild) console.log(`   📡 Discord: "${guild.name}" / text=${textChs.length} voice=${voiceChs.length} roles=${pickRole.length} owner=${ownerId}`);
  else       console.log(`   ⚠️  Discord 未取得（BOT トークン無し or 権限不足）→ プレースホルダ ID を使用`);

  const iso = (d = new Date()) => d.toISOString();
  const daysAgo = n => iso(new Date(Date.now() - n * 86400000));

  // ── 1. ショップ + 商品 + 注文 ─────────────────────────────────
  console.log('🛒 shops / products / orders');
  const shop1 = await insert('shops', {
    guild_id: GUILD_ID, shop_type: 'shop', name: '🎭 ロールショップ',
    description: '特別ロールを購入して限定チャンネルにアクセス！', enabled: true,
    channel_id: textCh, color: 0x5865F2, footer_text: 'Noxy Shop',
    welcome_fields: [], welcome_show_timestamp: true,
  }, { guild_id: GUILD_ID, name: '🎭 ロールショップ', description: '特別ロールを購入', channel_id: textCh, color: 0x5865F2 });

  const shop2 = await insert('shops', {
    guild_id: GUILD_ID, shop_type: 'shop', name: '💎 プレミアム特典',
    description: 'サーバーブースト特典・限定アイテムはこちら', enabled: true,
    channel_id: textCh2, color: 0xEB459E, footer_text: 'Premium',
    welcome_fields: [], welcome_show_timestamp: true,
  }, { guild_id: GUILD_ID, name: '💎 プレミアム特典', description: '限定アイテム', channel_id: textCh2, color: 0xEB459E });

  const products = [];
  if (shop1) {
    products.push(await insert('products', { shop_id: shop1.id, name: '👑 VIPロール', description: '限定チャンネル＋特別カラー', price_display: '¥500', reward_type: 'role', reward_role_id: role1, position: 0, enabled: true }));
    products.push(await insert('products', { shop_id: shop1.id, name: '🌟 サポーター', description: '運営を応援！名前が光ります', price_display: '¥1,000', reward_type: 'role', reward_role_id: role1, position: 1, enabled: true }));
    products.push(await insert('products', { shop_id: shop1.id, name: '🎨 カスタムカラー', description: '好きな色を選べます', price_display: '¥800', stock: 10, reward_type: 'text', position: 2, enabled: true }));
  }
  if (shop2) {
    products.push(await insert('products', { shop_id: shop2.id, name: '✨ 限定スタンプセット', description: 'オリジナル絵文字10種', price_display: '¥300', reward_type: 'text', position: 0, enabled: true }));
    products.push(await insert('products', { shop_id: shop2.id, name: '💎 プレミアム会員(30日)', description: '全特典が使い放題', price_display: '¥1,500', reward_type: 'text', position: 1, enabled: true }));
  }
  const P = products.filter(Boolean);

  // 注文（ステータス様々）
  const orderSeed = [
    { p: P[0], status: 'completed', buyer: 'たなか', uid: '201000000000000001', d: 5, bc: true, sc: true, completed: true },
    { p: P[1], status: 'delivered', buyer: 'さとう', uid: '201000000000000002', d: 2, paid: true, delivered: true },
    { p: P[3], status: 'open',      buyer: 'すずき', uid: '201000000000000003', d: 0 },
    { p: P[4], status: 'open',      buyer: 'やまだ', uid: '201000000000000004', d: 0 },
    { p: P[2], status: 'cancelled', buyer: 'いとう', uid: '201000000000000005', d: 7, cancelled: true },
  ];
  for (const o of orderSeed) {
    if (!o.p) continue;
    const now = daysAgo(o.d);
    await insert('orders', {
      shop_id: o.p.shop_id, product_id: o.p.id, guild_id: GUILD_ID, channel_id: textCh,
      buyer_user_id: o.uid, buyer_username: o.buyer,
      product_name: o.p.name, product_price_display: o.p.price_display,
      status: o.status,
      buyer_confirmed: !!o.bc, seller_confirmed: !!o.sc,
      buyer_cancel_requested: false, seller_cancel_requested: false,
      created_at: now,
      paid_at: o.paid ? now : null, delivered_at: o.delivered ? now : null,
      completed_at: o.completed ? now : null, cancelled_at: o.cancelled ? now : null,
    }, {
      shop_id: o.p.shop_id, product_id: o.p.id, guild_id: GUILD_ID, channel_id: textCh,
      buyer_user_id: o.uid, buyer_username: o.buyer,
      product_name: o.p.name, product_price_display: o.p.price_display, status: o.status,
    });
  }

  // ── 2. チケットパネル + チケット + メッセージ ───────────────────
  console.log('🎫 ticket_panels / tickets / ticket_messages');
  await insert('ticket_panels', {
    guild_id: GUILD_ID, channel_id: textCh, title: '🎫 サポートデスク',
    description: 'お困りごとや質問はこちらのボタンからお気軽にどうぞ！', color: 0x6366f1,
    button_label: '問い合わせる', button_emoji: '🎫', support_role_id: role1,
    ticket_embed_title: 'サポートチケット', ticket_embed_color: 0x6366f1, max_open_per_user: 1,
  }, { guild_id: GUILD_ID, channel_id: textCh, title: '🎫 サポートデスク', description: 'お問い合わせはこちら', button_label: '問い合わせる', button_emoji: '🎫' });

  const ticketSeed = [
    { subject: '購入した商品が届きません', status: 'open',   priority: 'high',   uid: '201000000000000001', d: 0, msgs: [['たなか', '昨日ロールを購入しましたがまだ付与されていません', false], ['運営チーム', 'ご確認します。少々お待ちください！', true]] },
    { subject: '退会の方法を教えてください', status: 'open',   priority: 'normal', uid: '201000000000000004', d: 1, msgs: [['やまだ', 'サブスクの解約方法が分かりません', false]] },
    { subject: 'コラボのご相談',           status: 'closed', priority: 'low',    uid: '201000000000000002', d: 3, msgs: [['さとう', 'イベントコラボのご相談です', false], ['運営チーム', 'ありがとうございます！DMしますね', true]] },
  ];
  for (const t of ticketSeed) {
    const tk = await insert('tickets', {
      guild_id: GUILD_ID, channel_id: textCh, opened_by_user_id: t.uid, subject: t.subject,
      status: t.status, priority: t.priority, message_count: t.msgs.length,
      opened_at: daysAgo(t.d), last_message_at: daysAgo(t.d),
    }, { guild_id: GUILD_ID, channel_id: textCh, opened_by_user_id: t.uid, subject: t.subject });
    if (tk) {
      for (const [uname, content, staff] of t.msgs) {
        await insert('ticket_messages', {
          ticket_id: tk.id, user_id: staff ? PH : t.uid, username: uname,
          content, is_staff: staff, created_at: daysAgo(t.d),
        });
      }
    }
  }

  // ── 3. 認証パネル + 認証申請 ───────────────────────────────────
  console.log('✅ verify_panels / verify_requests');
  const vpanel = await insert('verify_panels', {
    guild_id: GUILD_ID, name: '✅ メンバー認証', description: '下のボタンを押して認証を完了するとサーバーに参加できます。',
    channel_id: textCh, role_id: role1, color: 0x10b981, footer_text: 'Noxy Verify',
    button_label: '✅ 認証する', enabled: true, verify_type: 'manual', reaction_emoji: '✅', manual_channel_id: textCh2,
  }, { guild_id: GUILD_ID, name: '✅ メンバー認証', description: '認証してください', channel_id: textCh, role_id: role1, button_label: '✅ 認証する' });

  const reqUsers = [['みなみ', '202000000000000001'], ['きむら', '202000000000000002'], ['なかむら', '202000000000000003']];
  for (const [uname, uid] of reqUsers) {
    await insert('verify_requests', {
      panel_id: vpanel?.id ?? null, guild_id: GUILD_ID, user_id: uid, username: uname,
      avatar_url: null, status: 'pending', created_at: daysAgo(0),
    }, { guild_id: GUILD_ID, user_id: uid, username: uname, status: 'pending' });
  }

  // ── 4. 自動応答 ───────────────────────────────────────────────
  console.log('💬 auto_responses');
  const autoSeed = [
    { type: 'contains', trig: '料金',  resp: '料金プランは <#' + textCh + '> のショップをご確認ください！' },
    { type: 'contains', trig: '招待',  resp: '招待リンクはこちら → discord.gg/noxy' },
    { type: 'exact',    trig: 'ping',  resp: 'pong! 🏓' },
    { type: 'contains', trig: 'ルール', resp: 'サーバールールは <#' + textCh + '> をご確認ください📜' },
  ];
  for (const a of autoSeed) {
    await insert('auto_responses', {
      guild_id: GUILD_ID, trigger_type: a.type, trigger: a.trig, response: a.resp,
      is_enabled: true, cooldown_sec: 5, channel_ids: [],
    }, { guild_id: GUILD_ID, trigger_type: a.type, trigger: a.trig, response: a.resp });
  }

  // ── 5. 統計チャンネル ─────────────────────────────────────────
  console.log('📊 stat_channels');
  const statSeed = [
    { ch: vc1, type: 'members', val: 1248 },
    { ch: vc2, type: 'online',  val: 93 },
    { ch: vc3, type: 'boosts',  val: 14 },
  ];
  for (const s of statSeed) {
    await insert('stat_channels', {
      guild_id: GUILD_ID, channel_id: s.ch, stat_type: s.type, is_enabled: true, last_value: s.val,
    }, { guild_id: GUILD_ID, channel_id: s.ch, stat_type: s.type, is_enabled: true, last_value: s.val });
  }

  // ── 6. 一時VC ─────────────────────────────────────────────────
  console.log('🔊 temp_vc_sources / temp_channel_settings');
  await insert('temp_vc_sources', {
    guild_id: GUILD_ID, trigger_vc_id: vc1, trigger_vc_name: '🔊 VCを作成',
    vc_category_id: cat ?? PH, text_channel_category_id: cat ?? PH,
    vc_name_format: '{user-name}のVC', channel_name_format: '{user-name}の部屋',
    user_limit: 0, auto_delete: true, delete_delay_minutes: 0,
    join_leave_notification: true, enabled: true, waiting_room_enabled: false,
  }, { guild_id: GUILD_ID, trigger_vc_name: '🔊 VCを作成', vc_category_id: cat ?? PH, text_channel_category_id: cat ?? PH });

  await insert('temp_channel_settings', {
    guild_id: GUILD_ID, enabled: true, category_id: cat,
    channel_name_format: '💬-{vc-name}', auto_delete: true, delete_delay_minutes: 0,
    join_leave_notification: true, watch_all_vcs: true, watch_vc_ids: [], min_members: 1,
    updated_at: iso(),
  }, { guild_id: GUILD_ID, enabled: true, channel_name_format: '💬-{vc-name}' });

  // ── 7. モデレーション警告 ─────────────────────────────────────
  console.log('⚠️  mod_warnings');
  const warnSeed = [
    { uid: '203000000000000001', uname: 'spammer01', disp: 'スパム太郎',  reason: '宣伝スパムの繰り返し' },
    { uid: '203000000000000002', uname: 'troll_02',  disp: '荒らし花子',  reason: '禁止ワードの使用' },
    { uid: '203000000000000003', uname: 'newbie_03', disp: 'うっかり君',  reason: 'チャンネル違いの投稿（軽微）' },
  ];
  for (const w of warnSeed) {
    await insert('mod_warnings', {
      guild_id: GUILD_ID, user_id: w.uid, username: w.uname, display_name: w.disp,
      reason: w.reason, staff_id: ownerId ?? PH, staff_name: '運営チーム', is_revoked: false,
      created_at: daysAgo(Math.floor(Math.random() * 10)),
    }, { guild_id: GUILD_ID, user_id: w.uid, username: w.uname, display_name: w.disp, reason: w.reason, staff_id: ownerId ?? PH, staff_name: '運営チーム' });
  }

  // ── 8. 埋め込み ───────────────────────────────────────────────
  console.log('📋 embeds');
  await insert('embeds', {
    id: randomUUID(), name: '📜 サーバールール', guild_id: GUILD_ID,
    title: '📜 サーバールール', description: '楽しく過ごすためのルールです。必ずお読みください。',
    color_hex: 0x5865F2,
    fields: [
      { name: '1. 礼儀を守る', value: '誹謗中傷・差別的発言は禁止です', inline: false },
      { name: '2. スパム禁止', value: '宣伝・連投はお控えください', inline: false },
      { name: '3. 楽しむ', value: 'みんなで楽しいコミュニティを作りましょう！', inline: false },
    ],
    footer_text: 'Noxy Community', show_timestamp: true,
    created_at: iso(), updated_at: iso(),
  });
  await insert('embeds', {
    id: randomUUID(), name: '🎉 イベント告知', guild_id: GUILD_ID,
    title: '🎉 週末ゲームナイト開催！', description: '今週末20時からVCでゲーム大会を開催します。景品もあります🎁',
    color_hex: 0xEB459E, fields: [], footer_text: 'お楽しみに！', show_timestamp: true,
    created_at: iso(), updated_at: iso(),
  });

  // ── 9. ようこそ / 退室メッセージ ───────────────────────────────
  console.log('👋 greeting_settings');
  const greetExisting = await sb(`/greeting_settings?guild_id=eq.${GUILD_ID}&select=guild_id`);
  const greetBody = {
    guild_id: GUILD_ID,
    welcome_enabled: true, welcome_channel_id: textCh, welcome_channel_name: '#welcome',
    welcome_message: '{user.mention} が {server.name} に参加しました！🎉 メンバー数: {member.count}人',
    welcome_dm_enabled: true, welcome_dm_message: '{server.name} へようこそ！ルールを確認してお楽しみください。',
    welcome_role_enabled: true, welcome_role_id: role1, welcome_role_name: role1Nm,
    goodbye_enabled: true, goodbye_channel_id: textCh, goodbye_channel_name: '#general',
    goodbye_message: '{user.name} が退室しました。👋 また会えますように。',
    goodbye_dm_enabled: false, goodbye_dm_message: '',
  };
  if (Array.isArray(greetExisting.json) && greetExisting.json.length > 0) {
    const r = await sb(`/greeting_settings?guild_id=eq.${GUILD_ID}`, { method: 'PATCH', body: greetBody });
    console.log(r.ok ? '   ✅ greeting_settings 更新' : `   ❌ greeting_settings [${r.status}] ${JSON.stringify(r.json).slice(0,150)}`);
  } else {
    await insert('greeting_settings', greetBody, { guild_id: GUILD_ID, welcome_enabled: true, welcome_channel_id: textCh, welcome_message: greetBody.welcome_message });
  }

  // ── 10. リアクションロール（スキーマ不確実 → ベストエフォート）──
  console.log('🎭 reaction_roles (best-effort)');
  await insert('reaction_roles', {
    guild_id: GUILD_ID, channel_id: textCh, message_id: PH,
    emoji: '🔔', role_id: role1, role_name: role1Nm,
    created_at: iso(),
  });

  // ── 注: プレミアム有効化（課金ゲート解除）は本スクリプトに含めません ──
  // user_profiles / activated_servers の付与は権限昇格にあたるため、
  // 必要な場合はアプリ内の Debug 設定（/billing/debug-setup）から有効化するか、
  // 明示的に指示してください。

  console.log('\n✅ シード完了\n');
}

main().catch(e => { console.error('FATAL', e); process.exit(1); });
