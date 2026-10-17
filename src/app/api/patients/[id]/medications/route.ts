import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { getCurrentStaff } from '@/lib/current-staff';
import { conditionForDrugClass } from '@/lib/medication-classify';
import { verifyClinicAccess } from '@/lib/verify-clinic-access';

export const dynamic = 'force-dynamic';

/**
 * POST /api/patients/[id]/medications
 *
 * Adds a new medication for a real (Supabase-backed) patient, as the
 * logged-in staff member. Writes through the service-role client — same
 * reasoning as /api/messages: there's no staff INSERT policy on
 * `medications`, by design (see supabase/migrations/0001_init.sql's
 * comment on it), so a trusted server path is required. Clinic access is
 * checked first via a session-scoped lookup of the target patient, which
 * RLS (supabase/migrations/0003_clinics_and_staff.sql) naturally restricts
 * to patients in the logged-in staff member's own clinic.
 *
 * Also logs a medication_changes row describing the addition — this is
 * what shows up in the iOS app's "Recent Changes" card, so a dose/regimen
 * change made here is actually visible to the patient, not just recorded
 * silently.
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

  try {
    const body = await request.json();
    const { name, drugClass, dose, frequency, startDate, description } = body;

    if (!name || !drugClass || !dose || !frequency || !startDate) {
      return NextResponse.json(
        { error: 'Missing required fields: name, drugClass, dose, frequency, startDate' },
        { status: 400 }
      );
    }

    if (!(await verifyClinicAccess(patientId))) {
      return NextResponse.json({ error: 'Patient not found or not accessible.' }, { status: 404 });
    }

    const { data: medication, error } = await supabaseAdmin
      .from('medications')
      .insert({ patient_id: patientId, name, drug_class: drugClass, dose, frequency, start_date: startDate })
      .select()
      .single();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    const { error: changeError } = await supabaseAdmin.from('medication_changes').insert({
      patient_id: patientId,
      description: description || `Started ${name} ${dose}, ${frequency}`,
      related_condition: conditionForDrugClass(drugClass),
      changed_at: startDate,
    });
    if (changeError) {
      console.error('POST /api/patients/[id]/medications: medication_changes insert failed:', changeError);
    }

    return NextResponse.json({ success: true, medication }, { status: 201 });
  } catch {
    return NextResponse.json({ error: 'Invalid request body' }, { status: 400 });
  }
}
