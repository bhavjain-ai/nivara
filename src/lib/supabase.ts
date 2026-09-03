import { createClient } from '@supabase/supabase-js';

// Both values come from Project Settings → API in the Supabase dashboard.
// NEXT_PUBLIC_* env vars are safe to expose to the browser — the anon key is
// meant to be public and relies on the Row Level Security policies in
// supabase/migrations/0001_init.sql to restrict what it can actually read or
// write. Never put the service role key in a NEXT_PUBLIC_* var; it bypasses
// RLS entirely and must only be used from trusted server-side code (e.g. a
// route handler that inserts care-team-authored chat messages).
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error(
    'Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_ANON_KEY — copy .env.local.example to .env.local and fill in your Supabase project values.'
  );
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
