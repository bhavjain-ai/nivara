import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { getCurrentStaff } from '@/lib/current-staff';
import { verifyClinicAccess } from '@/lib/verify-clinic-access';

export const dynamic = 'force-dynamic';

/**
 * POST /api/patients/[id]/messages/mark-read
 *
 * Marks a patient's unread messages as read (sets read_at) — called when
 * staff opens a coordinator-role tab in MessagePanel. Uses supabaseAdmin
 * since there's no staff UPDATE policy on `messages` (same reasoning as
 * every other staff write in this app — see /api/messages's doc comment).
 * Optional `coordinatorRole` in the body scopes it to one thread; omitted,
 * it marks every thread read.
 */
export async function POST(request: NextRequest, { params }: { params: { id: string } }) {
  if (!supabaseAdmin) {
    return NextResponse.json({ error: 'Supabase is not configured on this server.' }, { status: 503 });
  }

  const staff = await getCurrentStaff();
  if (!staff) {
    return NextResponse.json({ error: 'Not authenticated.' }, { status: 401 });
  }

  const patientId = params.id;
  if (!(await verifyClinicAccess(patientId))) {
    return NextResponse.json({ error: 'Patient not found or not accessible.' }, { status: 404 });
  }

  let coordinatorRole: string | undefined;
  try {
    const body = await request.json();
    coordinatorRole = body?.coordinatorRole;
  } catch {
    // no body supplied — fine, marks every thread read
  }

  let query = supabaseAdmin
    .from('messages')
    .update({ read_at: new Date().toISOString() })
    .eq('patient_id', patientId)
    .eq('sender_type', 'patient')
    .is('read_at', null);

  if (coordinatorRole) {
    query = query.eq('coordinator_role', coordinatorRole);
  }

  const { error } = await query;
  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ success: true });
}
