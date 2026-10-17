import { NextResponse } from 'next/server';
import { getAllLivePatients, getLivePatient } from '@/lib/reading-store';
import { getLiveSupabasePatients } from '@/lib/supabase-live';
import { createSupabaseServerClient } from '@/lib/supabase-server';
import { mockPatients } from '@/lib/mock-data';

export const dynamic = 'force-dynamic';

/**
 * GET /api/patients/live
 *
 * Returns all live readings merged with mock patient records, from two
 * independent sources:
 * - The older flat-file reading-store (BP only) — nothing in the current
 *   iOS app posts to this; kept for whatever originally relied on it.
 * - Supabase (BP + glucose) — the real path, fed by the iOS app's
 *   SupabaseService.pushBPReading/pushGlucoseReading once a patient has a
 *   real Supabase project configured (see SUPABASE_SETUP.md). Returns []
 *   gracefully if Supabase isn't configured.
 *
 * Both sources report into the same per-patient `vitals`-shaped reading
 * list (systolic/diastolic for BP, glucose/glucoseType for glucose, same
 * as mock-data.ts's own VitalReading entries), so a real patient with
 * both a BP cuff and a glucose meter shows both on one chart.
 *
 * - Known patient IDs (matching mock data): live readings prepended to their vitals.
 * - Unknown patient IDs: minimal patient record built from live readings only.
 */
export async function GET() {
  const liveRecords = getAllLivePatients();
  const supabase = createSupabaseServerClient();
  const supabasePatients = supabase ? await getLiveSupabasePatients(supabase) : [];
  const knownIds = new Set(mockPatients.map(p => p.id));

  const fromFlatFile = liveRecords.map(record => {
    const mockPatient = mockPatients.find(p => p.id === record.patientId);
    const latest = record.readings[0];

    const liveVitals = record.readings.map(r => ({
      date: r.timestamp.split('T')[0],
      systolic: r.systolic,
      diastolic: r.diastolic,
    }));

    if (mockPatient) {
      // Merge: prepend live readings, deduplicate by date
      const existingDates = new Set(mockPatient.vitals.map(v => v.date));
      const newVitals = liveVitals.filter(v => !existingDates.has(v.date));
      return {
        ...mockPatient,
        vitals: [...newVitals, ...mockPatient.vitals],
        lastReadingTime: formatRelative(record.lastUpdate),
        isLive: true,
        liveReadings: record.readings,
      };
    }

    // Unknown patient — build minimal record
    return {
      id: record.patientId,
      name: `Patient ${record.patientId}`,
      age: null,
      gender: null,
      conditions: ['Hypertension'],
      city: '—',
      phoneNumber: '—',
      physicianName: 'Unassigned',
      enrollmentDate: record.firstSeen.split('T')[0],
      treatmentStep: 1,
      medications: [],
      alerts: [],
      alertStatus: getBpAlertStatus(latest?.systolic, latest?.diastolic),
      lastReadingTime: formatRelative(record.lastUpdate),
      vitals: liveVitals,
      isLive: true,
      liveReadings: record.readings,
    };
  });

  const fromSupabase = supabasePatients
    .filter(p => !knownIds.has(p.id)) // real patient_id UUIDs never collide with mock IDs, but guard anyway
    .map(p => {
      const bpVitals = p.bpReadings.map(r => ({
        date: r.recordedAt,
        systolic: r.systolic,
        diastolic: r.diastolic,
      }));
      const glucoseVitals = p.glucoseReadings.map(r => ({
        date: r.recordedAt,
        glucose: r.mgDl,
        glucoseType: r.sampleType,
      }));
      const vitals = [...bpVitals, ...glucoseVitals];
      const latestBP = p.bpReadings[0];

      return {
        id: p.id,
        name: p.name,
        age: p.age,
        gender: null,
        conditions: p.conditions.length > 0 ? p.conditions : ['Hypertension'],
        city: '—',
        phoneNumber: '—',
        physicianName: p.physicianName ?? 'Unassigned',
        enrollmentDate: p.enrollmentDate.split('T')[0],
        treatmentStep: 1,
        medications: p.medications.map(m => ({
          id: m.id,
          name: m.name,
          genericName: m.name, // not captured separately in the schema — unused in the UI, so this is a harmless default
          drugClass: m.drugClass,
          dose: m.dose,
          frequency: m.frequency,
          startDate: m.startDate,
        })),
        medicationHistory: p.medicationHistory,
        alerts: [],
        // BP-only, same scope as the flat-file path above — glucose-based
        // alerting isn't wired into this merge yet.
        alertStatus: getBpAlertStatus(latestBP?.systolic, latestBP?.diastolic),
        lastReadingTime: p.lastReadingAt ? formatRelative(p.lastReadingAt) : 'No readings yet',
        vitals,
        isLive: true,
        liveReadings: p.bpReadings.map(r => ({ systolic: r.systolic, diastolic: r.diastolic, pulse: r.pulse ?? undefined, timestamp: r.recordedAt })),
      };
    });

  const result = [...fromFlatFile, ...fromSupabase];

  return NextResponse.json({ patients: result, updatedAt: new Date().toISOString() });
}


function getBpAlertStatus(systolic?: number, diastolic?: number): string {
  if (!systolic || !diastolic) return 'normal';
  if (systolic >= 180 || diastolic >= 120) return 'critical';
  if (systolic >= 160 || diastolic >= 100) return 'critical';
  if (systolic >= 140 || diastolic >= 90) return 'warning';
  return 'normal';
}

function formatRelative(iso: string): string {
  const diffMs = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diffMs / 60000);
  if (mins < 1) return 'Just now';
  if (mins < 60) return `${mins} minute${mins > 1 ? 's' : ''} ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs} hour${hrs > 1 ? 's' : ''} ago`;
  return `${Math.floor(hrs / 24)} days ago`;
}
