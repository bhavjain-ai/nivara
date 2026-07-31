import {
  AlertStatus,
  Comorbidity,
  Condition,
  GlucoseTargetRange,
  HbA1cTierInfo,
  VitalStatus,
} from '@/types';

// --- Individualized targets ---

export interface BPTarget {
  sys: number;
  dia: number;
  label: string;
}

// IGH-V (2025-2026) — BP target is individualized, not one number for everyone
export function getBPTarget(
  conditions: Condition[],
  comorbidities: Comorbidity[],
  age: number
): BPTarget {
  const hasDiabetes = conditions.includes('Diabetes');
  const highRisk =
    comorbidities.includes('Established CVD') ||
    comorbidities.includes('CKD') ||
    comorbidities.includes('DKD');

  if (hasDiabetes) {
    return { sys: 129, dia: 79, label: '120–129/70–79 mmHg (diabetes-comorbid target, IGH-V/RSSDI 2022, where tolerated)' };
  }
  if (highRisk) {
    return { sys: 130, dia: 80, label: '<130/80 mmHg (high-risk target — established CVD/CKD, IGH-V)' };
  }
  if (age >= 65 && age <= 80) {
    return { sys: 140, dia: 80, label: '130–140/70–80 mmHg (elderly target, IGH-V — per clinical judgment)' };
  }
  return { sys: 140, dia: 90, label: '<140/90 mmHg (general target, IGH-V)' };
}

const HBA1C_TIERS: Record<1 | 2 | 3, HbA1cTierInfo> = {
  1: { tier: 1, target: '6.5%', targetValue: 6.5 },
  2: { tier: 2, target: '<7.0%', targetValue: 7.0 },
  3: { tier: 3, target: '7.5–8.0%', targetValue: 8.0 },
};

export function getHbA1cTierInfo(tier: 1 | 2 | 3): HbA1cTierInfo {
  return HBA1C_TIERS[tier];
}

export function getGlucoseTargets(hba1cTier: 1 | 2 | 3): GlucoseTargetRange {
  if (hba1cTier === 3) {
    return { population: 'relaxed', fastingLow: 90, fastingHigh: 150, postprandialHigh: 250 };
  }
  return { population: 'standard', fastingLow: 80, fastingHigh: 130, postprandialHigh: 180 };
}

// --- Blood pressure (IGH-V 2025-2026, Fig. 14 / Table 1) ---

function classifyBPStage(systolic: number, diastolic: number): { status: AlertStatus; label: string } | null {
  if (systolic >= 180 || diastolic >= 120) {
    return { status: 'critical', label: 'Hypertensive Crisis / Emergency' };
  }
  if (diastolic >= 110) {
    return { status: 'critical', label: 'Severe Hypertension (Stage III)' };
  }
  if (systolic >= 160 || diastolic >= 100) {
    return { status: 'critical', label: 'Moderate Hypertension (Stage II)' };
  }
  if (systolic >= 140 || diastolic >= 90) {
    return { status: 'warning', label: 'Mild Hypertension (Stage I)' };
  }
  return null;
}

export function analyzeBP(systolic: number, diastolic: number, target: BPTarget): VitalStatus {
  const stage = classifyBPStage(systolic, diastolic);
  if (stage) {
    return {
      status: stage.status,
      message: `${stage.label}: ${systolic}/${diastolic} mmHg`,
      guideline:
        stage.status === 'critical' && (systolic >= 180 || diastolic >= 120)
          ? 'IGH-V: SBP ≥180 or DBP ≥120 mmHg = urgent alert threshold, immediate escalation'
          : `IGH-V Step-Care Table 1 (presenting BP severity): ${stage.label}`,
    };
  }

  if (systolic > target.sys || diastolic > target.dia) {
    return {
      status: 'warning',
      message: `Above individualized target: ${systolic}/${diastolic} mmHg`,
      guideline: `IGH-V: patient's target is ${target.label}`,
    };
  }

  return {
    status: 'normal',
    message: `At target: ${systolic}/${diastolic} mmHg`,
    guideline: `IGH-V: within individualized target (${target.label})`,
  };
}

// --- Blood glucose (RSSDI Clinical Practice Recommendations 2022/2024, ADA Standards of Care 2026) ---

export function analyzeGlucose(
  glucose: number,
  glucoseType: 'fasting' | 'post-meal',
  targets: GlucoseTargetRange
): VitalStatus {
  if (glucose < 54) {
    return {
      status: 'critical',
      message: `Level 2 Hypoglycemia (severe): ${glucose} mg/dL — immediate physician contact`,
      guideline: 'RSSDI/ADA: <54 mg/dL = Level 2 hypoglycemia, immediate escalation (Part 3 safety protocol)',
    };
  }
  if (glucose < 70) {
    return {
      status: 'critical',
      message: `Level 1 Hypoglycemia: ${glucose} mg/dL — patient & family notified, no 3-reading wait`,
      guideline: 'RSSDI/ADA: <70, ≥54 mg/dL = Level 1 hypoglycemia, immediate patient + family alert',
    };
  }
  if (glucose > 300) {
    return {
      status: 'critical',
      message: `Severe Hyperglycemia: ${glucose} mg/dL`,
      guideline: 'RSSDI/ADA: >300 mg/dL = severe hyperglycemia, immediate physician review',
    };
  }

  const targetLabel =
    targets.population === 'relaxed'
      ? 'relaxed targets (Tier 3 / higher hypoglycemia risk)'
      : 'standard targets (Tier 1–2)';

  if (glucoseType === 'fasting') {
    if (glucose > targets.fastingHigh) {
      return {
        status: 'warning',
        message: `Above fasting target: ${glucose} mg/dL`,
        guideline: `RSSDI/ADA: fasting target ${targets.fastingLow}–${targets.fastingHigh} mg/dL (${targetLabel})`,
      };
    }
    if (glucose < targets.fastingLow) {
      return {
        status: 'warning',
        message: `Below fasting target: ${glucose} mg/dL`,
        guideline: `RSSDI/ADA: fasting target ${targets.fastingLow}–${targets.fastingHigh} mg/dL (${targetLabel})`,
      };
    }
    return {
      status: 'normal',
      message: `At fasting target: ${glucose} mg/dL`,
      guideline: `RSSDI/ADA: fasting target ${targets.fastingLow}–${targets.fastingHigh} mg/dL (${targetLabel})`,
    };
  }

  // post-meal (2hr)
  if (glucose > targets.postprandialHigh) {
    return {
      status: 'warning',
      message: `Above postprandial target: ${glucose} mg/dL`,
      guideline: `RSSDI/ADA: 2hr postprandial target <${targets.postprandialHigh} mg/dL (${targetLabel})`,
    };
  }
  return {
    status: 'normal',
    message: `At postprandial target: ${glucose} mg/dL`,
    guideline: `RSSDI/ADA: 2hr postprandial target <${targets.postprandialHigh} mg/dL (${targetLabel})`,
  };
}

// Map internal status to AlertStatus (kept for compatibility with any 'alert' string usages)
export function toAlertStatus(status: string): AlertStatus {
  if (status === 'alert') return 'warning';
  return status as AlertStatus;
}
