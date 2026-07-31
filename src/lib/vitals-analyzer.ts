import { Patient, AlertStatus } from '@/types';
import { analyzeBP, analyzeGlucose, getBPTarget, getGlucoseTargets } from './guidelines';

const statusOrder: AlertStatus[] = ['critical', 'warning', 'stable', 'normal'];

function worstStatus(statuses: AlertStatus[]): AlertStatus {
  for (const s of statusOrder) {
    if (statuses.includes(s)) return s;
  }
  return 'normal';
}

function mapStatus(raw: string): AlertStatus {
  if (raw === 'critical') return 'critical';
  if (raw === 'alert') return 'warning';
  if (raw === 'warning') return 'warning';
  if (raw === 'normal') return 'stable';
  return 'stable';
}

// BP and glucose are logged as separate sparse readings (not one combined daily record —
// SMBG frequency is individualized, not daily), so the latest BP and latest glucose reading
// must be found independently rather than assuming they share the single last vitals entry.
function latestBPReading(patient: Patient) {
  const readings = patient.vitals.filter((v) => v.systolic && v.diastolic);
  return readings[readings.length - 1];
}

function latestGlucoseReading(patient: Patient) {
  const readings = patient.vitals.filter((v) => v.glucose);
  return readings[readings.length - 1];
}

export function getPatientAlertLevel(patient: Patient): AlertStatus {
  if (!patient.vitals || patient.vitals.length === 0) return 'stable';

  const statuses: AlertStatus[] = [];

  const latestBP = latestBPReading(patient);
  if (latestBP?.systolic && latestBP.diastolic) {
    const target = getBPTarget(patient.conditions, patient.comorbidities, patient.age);
    const result = analyzeBP(latestBP.systolic, latestBP.diastolic, target);
    statuses.push(mapStatus(result.status));
  }

  const latestGlucose = latestGlucoseReading(patient);
  if (latestGlucose?.glucose && patient.hba1cTier) {
    const targets = getGlucoseTargets(patient.hba1cTier.tier);
    const result = analyzeGlucose(latestGlucose.glucose, latestGlucose.glucoseType || 'fasting', targets);
    statuses.push(mapStatus(result.status));
  }

  if (statuses.length === 0) return 'stable';
  return worstStatus(statuses);
}

export function getLatestVitalsSummary(patient: Patient) {
  const latestBP = latestBPReading(patient);
  const latestGlucose = latestGlucoseReading(patient);

  return {
    bp: latestBP?.systolic && latestBP.diastolic ? `${latestBP.systolic}/${latestBP.diastolic}` : undefined,
    glucose: latestGlucose?.glucose,
    glucoseType: latestGlucose?.glucoseType,
  };
}

export function getTrendDirection(values: number[]): 'up' | 'down' | 'stable' {
  if (values.length < 2) return 'stable';
  const recent = values.slice(-3);
  const first = recent[0];
  const last = recent[recent.length - 1];
  const diff = last - first;
  if (Math.abs(diff) < 2) return 'stable';
  return diff > 0 ? 'up' : 'down';
}
