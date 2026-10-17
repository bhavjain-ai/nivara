import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { getCurrentStaff } from '@/lib/current-staff';
import { conditionForDrugClass } from '@/lib/medication-classify';
import { verifyClinicAccess } from '@/lib/verify-clinic-access';

export const dynamic = 'force-dynamic';

/**
 * PATCH /api/patients/[id]/medications/[medicationId]
 *
 * Updates an existing medication (e.g. a dose titration) and logs a
 * medication_changes row describing what changed — see the POST route's
 * doc comment for the staff-auth + clinic-access + service-role reasoning,
 * which applies identically here.
 */
export async function PATCH(
  request: NextRequest,
  { params }: { params: { id: string; medicationId: string } }
) {
  if (!supabaseAdmin) {
    return NextResponse.json({ error: 'Supabase is not configured on this server.' }, { status: 503 });
  }

  const staff = await getCurrentStaff();
  if (!staff) {
    return NextResponse.json({ error: 'Not authenticated.' }, { status: 401 });
  }

  const { id: patientId, medicationId } = params;

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
      .update({ name, drug_class: drugClass, dose, frequency, start_date: startDate })
      .eq('id', medicationId)
      .eq('patient_id', patientId)
      .select()
      .single();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    const { error: changeError } = await supabaseAdmin.from('medication_changes').insert({
      patient_id: patientId,
      description: description || `Updated ${name} to ${dose}, ${frequency}`,
      related_condition: conditionForDrugClass(drugClass),
      changed_at: new Date().toISOString().split('T')[0],
    });
    if (changeError) {
      console.error('PATCH .../medications/[medicationId]: medication_changes insert failed:', changeError);
    }

    return NextResponse.json({ success: true, medication });
  } catch {
    return NextResponse.json({ error: 'Invalid request body' }, { status: 400 });
  }
}

/**
 * DELETE /api/patients/[id]/medications/[medicationId]
 *
 * Discontinues a medication. Reads the row first (service-role) to get its
 * name/drug_class for the auto-generated medication_changes description —
 * the client doesn't have to supply those just to delete something.
 */
export async function DELETE(
  request: NextRequest,
  { params }: { params: { id: string; medicationId: string } }
) {
  if (!supabaseAdmin) {
    return NextResponse.json({ error: 'Supabase is not configured on this server.' }, { status: 503 });
  }

  const staff = await getCurrentStaff();
  if (!staff) {
    return NextResponse.json({ error: 'Not authenticated.' }, { status: 401 });
  }

  const { id: patientId, medicationId } = params;

  if (!(await verifyClinicAccess(patientId))) {
    return NextResponse.json({ error: 'Patient not found or not accessible.' }, { status: 404 });
  }

  let description: string | undefined;
  try {
    const body = await request.json();
    description = body?.description;
  } catch {
    // no body supplied — fine, we'll auto-generate the description below
  }

  const { data: existing } = await supabaseAdmin
    .from('medications')
    .select('name, drug_class')
    .eq('id', medicationId)
    .eq('patient_id', patientId)
    .maybeSingle();

  const { error } = await supabaseAdmin
    .from('medications')
    .delete()
    .eq('id', medicationId)
    .eq('patient_id', patientId);

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  if (existing) {
    const { error: changeError } = await supabaseAdmin.from('medication_changes').insert({
      patient_id: patientId,
      description: description || `Discontinued ${existing.name}`,
      related_condition: conditionForDrugClass(existing.drug_class),
      changed_at: new Date().toISOString().split('T')[0],
    });
    if (changeError) {
      console.error('DELETE .../medications/[medicationId]: medication_changes insert failed:', changeError);
    }
  }

  return NextResponse.json({ success: true });
}
