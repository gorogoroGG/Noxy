import { createClient } from '@supabase/supabase-js';

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_KEY;

if (!url || !key) {
  throw new Error('SUPABASE_URL または SUPABASE_SERVICE_KEY が未設定です');
}

export const supabase = createClient(url, key);
