import { NextRequest, NextResponse } from 'next/server';
import { createSupabaseServerClient } from '@/lib/supabase-server';
import { getCurrentStaff } from '@/lib/current-staff';
import { verifyClinicAccess } from '@/lib/verify-clinic-access';

export const dynamic = 'force-dynamic';

/**
 * GET /api/patients/[id]/messages
 *
 * Lists every message in this patient's Care Team threads, for the
 * dashboard's MessagePanel. Reads through the session-scoped client, not
 * supabaseAdmin — RLS's messages_staff_select policy
 * (supabase/migrations/0003_clinics_and_staff.sql) already restricts this
 * to patients in the logged-in staff member's clinic, so there's nothing
 * service-role access would add here, and using it would skip that check.
 */
export async function GET(request: NextRequest, { params }: { params: { id: string } }) {
  const staff = await getCurrentStaff();
  if (!staff) {
    return NextResponse.json({ error: 'Not authenticated.' }, { status: 401 });
  }

  const patientId = params.id;
  if (!(await verifyClinicAccess(patientId))) {
    return NextResponse.json({ error: 'Patient not found or not accessible.' }, { status: 404 });
  }

  const sessionClient = createSupabaseServerClient();
  if (!sessionClient) {
    return NextResponse.json({ messages: [] });
  }

  const { data, error } = await sessionClient
    .from('messages')
    .select('id, coordinator_role, sender_type, sender_name, body, read_at, created_at')
    .eq('patient_id', patientId)
    .order('created_at', { ascending: true });

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ messages: data ?? [] });
}
