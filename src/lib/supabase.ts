import { createClient, SupabaseClient } from '@supabase/supabase-js';

// Both values come from Project Settings → API in the Supabase dashboard.
// NEXT_PUBLIC_* env vars are safe to expose to the browser — the anon key is
// meant to be public and relies on the Row Level Security policies in
// supabase/migrations/0001_init.sql to restrict what it can actually read or
// write. Never put the service role key in a NEXT_PUBLIC_* var; it bypasses
// RLS entirely and must only be used from trusted server-side code (e.g. a
// route handler that inserts care-team-authored chat messages).
//
// `supabase` is null (not a thrown error) when NEXT_PUBLIC_SUPABASE_URL/
// NEXT_PUBLIC_SUPABASE_ANON_KEY aren't set — the dashboard's main pages run
// on bundled mock data (src/lib/mock-data.ts) and don't need this at all;
// only the live-sync features actually touch Supabase, and they're expected
// to no-op gracefully without it (matching the iOS app's
// SupabaseConfig.isConfigured pattern). A missing/half-set pair is treated
// the same as "not configured," not a broken config.
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);

export const supabase: SupabaseClient | null = isSupabaseConfigured
  ? createClient(supabaseUrl!, supabaseAnonKey!)
  : null;
