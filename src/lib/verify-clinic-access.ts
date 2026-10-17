import { createSupabaseServerClient } from './supabase-server';

/// Confirms the logged-in staff member (from their session cookie) can see
/// this patient — i.e. the patient is in their clinic, or they're a
/// super-admin. Relies on RLS (supabase/migrations/0003_clinics_and_staff.sql)
/// rather than comparing clinic_id by hand: a session-scoped lookup of the
/// patient returns a row only if the policy allows it, so this is the
/// access check by construction, not just a convenience wrapper around one.
/// Used by every route that writes something staff-triggered (medications,
/// messages) to stop a Dr. Heart login from acting on a Bangalore Diabetes
/// Center patient just by knowing their patient_id.
export async function verifyClinicAccess(patientId: string): Promise<boolean> {
  const sessionClient = createSupabaseServerClient();
  if (!sessionClient) return false;
  const { data } = await sessionClient.from('patients').select('id').eq('id', patientId).maybeSingle();
  return Boolean(data);
}
