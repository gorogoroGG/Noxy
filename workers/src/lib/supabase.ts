import type { Env } from '../types.js';

// ── env 経由の Supabase クライアント（HTTP ルートハンドラ用）────

export function makeSupabaseFetch(env: Env) {
  return (path: string, options?: RequestInit): Promise<Response> => {
    const baseUrl = env.SUPABASE_URL.replace(/\/$/, '');
    const url = `${baseUrl}/rest/v1${path}`;
    return fetch(url, {
      ...options,
      headers: {
        apikey:          env.SUPABASE_SERVICE_KEY,
        Authorization:   `Bearer ${env.SUPABASE_SERVICE_KEY}`,
        'Content-Type':  'application/json',
        Prefer:          'return=representation',
        ...(options?.headers ?? {}),
      },
    });
  };
}
