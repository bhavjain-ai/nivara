import { supabaseAdmin } from './supabase-admin';

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

/// Pulls every registered patient plus their recent BP/glucose readings
/// directly from Supabase — the real counterpart to the older flat-file
/// reading-store (see reading-store.ts), which nothing in the current iOS
/// app actually posts to. Returns [] (not a thrown error) whenever
/// Supabase isn't configured, a patient has no readings yet, or a query
/// fails — this feeds the dashboard's existing "live" merge logic
/// (/api/patients/live), which already treats an empty/partial result as
/// "mock data still shows," matching the rest of this app's philosophy
/// that a missing backend should degrade gracefully, never crash a page.
///
/// Uses the service-role client deliberately: this needs to see every
/// patient's readings in one query for the admin-facing dashboard, which
/// is exactly what a patient's own RLS-scoped anon session can never do
/// (by design — see supabase/migrations/0001_init.sql).
export async function getLiveSupabasePatients(): Promise<SupabaseLivePatient[]> {
  if (!supabaseAdmin) return [];

  const [patientsResult, bpResult, glucoseResult] = await Promise.all([
    supabaseAdmin
      .from('patients')
      .select('id, first_name, last_name, date_of_birth, conditions, physician_name, created_at'),
    supabaseAdmin
      .from('bp_readings')
      .select('patient_id, systolic, diastolic, pulse, recorded_at')
      .order('recorded_at', { ascending: false })
      .limit(1000),
    supabaseAdmin
      .from('glucose_readings')
      .select('patient_id, mg_dl, sample_type, recorded_at')
      .order('recorded_at', { ascending: false })
      .limit(1000),
  ]);

  const patients = (patientsResult.data ?? []) as PatientRow[];
  if (patientsResult.error || patients.length === 0) return [];

  const bpRows = (bpResult.data ?? []) as BPReadingRow[];
  const glucoseRows = (glucoseResult.data ?? []) as GlucoseReadingRow[];

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
