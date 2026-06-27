import { AlertStatus, Condition, VitalStatus } from '@/types';

// AHA 2017 + ISH India 2020 Blood Pressure Guidelines
export function analyzeBP(
  systolic: number,
  diastolic: number,
  _condition?: Condition
): VitalStatus {
  if (systolic >= 180 || diastolic >= 120) {
    return {
      status: 'critical',
      message: `Hypertensive Crisis: ${systolic}/${diastolic} mmHg`,
      guideline: 'AHA 2017 / ISH India 2020: Systolic ≥180 or Diastolic ≥120 = Hypertensive Crisis',
    };
  }
  if (systolic >= 140 || diastolic >= 90) {
    return {
      status: 'alert' as AlertStatus,
      message: `Stage 2 Hypertension: ${systolic}/${diastolic} mmHg`,
      guideline: 'AHA 2017 / ISH India 2020: Systolic ≥140 or Diastolic ≥90 = Stage 2 HTN',
    };
  }
  if ((systolic >= 130 && systolic <= 139) || (diastolic >= 80 && diastolic <= 89)) {
    return {
      status: 'warning',
      message: `Stage 1 Hypertension: ${systolic}/${diastolic} mmHg`,
      guideline: 'AHA 2017 / ISH India 2020: Systolic 130-139 or Diastolic 80-89 = Stage 1 HTN',
    };
  }
  if (systolic >= 120 && systolic <= 129 && diastolic < 80) {
    return {
      status: 'warning',
      message: `Elevated BP: ${systolic}/${diastolic} mmHg`,
      guideline: 'AHA 2017: Systolic 120-129 with Diastolic <80 = Elevated',
    };
  }
  return {
    status: 'normal',
    message: `Normal BP: ${systolic}/${diastolic} mmHg`,
    guideline: 'AHA 2017 / ISH India 2020: Systolic <120 and Diastolic <80 = Normal',
  };
}

// RSSDI + ADA Blood Glucose Guidelines
export function analyzeGlucose(
  glucose: number,
  glucoseType: 'fasting' | 'post-meal' = 'fasting',
  _condition?: Condition
): VitalStatus {
  if (glucose < 70) {
    return {
      status: 'critical',
      message: `Hypoglycemia: ${glucose} mg/dL`,
      guideline: 'RSSDI / ADA: Glucose <70 mg/dL = Hypoglycemia (Critical)',
    };
  }
  if (glucose > 300) {
    return {
      status: 'critical',
      message: `Severe Hyperglycemia: ${glucose} mg/dL`,
      guideline: 'RSSDI / ADA: Glucose >300 mg/dL = Severe Hyperglycemia (Critical)',
    };
  }

  if (glucoseType === 'fasting') {
    if (glucose >= 126) {
      return {
        status: 'alert' as AlertStatus,
        message: `Fasting Diabetes Range: ${glucose} mg/dL`,
        guideline: 'RSSDI / ADA: Fasting Glucose ≥126 mg/dL = Diabetes Alert',
      };
    }
    if (glucose >= 100) {
      return {
        status: 'warning',
        message: `Fasting Prediabetes: ${glucose} mg/dL`,
        guideline: 'RSSDI / ADA: Fasting Glucose 100-125 mg/dL = Prediabetes Warning',
      };
    }
    return {
      status: 'normal',
      message: `Normal Fasting Glucose: ${glucose} mg/dL`,
      guideline: 'RSSDI / ADA: Fasting Glucose 70-99 mg/dL = Normal',
    };
  } else {
    // post-meal (2hr)
    if (glucose >= 200) {
      return {
        status: 'alert' as AlertStatus,
        message: `Post-meal Diabetes Range: ${glucose} mg/dL`,
        guideline: 'RSSDI / ADA: 2hr Post-meal Glucose ≥200 mg/dL = Diabetes Alert',
      };
    }
    if (glucose >= 140) {
      return {
        status: 'warning',
        message: `Post-meal Prediabetes: ${glucose} mg/dL`,
        guideline: 'RSSDI / ADA: 2hr Post-meal Glucose 140-199 mg/dL = Warning',
      };
    }
    return {
      status: 'normal',
      message: `Normal Post-meal Glucose: ${glucose} mg/dL`,
      guideline: 'RSSDI / ADA: 2hr Post-meal Glucose <140 mg/dL = Normal',
    };
  }
}

// O2 Saturation Guidelines (COPD/HF)
export function analyzeO2Sat(
  o2Sat: number,
  condition?: Condition
): VitalStatus {
  const isCOPDorHF = condition === 'COPD' || condition === 'Heart Failure';

  if (o2Sat < 85) {
    return {
      status: 'critical',
      message: `Severe Hypoxia: SpO2 ${o2Sat}%`,
      guideline: `${isCOPDorHF ? 'GOLD / AHA HF' : 'Standard'} Guidelines: SpO2 <85% = Severe Hypoxia (Critical)`,
    };
  }
  if (o2Sat >= 86 && o2Sat <= 90) {
    return {
      status: 'alert' as AlertStatus,
      message: `Moderate Hypoxia: SpO2 ${o2Sat}%`,
      guideline: `${isCOPDorHF ? 'GOLD / AHA HF' : 'Standard'} Guidelines: SpO2 86-90% = Moderate Hypoxia (Alert)`,
    };
  }
  if (o2Sat >= 91 && o2Sat <= 94) {
    return {
      status: 'warning',
      message: `Mild Hypoxia: SpO2 ${o2Sat}%`,
      guideline: `${isCOPDorHF ? 'GOLD / AHA HF' : 'Standard'} Guidelines: SpO2 91-94% = Mild Hypoxia (Warning)`,
    };
  }
  return {
    status: 'normal',
    message: `Normal SpO2: ${o2Sat}%`,
    guideline: 'Standard Guidelines: SpO2 ≥95% = Normal',
  };
}

// Weight Analysis (Heart Failure - AHA HF Guidelines)
export function analyzeWeight(
  currentWeight: number,
  previousReadings: number[],
  condition?: Condition
): VitalStatus {
  if (!previousReadings || previousReadings.length === 0) {
    return {
      status: 'normal',
      message: `Weight: ${currentWeight} kg`,
      guideline: 'AHA HF Guidelines: Baseline reading',
    };
  }

  const prev24h = previousReadings[previousReadings.length - 1];
  const gain24h = currentWeight - prev24h;

  if (condition === 'Heart Failure') {
    if (gain24h > 2) {
      return {
        status: 'alert' as AlertStatus,
        message: `Weight gain >2kg in 24h: +${gain24h.toFixed(1)} kg`,
        guideline: 'AHA HF Guidelines: Weight gain >2kg/24h = Alert (fluid retention risk)',
      };
    }

    if (previousReadings.length >= 2) {
      const prev48h = previousReadings[previousReadings.length - 2];
      const gain48h = currentWeight - prev48h;
      if (gain48h > 2.5) {
        return {
          status: 'critical',
          message: `Weight gain >2.5kg in 48h: +${gain48h.toFixed(1)} kg`,
          guideline: 'AHA HF Guidelines: Weight gain >2.5kg/48h = Critical (decompensation risk)',
        };
      }
    }
  }

  return {
    status: 'normal',
    message: `Weight: ${currentWeight} kg (stable)`,
    guideline: 'AHA HF Guidelines: Weight stable (no significant gain)',
  };
}

// Main exported function for analyzing any vital
export function analyzeVital(
  type: 'BP' | 'Glucose' | 'O2Sat' | 'Weight',
  value: number | { systolic: number; diastolic: number },
  condition?: Condition,
  previousReadings?: number[],
  glucoseType?: 'fasting' | 'post-meal'
): VitalStatus {
  switch (type) {
    case 'BP': {
      const bp = value as { systolic: number; diastolic: number };
      return analyzeBP(bp.systolic, bp.diastolic, condition);
    }
    case 'Glucose':
      return analyzeGlucose(value as number, glucoseType || 'fasting', condition);
    case 'O2Sat':
      return analyzeO2Sat(value as number, condition);
    case 'Weight':
      return analyzeWeight(value as number, previousReadings || [], condition);
    default:
      return {
        status: 'normal',
        message: 'Unknown vital type',
        guideline: 'N/A',
      };
  }
}

// Map internal status to AlertStatus
export function toAlertStatus(status: string): AlertStatus {
  if (status === 'alert') return 'warning'; // map 'alert' -> 'warning' for display
  return status as AlertStatus;
}
