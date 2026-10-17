import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { createSupabaseServerClient } from '@/lib/supabase-server';
import { getCurrentStaff } from '@/lib/current-staff';

const VALID_ROLES = ['Physician', 'Dietician', 'Coach'] as const;

/**
 * POST /api/messages
 *
 * Inserts a care-team-authored chat message, as the logged-in staff member
 * (see supabase/migrations/0003_clinics_and_staff.sql) — sender_name comes
 * from their session, never from the request body, so one staff member
 * can't post pretending to be someone else.
 *
 * Uses the service-role Supabase client for the actual insert because RLS
 * (see supabase/migrations/0001_init.sql) only lets a patient's own anon
 * session insert messages with sender_type = 'patient' — a coordinator's
 * reply has to come from a trusted server path like this one. Clinic
 * access is still checked first, via a session-scoped lookup of the target
 * patient (RLS-filtered — see getLiveSupabasePatients's doc comment for why
 * this is the right client to use for that), so a Dr. Heart staff member
 * can't message a Bangalore Diabetes Center patient just by knowing their
 * patient_id.
 */
export async function POST(request: NextRequest) {
  if (!supabaseAdmin) {
    return NextResponse.json(
      { error: 'Supabase is not configured on this server — copy .env.local.example to .env.local and fill in your project values.' },
      { status: 503 }
    );
  }

  const staff = await getCurrentStaff();
  if (!staff) {
    return NextResponse.json({ error: 'Not authenticated.' }, { status: 401 });
  }

  try {
    const body = await request.json();
    const { patient_id, coordinator_role, message_body } = body;

    if (!patient_id || !coordinator_role || !message_body) {
      return NextResponse.json(
        { error: 'Missing required fields: patient_id, coordinator_role, message_body' },
        { status: 400 }
      );
    }

    if (!VALID_ROLES.includes(coordinator_role)) {
      return NextResponse.json({ error: `coordinator_role must be one of ${VALID_ROLES.join(', ')}` }, { status: 422 });
    }

    // RLS-scoped lookup, not supabaseAdmin: returns no row if this patient
    // isn't in the logged-in staff member's clinic, which is exactly the
    // access check we want — see supabase/migrations/0003_clinics_and_staff.sql.
    const sessionClient = createSupabaseServerClient();
    const { data: patientRow } = sessionClient
      ? await sessionClient.from('patients').select('id').eq('id', patient_id).maybeSingle()
      : { data: null };
    if (!patientRow) {
      return NextResponse.json({ error: 'Patient not found or not accessible.' }, { status: 404 });
    }

    const { data, error } = await supabaseAdmin
      .from('messages')
      .insert({
        patient_id,
        coordinator_role,
        sender_type: 'care_team',
        sender_name: staff.name,
        body: message_body,
      })
      .select()
      .single();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true, message: data }, { status: 201 });
  } catch {
    return NextResponse.json({ error: 'Invalid request body' }, { status: 400 });
  }
}
