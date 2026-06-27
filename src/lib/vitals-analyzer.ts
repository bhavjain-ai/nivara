import { Patient, AlertStatus, VitalReading } from '@/types';
import { analyzeBP, analyzeGlucose, analyzeO2Sat, analyzeWeight } from './guidelines';

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

export function getPatientAlertLevel(patient: Patient): AlertStatus {
  const vitals = patient.vitals;
  if (!vitals || vitals.length === 0) return 'stable';

  const latest = vitals[vitals.length - 1];
  const statuses: AlertStatus[] = [];

  // Analyze BP
  if (latest.systolic && latest.diastolic) {
    const result = analyzeBP(latest.systolic, latest.diastolic, patient.condition);
    statuses.push(mapStatus(result.status));
  }

  // Analyze Glucose
  if (latest.glucose) {
    const result = analyzeGlucose(latest.glucose, latest.glucoseType || 'fasting', patient.condition);
    statuses.push(mapStatus(result.status));
  }

  // Analyze O2 Sat
  if (latest.o2Sat) {
    const result = analyzeO2Sat(latest.o2Sat, patient.condition);
    statuses.push(mapStatus(result.status));
  }

  // Analyze Weight
  if (latest.weight) {
    const prevWeights = vitals
      .slice(0, -1)
      .map((v: VitalReading) => v.weight)
      .filter((w): w is number => w !== undefined);
    const result = analyzeWeight(latest.weight, prevWeights, patient.condition);
    statuses.push(mapStatus(result.status));
  }

  if (statuses.length === 0) return 'stable';
  return worstStatus(statuses);
}

export function getLatestVitalsSummary(patient: Patient) {
  const latest = patient.vitals[patient.vitals.length - 1];
  if (!latest) return {};

  return {
    bp: latest.systolic && latest.diastolic ? `${latest.systolic}/${latest.diastolic}` : undefined,
    glucose: latest.glucose,
    o2Sat: latest.o2Sat,
    weight: latest.weight,
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
