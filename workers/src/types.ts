// ── Cloudflare Worker 環境変数 ─────────────────────────────────

export interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_KEY: string;
  DISCORD_BOT_TOKEN: string;
  DISCORD_CLIENT_ID: string;
  WORKER_API_SECRET: string; // #1: 認証シークレット (wrangler secret put WORKER_API_SECRET)
}

// ── Embed ─────────────────────────────────────────────────────

export interface Embed {
  id: string;
  name: string;
  message_content: string | null;
  title: string | null;
  description: string | null;
  color_hex: number;
  fields: Array<{ name: string; value: string; inline: boolean }>;
  image_url: string | null;
  thumbnail_url: string | null;
  footer_text: string | null;
  footer_icon_url: string | null;
  show_timestamp: boolean;
}

// ── Ticket ────────────────────────────────────────────────────

export interface TicketRow {
  id: string;
  guild_id: string;
  channel_id: string;
  opened_by_user_id: string;
  subject: string;
  status: string;
  priority: string;
  assigned_to_user_id: string | null;
  panel_id: string | null;
  opened_at: string;
  closed_at: string | null;
  last_message_at: string;
  message_count: number;
}

export interface TicketMessageRow {
  id: string;
  ticket_id: string;
  user_id: string;
  username: string;
  content: string;
  is_staff: boolean;
  created_at: string;
}

export function mapTicket(t: TicketRow) {
  return {
    id:               t.id,
    guildId:          t.guild_id,
    channelId:        t.channel_id,
    openedBy:         t.opened_by_user_id,
    subject:          t.subject,
    status:           t.status,
    priority:         t.priority,
    assignedToUserId: t.assigned_to_user_id ?? null,
    panelId:          t.panel_id ?? null,
    openedAt:         t.opened_at,
    closedAt:         t.closed_at ?? null,
    lastMessageAt:    t.last_message_at,
    messageCount:     t.message_count,
  };
}

export function mapTicketMessage(m: TicketMessageRow) {
  return {
    id:        m.id,
    ticketId:  m.ticket_id,
    userId:    m.user_id,
    username:  m.username,
    content:   m.content,
    isStaff:   m.is_staff,
    createdAt: m.created_at,
  };
}

export interface TicketPanelRow {
  id: string;
  guild_id: string;
  channel_id: string;
  message_id: string | null;
  title: string;
  description: string;
  color: number;
  button_label: string;
  button_emoji: string;
  support_role_id: string | null;
  open_category_id: string | null;
  closed_category_id: string | null;
  ticket_msg_content: string | null;
  ticket_embed_title: string;
  ticket_embed_color: number;
  max_open_per_user: number;
  created_at: string;
}

export function mapPanel(p: TicketPanelRow) {
  return {
    id:               p.id,
    guildId:          p.guild_id,
    channelId:        p.channel_id,
    messageId:        p.message_id ?? null,
    title:            p.title,
    description:      p.description,
    color:            p.color,
    buttonLabel:      p.button_label,
    buttonEmoji:      p.button_emoji,
    supportRoleId:    p.support_role_id ?? null,
    openCategoryId:   p.open_category_id ?? null,
    closedCategoryId: p.closed_category_id ?? null,
    ticketMsgContent: p.ticket_msg_content ?? null,
    ticketEmbedTitle: p.ticket_embed_title,
    ticketEmbedColor: p.ticket_embed_color,
    maxOpenPerUser:   p.max_open_per_user,
    createdAt:        p.created_at,
  };
}

// ── Shop / Order ──────────────────────────────────────────────

export interface ShopRow {
  id: string; guild_id: string; shop_type: string; name: string; description: string; enabled: boolean;
  disabled_message: string | null;
  channel_id: string; message_id: string | null;
  order_category_id: string | null; archive_category_id: string | null;
  support_role_id: string | null; timeout_hours: number | null;
  color: number; footer_text: string;
  review_enabled: boolean; review_channel_id: string | null;
  welcome_image_url: string | null; welcome_thumbnail_url: string | null;
  welcome_fields: Array<{name: string; value: string; inline: boolean}>;
  welcome_footer_text: string | null; welcome_footer_icon_url: string | null;
  welcome_show_timestamp: boolean;
  payment_input_label: string | null;
  auto_delete_enabled: boolean; auto_delete_days: number | null;
  created_at: string;
}

export interface ProductRow {
  id: string; shop_id: string; name: string; description: string;
  price_display: string; image_url: string | null; stock: number | null;
  reward_type: string; reward_content: string | null;
  reward_role_id: string | null; reward_dm_content: string | null;
  position: number; enabled: boolean; created_at: string;
}

export interface OrderRow {
  id: string; shop_id: string; product_id: string; guild_id: string;
  channel_id: string; buyer_user_id: string; buyer_username: string;
  product_name: string; product_price_display: string; status: string;
  buyer_confirmed: boolean; seller_confirmed: boolean;
  buyer_cancel_requested: boolean; seller_cancel_requested: boolean;
  payment_url: string | null; payment_submitted_at: string | null;
  created_at: string; paid_at: string | null; delivered_at: string | null;
  completed_at: string | null; cancelled_at: string | null;
}

export function mapShop(s: ShopRow) {
  return {
    id: s.id, guildId: s.guild_id, shopType: s.shop_type ?? 'shop',
    name: s.name, description: s.description,
    enabled: s.enabled, disabledMessage: s.disabled_message,
    channelId: s.channel_id, messageId: s.message_id,
    orderCategoryId: s.order_category_id, archiveCategoryId: s.archive_category_id,
    supportRoleId: s.support_role_id, timeoutHours: s.timeout_hours,
    color: s.color, footerText: s.footer_text,
    reviewEnabled: s.review_enabled ?? false, reviewChannelId: s.review_channel_id ?? null,
    welcomeImageUrl: s.welcome_image_url, welcomeThumbnailUrl: s.welcome_thumbnail_url,
    welcomeFields: s.welcome_fields ?? [],
    welcomeFooterText: s.welcome_footer_text, welcomeFooterIconUrl: s.welcome_footer_icon_url,
    welcomeShowTimestamp: s.welcome_show_timestamp,
    paymentInputLabel: s.payment_input_label ?? null,
    autoDeleteEnabled: s.auto_delete_enabled ?? false, autoDeleteDays: s.auto_delete_days ?? null,
    createdAt: s.created_at,
  };
}

export function mapProduct(p: ProductRow) {
  return {
    id: p.id, shopId: p.shop_id, name: p.name, description: p.description,
    priceDisplay: p.price_display, imageUrl: p.image_url, stock: p.stock,
    rewardType: p.reward_type, rewardContent: p.reward_content,
    rewardRoleId: p.reward_role_id, rewardDmContent: p.reward_dm_content,
    position: p.position, enabled: p.enabled, createdAt: p.created_at,
  };
}

export function mapOrder(o: OrderRow) {
  return {
    id: o.id, shopId: o.shop_id, productId: o.product_id,
    guildId: o.guild_id, channelId: o.channel_id,
    buyerUserId: o.buyer_user_id, buyerUsername: o.buyer_username,
    productName: o.product_name, productPriceDisplay: o.product_price_display,
    status: o.status, buyerConfirmed: o.buyer_confirmed, sellerConfirmed: o.seller_confirmed,
    buyerCancelRequested: o.buyer_cancel_requested, sellerCancelRequested: o.seller_cancel_requested,
    paymentUrl: o.payment_url, paymentSubmittedAt: o.payment_submitted_at,
    createdAt: o.created_at, paidAt: o.paid_at, deliveredAt: o.delivered_at,
    completedAt: o.completed_at, cancelledAt: o.cancelled_at,
  };
}

// ── AutoResponse ──────────────────────────────────────────────

export interface AutoResponseRow {
  id: string;
  guild_id: string;
  trigger_type: string;
  trigger: string;
  response: string;
  is_enabled: boolean;
  cooldown_sec: number;
  channel_ids: string[];
  created_at: string;
}

export const triggerTypeToDB: Record<string, string> = {
  contains:   'contains',
  exact:      'exact',
  regex:      'regex',
  startsWith: 'starts_with',
  endsWith:   'ends_with',
};

const triggerTypeToiOS: Record<string, string> = {
  contains:    'contains',
  exact:       'exact',
  regex:       'regex',
  starts_with: 'startsWith',
  ends_with:   'contains',
};

export function mapAutoResponse(r: AutoResponseRow) {
  return {
    id:              r.id,
    guildId:         r.guild_id,
    trigger:         r.trigger,
    response:        r.response,
    matchType:       triggerTypeToiOS[r.trigger_type] ?? 'contains',
    enabled:         r.is_enabled,
    cooldownSeconds: r.cooldown_sec,
    channelIds:      r.channel_ids ?? [],
  };
}

// ── StatChannel ───────────────────────────────────────────────

export type StatType = 'members' | 'online' | 'boosts' | 'vc_users';

export interface StatChannelRow {
  id: string;
  guild_id: string;
  channel_id: string;
  stat_type: StatType;
  is_enabled: boolean;
  last_value: number;
  last_updated_at: string | null;
  created_at: string;
}

export function mapStatChannel(r: StatChannelRow) {
  return {
    id:            r.id,
    guildId:       r.guild_id,
    channelId:     r.channel_id,
    statType:      r.stat_type,
    isEnabled:     r.is_enabled,
    lastValue:     r.last_value,
    lastUpdatedAt: r.last_updated_at ?? null,
  };
}

export function statChannelLabel(type: StatType, value: number): string {
  switch (type) {
    case 'members':  return `👥 メンバー: ${value.toLocaleString('ja-JP')}`;
    case 'online':   return `🟢 オンライン: ${value.toLocaleString('ja-JP')}`;
    case 'boosts':   return `🚀 Boost: ${value}`;
    case 'vc_users': return `🎙️ VC中: ${value}人`;
  }
}
