import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';

const VALID_ROLES = ['Physician', 'Dietician', 'Coach'] as const;

/**
 * POST /api/messages
 *
 * Inserts a care-team-authored chat message. Uses the service-role Supabase
 * client because RLS (see supabase/migrations/0001_init.sql) only lets a
 * patient's own anon session insert messages with sender_type = 'patient' —
 * a coordinator's reply has to come from a trusted server path like this one.
 *
 * ⚠️ NOT YET AUTHENTICATED. There is no login system for the physician/
 * coordinator web dashboard anywhere in this repo yet (it currently runs on
 * hardcoded mock data — see src/lib/mock-data.ts). Right now, anyone who can
 * reach this route can post a message impersonating any patient's care
 * team. This is fine for local development against your own Supabase
 * project, but this route MUST be gated behind real staff authentication
 * (e.g. Supabase Auth with an email/password or SSO login for coordinators,
 * checked here via the request's session) before this is exposed publicly.
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { patient_id, coordinator_role, sender_name, message_body } = body;

    if (!patient_id || !coordinator_role || !sender_name || !message_body) {
      return NextResponse.json(
        { error: 'Missing required fields: patient_id, coordinator_role, sender_name, message_body' },
        { status: 400 }
      );
    }

    if (!VALID_ROLES.includes(coordinator_role)) {
      return NextResponse.json({ error: `coordinator_role must be one of ${VALID_ROLES.join(', ')}` }, { status: 422 });
    }

    const { data, error } = await supabaseAdmin
      .from('messages')
      .insert({
        patient_id,
        coordinator_role,
        sender_type: 'care_team',
        sender_name,
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
