import 'server-only';
import { createSupabaseServerClient } from './supabase-server';
import type { CurrentStaff } from '@/types/staff';

interface StaffRow {
  id: string;
  name: string;
  role: string;
  clinic_id: string | null;
  clinics: { name: string } | null;
}

/// Reads the signed-in staff member's identity + clinic from their session
/// (see supabase/migrations/0003_clinics_and_staff.sql). Returns null if
/// nobody's logged in, Supabase isn't configured, or the session belongs to
/// someone with no staff row (e.g. a stray patient anon session). The
/// dashboard layout already redirects to /login on null; route handlers
/// that don't go through that layout (API routes aren't covered by
/// middleware's matcher) should check this themselves too.
export async function getCurrentStaff(): Promise<CurrentStaff | null> {
  const supabase = createSupabaseServerClient();
  if (!supabase) return null;

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data } = await supabase
    .from('staff')
    .select('id, name, role, clinic_id, clinics(name)')
    .eq('auth_user_id', user.id)
    .maybeSingle();

  const staffRow = data as unknown as StaffRow | null;
  if (!staffRow) return null;

  return {
    id: staffRow.id,
    name: staffRow.name,
    role: staffRow.role,
    email: user.email ?? null,
    clinicId: staffRow.clinic_id,
    clinicName: staffRow.clinics?.name ?? null,
    isSuperAdmin: staffRow.clinic_id === null,
  };
}
