import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string;
const serviceRoleKey = import.meta.env.VITE_SUPABASE_SERVICE_ROLE_KEY as string | undefined;

if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error('Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY env vars');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export const isDevMode = !!serviceRoleKey;

export const supabaseAdmin = serviceRoleKey
    ? createClient(supabaseUrl, serviceRoleKey)
    : null;