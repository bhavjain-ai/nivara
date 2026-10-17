import 'server-only';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

// Service-role client — bypasses Row Level Security entirely. Import this
// ONLY from server-side code (route handlers, server components), never
// from anything that ships to the browser. The `server-only` import above
// makes Next.js throw a build error if a client component ever imports this
// file by mistake.
//
// Use this for actions a patient's own anon session isn't allowed to do —
// e.g. inserting a care-team-authored chat message (RLS only lets a patient
// insert messages with sender_type = 'patient'; a coordinator's reply has to
// come from a trusted path like this one instead) — and for admin-style
// reads across all patients (e.g. the live-sync dashboard feed in
// src/lib/supabase-live.ts), which no single patient's RLS-scoped session
// could ever see in one query.
//
// `supabaseAdmin` is null (not a thrown error) when
// NEXT_PUBLIC_SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY aren't set — every
// caller must handle that and fall back to mock/local data, the same way
// the iOS app's SupabaseService.client does when SupabaseConfig isn't
// filled in. A fresh checkout with no Supabase project configured should
// still be able to run `npm run dev` and see the dashboard on mock data,
// not crash at import time.
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

export const isSupabaseAdminConfigured = Boolean(supabaseUrl && serviceRoleKey);

// TEMPORARY diagnostic — remove once the live-sync bug is found. Masks the
// key (only prints its length and last 6 chars) so nothing secret lands in
// server logs; lets us compare against the known-good key used in manual
// curl tests without ever printing the real value.
console.log(
  `[supabase-admin] url=${supabaseUrl ?? 'undefined'} keyLen=${serviceRoleKey?.length ?? 0} keyTail=${serviceRoleKey?.slice(-6) ?? 'n/a'}`
);

export const supabaseAdmin: SupabaseClient | null = isSupabaseAdminConfigured
  ? createClient(supabaseUrl!, serviceRoleKey!, {
      auth: { autoRefreshToken: false, persistSession: false },
    })
  : null;
