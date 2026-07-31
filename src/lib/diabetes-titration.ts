import { Comorbidity, DiabetesEscalationRecommendation, DiabetesStep, Medication, Patient } from '@/types';
import { getGlucoseTargets } from './guidelines';

const STEP_LABELS: Record<DiabetesStep, string> = {
  metformin: 'Step 1 — Metformin + Lifestyle',
  dual: 'Step 2 — Dual Therapy',
  triple: 'Step 3 — Triple Therapy',
  'pioglitazone-trial': 'Step 4 — Pioglitazone Trial',
  'insulin-basal': 'Insulin — Basal Only',
  'insulin-basal-plus': 'Insulin — Basal-Plus',
  'insulin-basal-bolus': 'Insulin — Basal-Bolus',
  'insulin-premix': 'Insulin — Premixed',
};

export function getDiabetesStepLabel(step: DiabetesStep): string {
  return STEP_LABELS[step];
}

function daysBetween(a: Date, b: Date): number {
  return Math.abs(a.getTime() - b.getTime()) / (1000 * 60 * 60 * 24);
}

function mostRecentMedStartDate(meds: Medication[]): Date | null {
  if (meds.length === 0) return null;
  return new Date(Math.max(...meds.map((m) => new Date(m.startDate).getTime())));
}

// Insulin Selection & Titration — starting dose, first matching rule wins
export function computeInsulinStartingDose(patient: Patient): { units: number; rule: string } {
  const higherHypoRisk = patient.comorbidities.includes('Higher Hypoglycemia Risk');
  const weight = patient.weightKg ?? 60; // 6/12/18-unit reference table uses a 60kg reference adult

  if (patient.age >= 75 || higherHypoRisk) {
    const units = Math.round(weight * 0.1);
    return { units, rule: '0.1 units/kg/day — age ≥75, eGFR <45, or a Level 2/3 hypoglycemic event in the past 12 months' };
  }
  // Rule 2 (HbA1c ≥10% AND BMI ≥30) requires BMI, not tracked on this dashboard — falls through to default.
  const units = Math.round(weight * 0.2);
  return { units, rule: '0.2 units/kg/day — default starting dose' };
}

export function getDiabetesEscalationRecommendation(patient: Patient): DiabetesEscalationRecommendation {
  if (!patient.diabetesStep || !patient.hba1cTier) {
    return {
      shouldEscalate: false,
      currentStep: 'metformin',
      currentStepLabel: 'N/A',
      sustainedHighReadings: [],
      glucoseReadingsTriggering: [],
      recommendedAddition: '',
      recommendedRegimen: [],
      insulinTrigger: null,
      contraindications: [],
      guidelineReference: '',
      urgency: 'routine',
      onPostTitrationHold: false,
    };
  }

  const targets = getGlucoseTargets(patient.hba1cTier.tier);
  const fastingReadings = [...patient.vitals]
    .filter((v) => v.glucose && v.glucoseType === 'fasting')
    .reverse(); // most recent first

  const now = fastingReadings[0] ? new Date(fastingReadings[0].date) : null;
  const glucoseReadingsTriggering: { date: string; glucose: number }[] = [];
  let consecutiveHigh = 0;

  for (const v of fastingReadings) {
    if (!v.glucose) break;
    if (now && daysBetween(new Date(v.date), now) > 5) break;
    if (v.glucose > targets.fastingHigh) {
      consecutiveHigh++;
      glucoseReadingsTriggering.push({ date: v.date, glucose: v.glucose });
    } else {
      break;
    }
  }

  const latestFasting = fastingReadings[0]?.glucose;
  let insulinTrigger: string | null = null;
  if (latestFasting && latestFasting > 300) {
    insulinTrigger = 'Glucose >300 mg/dL — bypass to insulin per RSSDI/ADA (verify no ketosis or catabolic symptoms first)';
  }

  let shouldEscalate = consecutiveHigh >= 3 || insulinTrigger !== null;
  const urgency: 'routine' | 'urgent' | 'immediate' = insulinTrigger ? 'urgent' : 'routine';

  const lastChange = mostRecentMedStartDate(patient.medications);
  const onPostTitrationHold =
    !insulinTrigger && lastChange !== null && now !== null && daysBetween(lastChange, now) < 14;
  if (onPostTitrationHold) shouldEscalate = false;

  const { recommendedAddition, recommendedRegimen, contraindications } = getNextStepRegimen(
    patient.diabetesStep,
    patient.medications,
    patient.comorbidities,
    patient
  );

  return {
    shouldEscalate,
    currentStep: patient.diabetesStep,
    currentStepLabel: getDiabetesStepLabel(patient.diabetesStep),
    sustainedHighReadings: [],
    glucoseReadingsTriggering,
    recommendedAddition,
    recommendedRegimen,
    insulinTrigger,
    contraindications,
    guidelineReference: 'RSSDI Clinical Practice Recommendations 2022/2024; ADA Standards of Care 2026',
    urgency,
    onPostTitrationHold,
  };
}

function getNextStepRegimen(
  step: DiabetesStep,
  meds: Medication[],
  comorbidities: Comorbidity[],
  patient: Patient
): { recommendedAddition: string; recommendedRegimen: string[]; contraindications: string[] } {
  const hasSGLT2 = meds.some((m) => m.drugClass === 'SGLT2i');
  const hasGLP1 = meds.some((m) => m.drugClass === 'GLP1');
  const hasDPP4 = meds.some((m) => m.drugClass === 'DPP4i');
  const hasSU = meds.some((m) => m.drugClass === 'Sulfonylurea');

  const hasCVDorHForDKD =
    comorbidities.includes('Established CVD') ||
    comorbidities.includes('Heart Failure (HFrEF)') ||
    comorbidities.includes('DKD');
  const elderlyOrHypoRisk = comorbidities.includes('Elderly') || comorbidities.includes('Higher Hypoglycemia Risk');
  const costSensitive = comorbidities.includes('Cost-Sensitive');
  const contraindications: string[] = [];

  const regimenBase = meds.map((m) => `${m.name} ${m.dose} ${m.frequency}`);

  if (step === 'metformin') {
    let addition: string;
    if (hasCVDorHForDKD) {
      const hf = comorbidities.includes('Heart Failure (HFrEF)') || comorbidities.includes('DKD');
      addition = hf
        ? 'Add Empagliflozin 10 mg OD (SGLT2i) — heart failure/DKD, organ-protective regardless of glycemic control'
        : 'Add oral Semaglutide 3 mg OD (GLP-1) — established ASCVD, organ-protective add-on';
    } else if (elderlyOrHypoRisk) {
      addition = 'Add Sitagliptin 100 mg OD (DPP-4i) — elderly/hypoglycemia risk, preferred over sulfonylurea';
    } else if (costSensitive) {
      addition = 'Add Glimepiride 1 mg OD (sulfonylurea) — cost-sensitive; avoid glibenclamide';
    } else {
      addition = 'Add Sitagliptin 100 mg OD (DPP-4i) or Empagliflozin 10 mg OD (SGLT2i) per patient preference/access';
    }
    return { recommendedAddition: addition, recommendedRegimen: [...regimenBase, `+ ${addition}`], contraindications };
  }

  if (step === 'dual') {
    if (hasDPP4 && !hasGLP1) contraindications.push('Avoid combining DPP-4i + GLP-1 — redundant mechanism');
    let addition = 'Add a third complementary class (avoid DPP-4i + GLP-1 combination)';
    if (!hasSGLT2 && hasCVDorHForDKD) addition = 'Add Dapagliflozin 5 mg OD (SGLT2i) — organ-protective, not yet on board';
    else if (!hasSU && costSensitive) addition = 'Add Gliclazide MR 30 mg OD (sulfonylurea) — cost-sensitive triple therapy';
    else if (!hasDPP4 && elderlyOrHypoRisk && !hasGLP1) addition = 'Add Linagliptin 5 mg OD (DPP-4i) — elderly/hypoglycemia risk';
    return { recommendedAddition: addition, recommendedRegimen: [...regimenBase, `+ ${addition}`], contraindications };
  }

  if (step === 'triple') {
    const latestHbA1c = patient.hba1cReadings[patient.hba1cReadings.length - 1]?.value;
    const eligibleForPioglitazone =
      latestHbA1c !== undefined &&
      latestHbA1c <= 8.5 &&
      !comorbidities.includes('Heart Failure (HFrEF)');
    if (eligibleForPioglitazone) {
      contraindications.push('Contraindicated in HFrEF, proliferative retinopathy, active bladder cancer/unexplained hematuria, high fracture risk');
      return {
        recommendedAddition: 'Trial Pioglitazone 15 mg OD → 30 mg after 4–8 weeks (HbA1c ≤8.5% on optimised triple therapy, patient prefers to defer insulin). Stop rule: no improvement at 12 weeks → insulin.',
        recommendedRegimen: [...regimenBase, '+ Pioglitazone 15 mg OD (trial, 12-week stop rule)'],
        contraindications,
      };
    }
    const dose = computeInsulinStartingDose(patient);
    return {
      recommendedAddition: `Start basal insulin (glargine/degludec preferred) — ${dose.units} units/day (${dose.rule}); continue metformin; halve sulfonylurea dose if on one`,
      recommendedRegimen: [...regimenBase, `+ Basal insulin ${dose.units} units OD (new)`],
      contraindications,
    };
  }

  if (step === 'pioglitazone-trial') {
    const dose = computeInsulinStartingDose(patient);
    return {
      recommendedAddition: `No improvement at 12 weeks on pioglitazone → stop and start basal insulin, ${dose.units} units/day (${dose.rule})`,
      recommendedRegimen: [...regimenBase.filter((r) => !r.includes('Pioglitazone')), `+ Basal insulin ${dose.units} units OD (new)`],
      contraindications,
    };
  }

  if (step === 'insulin-basal') {
    return {
      recommendedAddition: 'Basal titration: ↑2 units (or 10%) every 3–7 days if FBG above target on 2 consecutive days with no hypoglycemia. Add prandial ("basal-plus") if FBG at target but HbA1c or postprandial glucose remain above target, or basal dose reaches ≈0.5 units/kg/day.',
      recommendedRegimen: regimenBase,
      contraindications,
    };
  }

  return {
    recommendedAddition: 'Continue current insulin regimen; titrate prandial doses ↑1–2 units every 3–7 days per 2-hr postprandial glucose at that meal',
    recommendedRegimen: regimenBase,
    contraindications,
  };
}
