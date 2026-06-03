import type { Env } from '../types.js';

// ── CORS ヘッダー (#10) ───────────────────────────────────────

export const corsHeaders: HeadersInit = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Bot-Secret, Authorization',
  'Access-Control-Max-Age':       '86400',
};

export function corsResponse(body: BodyInit | null, init: ResponseInit = {}): Response {
  return new Response(body, {
    ...init,
    headers: { ...corsHeaders, ...(init.headers ?? {}) },
  });
}

export function jsonResponse(data: unknown, status = 200): Response {
  return corsResponse(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

export function errorResponse(message: string, status = 400): Response {
  return jsonResponse({ error: message }, status);
}

// ── 認証チェック (#1) ────────────────────────────────────────
// X-Bot-Secret ヘッダーと環境変数 WORKER_API_SECRET を照合する
// WORKER_API_SECRET が未設定の場合は開発環境とみなし通過させる

export function checkAuth(request: Request, env: Env): boolean {
  if (!env.WORKER_API_SECRET) return true; // 未設定 = ローカル開発
  const secret = request.headers.get('X-Bot-Secret');
  return secret === env.WORKER_API_SECRET;
}
