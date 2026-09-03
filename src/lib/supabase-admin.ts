import 'server-only';
import { createClient } from '@supabase/supabase-js';

// Service-role client — bypasses Row Level Security entirely. Import this
// ONLY from server-side code (route handlers, server components), never
// from anything that ships to the browser. The `server-only` import above
// makes Next.js throw a build error if a client component ever imports this
// file by mistake.
//
// Use this for actions a patient's own anon session isn't allowed to do —
// e.g. inserting a care-team-authored chat message (RLS only lets a patient
// insert messages with sender_type = 'patient'; a coordinator's reply has to
// come from a trusted path like this one instead).
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error(
    'Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY — copy .env.local.example to .env.local and fill in your Supabase project values.'
  );
}

export const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});
