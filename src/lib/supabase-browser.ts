'use client';

import { createBrowserClient } from '@supabase/ssr';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export const isSupabaseBrowserConfigured = Boolean(supabaseUrl && anonKey);

/// Browser-side Supabase client for client components (the login form,
/// the Sidebar's sign-out button) — reads/writes the same auth cookie
/// the middleware and server client use, via @supabase/ssr.
export function createSupabaseBrowserClient() {
  if (!isSupabaseBrowserConfigured) return null;
  return createBrowserClient(supabaseUrl!, anonKey!);
}
