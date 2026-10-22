import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from '../config.js';
const keyReady = SUPABASE_PUBLISHABLE_KEY && !SUPABASE_PUBLISHABLE_KEY.includes('COLE_SUA_CHAVE');
export const supabaseConfigured = Boolean(window.supabase && keyReady && SUPABASE_URL.startsWith('https://'));
export const supabase = supabaseConfigured ? window.supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, storageKey: 'level-up-auth-v1' }
}) : null;
