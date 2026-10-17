import type { SupabaseClient } from '@supabase/supabase-js';

export interface SupabaseBPReading {
  systolic: number;
  diastolic: number;
  pulse: number | null;
  recordedAt: string; // ISO-8601
}

export interface SupabaseGlucoseReading {
  mgDl: number;
  sampleType: 'fasting' | 'post-meal';
  recordedAt: string; // ISO-8601
}

export interface SupabaseLivePatient {
  id: string;
  name: string;
  age: number | null;
  conditions: string[];
  physicianName: string | null;
  enrollmentDate: string; // ISO-8601
  bpReadings: SupabaseBPReading[]; // newest first
  glucoseReadings: SupabaseGlucoseReading[]; // newest first
  lastReadingAt: string | null; // newest of either reading type, or null if none yet
}

interface PatientRow {
  id: string;
  first_name: string;
  last_name: string;
  date_of_birth: string | null;
  conditions: string[] | null;
  physician_name: string | null;
  created_at: string;
}

interface BPReadingRow {
  patient_id: string;
  systolic: number;
  diastolic: number;
  pulse: number | null;
  recorded_at: string;
}

interface GlucoseReadingRow {
  patient_id: string;
  mg_dl: number;
  sample_type: string;
  recorded_at: string;
}

/// Pulls every patient visible to `client` plus their recent BP/glucose
/// readings from Supabase — the real counterpart to the older flat-file
/// reading-store (see reading-store.ts), which nothing in the current iOS
/// app actually posts to. Returns [] (not a thrown error) whenever a query
/// fails or a patient has no readings yet — this feeds the dashboard's
/// existing "live" merge logic (/api/patients/live), which already treats
/// an empty/partial result as "mock data still shows," matching the rest
/// of this app's philosophy that a missing backend should degrade
/// gracefully, never crash a page.
///
/// Takes a session-scoped client (src/lib/supabase-server.ts), not the
/// service-role one — Row Level Security (see
/// supabase/migrations/0003_clinics_and_staff.sql) then does the clinic
/// filtering for us: a clinic-scoped staff session only ever gets back
/// patients from their own clinic, a super-admin session (staff row with
/// clinic_id = null) gets every clinic. Passing the service-role client
/// here instead would bypass that and leak every clinic's patients to
/// whoever's logged in.
export async function getLiveSupabasePatients(client: SupabaseClient): Promise<SupabaseLivePatient[]> {
  const [patientsResult, bpResult, glucoseResult] = await Promise.all([
    client
      .from('patients')
      .select('id, first_name, last_name, date_of_birth, conditions, physician_name, created_at'),
    client
      .from('bp_readings')
      .select('patient_id, systolic, diastolic, pulse, recorded_at')
      .order('recorded_at', { ascending: false })
      .limit(1000),
    client
      .from('glucose_readings')
      .select('patient_id, mg_dl, sample_type, recorded_at')
      .order('recorded_at', { ascending: false })
      .limit(1000),
  ]);

  const patients = (patientsResult.data ?? []) as PatientRow[];
  if (patientsResult.error) {
    console.error('getLiveSupabasePatients: patients query failed:', patientsResult.error);
  }
  if (patientsResult.error || patients.length === 0) return [];

  if (bpResult.error) {
    console.error('getLiveSupabasePatients: bp_readings query failed:', bpResult.error);
  }
  if (glucoseResult.error) {
    console.error('getLiveSupabasePatients: glucose_readings query failed:', glucoseResult.error);
  }
  const bpRows = (bpResult.data ?? []) as BPReadingRow[];
  const glucoseRows = (glucoseResult.data ?? []) as GlucoseReadingRow[];

  console.log(
    `getLiveSupabasePatients: ${patients.length} patient(s), ${bpRows.length} bp row(s), ${glucoseRows.length} glucose row(s)`
  );

  return patients.map((p) => {
    const bpReadings: SupabaseBPReading[] = bpRows
      .filter((r) => r.patient_id === p.id)
      .map((r) => ({ systolic: r.systolic, diastolic: r.diastolic, pulse: r.pulse, recordedAt: r.recorded_at }));
    const glucoseReadings: SupabaseGlucoseReading[] = glucoseRows
      .filter((r) => r.patient_id === p.id)
      .map((r) => ({
        mgDl: r.mg_dl,
        sampleType: r.sample_type === 'post-meal' ? 'post-meal' : 'fasting',
        recordedAt: r.recorded_at,
      }));

    const latestTimestamps = [bpReadings[0]?.recordedAt, glucoseReadings[0]?.recordedAt].filter(
      (t): t is string => Boolean(t)
    );
    const lastReadingAt = latestTimestamps.length > 0
      ? latestTimestamps.sort((a, b) => b.localeCompare(a))[0]
      : null;

    return {
      id: p.id,
      name: `${p.first_name} ${p.last_name}`.trim(),
      age: p.date_of_birth ? ageFromDateOfBirth(p.date_of_birth) : null,
      conditions: p.conditions ?? [],
      physicianName: p.physician_name,
      enrollmentDate: p.created_at,
      bpReadings,
      glucoseReadings,
      lastReadingAt,
    };
  });
}

function ageFromDateOfBirth(dateOfBirth: string): number {
  const birth = new Date(dateOfBirth);
  const now = new Date();
  let age = now.getFullYear() - birth.getFullYear();
  const hasHadBirthdayThisYear =
    now.getMonth() > birth.getMonth() ||
    (now.getMonth() === birth.getMonth() && now.getDate() >= birth.getDate());
  if (!hasHadBirthdayThisYear) age -= 1;
  return age;
}
