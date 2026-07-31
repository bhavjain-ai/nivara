import { NextResponse } from 'next/server';
import { getAllLivePatients, getLivePatient } from '@/lib/reading-store';
import { mockPatients } from '@/lib/mock-data';

export const dynamic = 'force-dynamic';

/**
 * GET /api/patients/live
 *
 * Returns all live readings merged with mock patient records.
 * - Known patient IDs (matching mock data): live readings prepended to their vitals.
 * - Unknown patient IDs: minimal patient record built from live readings only.
 */
export async function GET() {
  const liveRecords = getAllLivePatients();
  const knownIds = new Set(mockPatients.map(p => p.id));

  const result = liveRecords.map(record => {
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
      condition: 'Hypertension', // kept as a flat string for the /api/patients/live wire format
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
