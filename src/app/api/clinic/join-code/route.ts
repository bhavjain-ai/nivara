import { NextRequest, NextResponse } from 'next/server';
import { randomInt } from 'crypto';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { getCurrentStaff } from '@/lib/current-staff';

export const dynamic = 'force-dynamic';

// Excludes visually ambiguous characters (0/O, 1/I/L) since this gets read
// off a screen or printed card and typed back in by a patient.
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

function generateJoinCode(): string {
  let code = '';
  for (let i = 0; i < 8; i++) {
    code += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
  }
  return code;
}

/**
 * GET /api/clinic/join-code
 *
 * Returns the join code(s) a staff member is allowed to see: their own
 * clinic's code for ordinary staff, or every clinic's code for a
 * super-admin (clinic_id = null — see supabase/migrations/0003). Uses the
 * service-role client because `clinics.join_code` is deliberately not
 * selectable via the session-scoped client (see
 * supabase/migrations/0005_clinic_join_codes.sql) — this route is the only
 * sanctioned way to read it back.
 */
export async function GET() {
  if (!supabaseAdmin) {
    return NextResponse.json({ error: 'Supabase is not configured on this server.' }, { status: 503 });
  }

  const staff = await getCurrentStaff();
  if (!staff) {
    return NextResponse.json({ error: 'Not authenticated.' }, { status: 401 });
  }

  let query = supabaseAdmin.from('clinics').select('id, name, join_code').order('name');
  if (!staff.isSuperAdmin) {
    query = query.eq('id', staff.clinicId as string);
  }

  const { data, error } = await query;
  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ clinics: data });
}

/**
 * POST /api/clinic/join-code
 *
 * Generates a fresh join code for a clinic, replacing whatever code it had
 * (a leaked or shared-too-widely code can be rotated — the old one stops
 * working immediately since the column is unique and this overwrites it).
 * Ordinary staff always rotate their own clinic; a super-admin must pass
 * `{ clinicId }` in the body to say which one.
 */
export async function POST(request: NextRequest) {
  if (!supabaseAdmin) {
    return NextResponse.json({ error: 'Supabase is not configured on this server.' }, { status: 503 });
  }

  const staff = await getCurrentStaff();
  if (!staff) {
    return NextResponse.json({ error: 'Not authenticated.' }, { status: 401 });
  }

  let clinicId: string;
  if (staff.isSuperAdmin) {
    const body = await request.json().catch(() => ({}));
    if (!body?.clinicId) {
      return NextResponse.json({ error: 'clinicId is required for a super-admin.' }, { status: 400 });
    }
    clinicId = body.clinicId;
  } else {
    if (!staff.clinicId) {
      return NextResponse.json({ error: 'No clinic associated with this account.' }, { status: 422 });
    }
    clinicId = staff.clinicId;
  }

  // A fresh random code can, in principle, collide with an existing one
  // (the column is `unique`) — retry a few times rather than surfacing a
  // raw constraint-violation error for what's really just bad luck.
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = generateJoinCode();
    const { data, error } = await supabaseAdmin
      .from('clinics')
      .update({ join_code: code })
      .eq('id', clinicId)
      .select('id, name, join_code')
      .single();

    if (!error) {
      return NextResponse.json({ success: true, clinic: data });
    }
    if (error.code !== '23505') {
      // Not a unique-violation — a retry won't help.
      return NextResponse.json({ error: error.message }, { status: 500 });
    }
  }

  return NextResponse.json({ error: 'Could not generate a unique code — try again.' }, { status: 500 });
}
