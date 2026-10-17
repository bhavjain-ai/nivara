import 'server-only';
import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { cookies } from 'next/headers';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export const isSupabaseSsrConfigured = Boolean(supabaseUrl && anonKey);

/// Session-scoped Supabase client for Server Components and Route Handlers.
/// Reads the signed-in staff member's auth cookie, so every query runs AS
/// that person — Row Level Security (supabase/migrations/0003_clinics_and_staff.sql)
/// then naturally scopes results to their own clinic (or every clinic, for
/// a super-admin whose staff row has clinic_id = null).
///
/// Use this, never supabase-admin.ts's service-role client, anywhere clinic
/// isolation matters — the service-role client bypasses RLS entirely and
/// would leak every clinic's patients to whoever happens to be logged in.
/// supabase-admin.ts still exists for the few genuinely cross-clinic-trusted
/// writes (e.g. inserting a care-team chat reply as a role no patient has).
export function createSupabaseServerClient() {
  if (!isSupabaseSsrConfigured) return null;
  const cookieStore = cookies();

  return createServerClient(supabaseUrl!, anonKey!, {
    cookies: {
      get(name: string) {
        return cookieStore.get(name)?.value;
      },
      set(name: string, value: string, options: CookieOptions) {
        try {
          cookieStore.set({ name, value, ...options });
        } catch {
          // Called from a Server Component, which can't set cookies —
          // middleware refreshes the session on navigation instead.
        }
      },
      remove(name: string, options: CookieOptions) {
        try {
          cookieStore.set({ name, value: '', ...options });
        } catch {
          // Same as above.
        }
      },
    },
  });
}
