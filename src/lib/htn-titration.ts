import { Comorbidity, ElevatedReading, EscalationRecommendation, EscalationReason, Medication, Patient, TitrationTarget } from '@/types';
import { getBPTarget } from './guidelines';

// Max doses per IGH-V Table 24 (2025-2026)
const MAX_DOSES: Record<string, { max: string; unit: string }> = {
  Amlodipine: { max: '10', unit: 'mg OD' },
  'S-Amlodipine': { max: '5', unit: 'mg OD' },
  Cilnidipine: { max: '10', unit: 'mg OD' },
  Telmisartan: { max: '80', unit: 'mg OD' },
  Losartan: { max: '100', unit: 'mg OD' },
  Valsartan: { max: '320', unit: 'mg OD' },
  Olmesartan: { max: '40', unit: 'mg OD' },
  Candesartan: { max: '32', unit: 'mg OD' },
  Irbesartan: { max: '300', unit: 'mg OD' },
  Azilsartan: { max: '80', unit: 'mg OD' },
  Ramipril: { max: '10', unit: 'mg OD' },
  Perindopril: { max: '8', unit: 'mg OD' },
  Enalapril: { max: '20', unit: 'mg BD' },
  Lisinopril: { max: '20', unit: 'mg OD' },
  Chlorthalidone: { max: '12.5', unit: 'mg OD' },
  Hydrochlorothiazide: { max: '12.5', unit: 'mg OD' },
  Indapamide: { max: '2.5', unit: 'mg OD' },
  Bisoprolol: { max: '10', unit: 'mg OD' },
  Nebivolol: { max: '5', unit: 'mg OD' },
  Metoprolol: { max: '100', unit: 'mg BD' },
  Carvedilol: { max: '50', unit: 'mg BD' },
  Spironolactone: { max: '50', unit: 'mg OD' },
  Eplerenone: { max: '50', unit: 'mg OD' },
  Doxazosin: { max: '4', unit: 'mg OD' },
};

function parseDoseMg(dose: string): number {
  const match = dose.match(/[\d.]+/);
  return match ? parseFloat(match[0]) : 0;
}

// Pick the single drug with the most room to titrate (lowest % of max)
function pickTitrationTarget(meds: Medication[]): TitrationTarget | null {
  let best: { med: Medication; ratio: number } | null = null;

  for (const med of meds) {
    const maxInfo = MAX_DOSES[med.name];
    if (!maxInfo) continue;
    const current = parseDoseMg(med.dose);
    const max = parseFloat(maxInfo.max);
    if (current >= max) continue;
    const ratio = current / max;
    if (!best || ratio < best.ratio) {
      best = { med, ratio };
    }
  }

  if (!best) return null;

  const maxInfo = MAX_DOSES[best.med.name]!;
  return {
    drugName: best.med.name,
    currentDose: best.med.dose,
    targetDose: `${maxInfo.max} ${maxInfo.unit}`,
    note: `Up-titrate ${best.med.name} first — it has the most headroom (${best.med.dose} → ${maxInfo.max} ${maxInfo.unit}). Reassess in ~2 weeks before adjusting other drugs (IGH-V Table 24 §3).`,
  };
}

function mostRecentMedStartDate(meds: Medication[]): Date | null {
  if (meds.length === 0) return null;
  const dates = meds.map((m) => new Date(m.startDate).getTime());
  return new Date(Math.max(...dates));
}

function daysBetween(a: Date, b: Date): number {
  return Math.abs(a.getTime() - b.getTime()) / (1000 * 60 * 60 * 24);
}

export function getEscalationRecommendation(patient: Patient): EscalationRecommendation {
  const vitals = [...patient.vitals]
    .filter((v) => v.systolic && v.diastolic)
    .reverse(); // most recent first

  const target = getBPTarget(patient.conditions, patient.comorbidities, patient.age);
  const now = vitals[0] ? new Date(vitals[0].date) : null;

  const elevatedReadings: ElevatedReading[] = [];
  let consecutiveSevere = 0;
  let consecutiveElevated = 0;
  let crisisDetected = false;
  let crisisReading: ElevatedReading | null = null;

  for (const v of vitals) {
    if (!v.systolic || !v.diastolic) break;
    if (now && daysBetween(new Date(v.date), now) > 5) break; // 5-day sustained window (IGH-V)

    if (v.systolic >= 180 || v.diastolic >= 120) {
      crisisDetected = true;
      crisisReading = { date: v.date, systolic: v.systolic, diastolic: v.diastolic };
      break;
    }

    if (v.systolic > target.sys || v.diastolic > target.dia) {
      if (v.systolic >= 160 || v.diastolic >= 100) {
        consecutiveSevere++;
      } else {
        consecutiveElevated++;
      }
      elevatedReadings.push({ date: v.date, systolic: v.systolic, diastolic: v.diastolic });
    } else {
      break; // a controlled reading breaks the sustained streak
    }
  }

  if (crisisReading) elevatedReadings.unshift(crisisReading);

  const currentStep = patient.htnStep ?? 1;

  const contraindications: string[] = [];
  if (patient.comorbidities.includes('Heart Failure (HFrEF)')) {
    contraindications.push('Non-dihydropyridine CCBs (verapamil, diltiazem) contraindicated in HFrEF; avoid pioglitazone if also on diabetes ladder');
  }
  if (patient.comorbidities.includes('Gout')) {
    contraindications.push('Avoid thiazide diuretics (D) — favor amlodipine (C) or losartan for A');
  }
  contraindications.push('Never combine: ACEi + ARB; two drugs from the same class; β-blocker + verapamil/diltiazem');

  let shouldEscalate = false;
  let reason: EscalationReason = 'none';
  let urgency: 'routine' | 'urgent' | 'immediate' = 'routine';
  let escalationThreshold = 3;
  const consecutiveElevatedCount = crisisDetected ? 1 : Math.max(consecutiveElevated, consecutiveSevere);

  if (crisisDetected) {
    shouldEscalate = true;
    reason = 'crisis';
    urgency = 'immediate';
    escalationThreshold = 1;
  } else if (consecutiveSevere >= 2) {
    shouldEscalate = true;
    reason = 'consecutive_severe';
    urgency = 'urgent';
    escalationThreshold = 2;
  } else if (consecutiveElevated >= 3) {
    shouldEscalate = true;
    reason = 'consecutive_elevated';
    urgency = 'routine';
    escalationThreshold = 3;
  }

  // Post-titration hold: trigger logic suspended 2 weeks after any medication change,
  // except a same-day hypertensive crisis, which is a safety alert, not a titration trigger.
  const lastChange = mostRecentMedStartDate(patient.medications);
  const onPostTitrationHold =
    !crisisDetected && lastChange !== null && now !== null && daysBetween(lastChange, now) < 14;
  if (onPostTitrationHold) {
    shouldEscalate = false;
  }

  const nextStep = Math.min(currentStep + 1, 6) as 1 | 2 | 3 | 4 | 5 | 6;

  const { recommendedAddition, recommendedRegimen, titrationTarget } = getNextStepRegimen(
    currentStep,
    patient.medications,
    patient.comorbidities
  );

  return {
    shouldEscalate,
    reason,
    currentStep,
    nextStep: shouldEscalate ? nextStep : currentStep,
    consecutiveElevatedCount,
    escalationThreshold,
    recommendedAddition,
    recommendedRegimen,
    elevatedReadings,
    titrationTarget,
    contraindications,
    guidelineReference: 'IGH-V (2025-2026), Fig. 14 — Step-care approach for combination therapy in hypertension',
    urgency,
    onPostTitrationHold,
  };
}

function getNextStepRegimen(
  currentStep: number,
  currentMeds: Medication[],
  comorbidities: Comorbidity[]
): { recommendedAddition: string; recommendedRegimen: string[]; titrationTarget: TitrationTarget | null } {
  const existingClasses = currentMeds.map((m) => m.drugClass);

  if (currentStep === 1) {
    const addition = getMissingDrugClass(existingClasses, comorbidities);
    return {
      recommendedAddition: addition,
      recommendedRegimen: [...currentMeds.map((m) => `${m.name} ${m.dose} ${m.frequency}`), `+ ${addition}`],
      titrationTarget: null,
    };
  }

  if (currentStep === 2) {
    const target = pickTitrationTarget(currentMeds);
    if (!target) {
      return {
        recommendedAddition: 'All drugs already at maximum doses — proceed to Step 4 (add MRA)',
        recommendedRegimen: currentMeds.map((m) => `${m.name} ${m.dose} ${m.frequency} ← already at max`),
        titrationTarget: null,
      };
    }
    return {
      recommendedAddition: `Up-titrate ${target.drugName} from ${target.currentDose} → ${target.targetDose} (IGH-V Step 3 — one drug at a time, reassess in ~2 weeks)`,
      recommendedRegimen: currentMeds.map((m) =>
        m.name === target.drugName
          ? `${m.name} ${m.dose} → ${target.targetDose} ⬆ (titrate first)`
          : `${m.name} ${m.dose} ${m.frequency} (unchanged)`
      ),
      titrationTarget: target,
    };
  }

  if (currentStep === 3) {
    const earlyMRA = comorbidities.includes('Heart Failure (HFrEF)');
    return {
      recommendedAddition: `Add Spironolactone 25 mg OD — ${earlyMRA ? 'HFrEF: MRA favored earlier than Step 4' : 'Resistant HTN confirmed (IGH-V Step 4)'}; use Eplerenone 25 mg OD if gynecomastia/hyperkalemia`,
      recommendedRegimen: [
        ...currentMeds.map((m) => `${m.name} ${m.dose} ${m.frequency}`),
        '+ Spironolactone 25 mg OD (new)',
      ],
      titrationTarget: null,
    };
  }

  if (currentStep === 4) {
    return {
      recommendedAddition: 'Add Doxazosin 1 mg OD (alpha-blocker) — IGH-V Step 5; up-titrate to 4 mg OD if tolerated; monitor for orthostatic hypotension. Consider ARNI or SGLT2i if not already on one.',
      recommendedRegimen: [
        ...currentMeds.map((m) => `${m.name} ${m.dose} ${m.frequency}`),
        '+ Doxazosin 1 mg OD (new) → titrate to 4 mg OD',
      ],
      titrationTarget: null,
    };
  }

  if (currentStep === 5) {
    return {
      recommendedAddition: 'Refer for renal denervation therapy evaluation — IGH-V Step 6 (confirmed resistant HTN only, after secondary-cause workup)',
      recommendedRegimen: [
        ...currentMeds.map((m) => `${m.name} ${m.dose} ${m.frequency}`),
        '→ Referral: Renal Denervation Therapy',
      ],
      titrationTarget: null,
    };
  }

  return {
    recommendedAddition: 'Already at maximum medical therapy — refer to hypertension specialist',
    recommendedRegimen: currentMeds.map((m) => `${m.name} ${m.dose} ${m.frequency}`),
    titrationTarget: null,
  };
}

function getMissingDrugClass(existing: string[], comorbidities: Comorbidity[]): string {
  const hasCCB = existing.includes('CCB');
  const hasACEorARB = existing.includes('ACE') || existing.includes('ARB');
  const hasDiuretic = existing.includes('Diuretic');
  const hasBeta = existing.includes('BetaBlocker');

  const hasHFrEF = comorbidities.includes('Heart Failure (HFrEF)');
  const hasGout = comorbidities.includes('Gout');
  const hasCVD = comorbidities.includes('Established CVD');
  const hasAF = comorbidities.includes('Atrial Fibrillation');

  if (!hasACEorARB) {
    return hasGout ? 'Losartan 50 mg OD (max 100 mg OD) — ARB favored over ACEi in gout' : 'Telmisartan 40 mg OD (max 80 mg OD) — anchor drug (A)';
  }
  if (hasHFrEF) {
    if (!hasBeta) return 'Bisoprolol 2.5 mg OD (max 10 mg OD) — HFrEF: build A + β-blocker + diuretic rather than default A+C';
    if (!hasDiuretic) return 'Furosemide/thiazide per fluid status — HFrEF diuretic backbone';
  }
  if (!hasCCB && !hasHFrEF) {
    return hasGout ? 'Amlodipine 2.5 mg OD (max 10 mg OD) — favored over thiazide in gout' : 'Amlodipine 2.5 mg OD (max 10 mg OD)';
  }
  if (!hasDiuretic) {
    return hasGout ? 'Avoid thiazide in gout — add Amlodipine or up-titrate ARB instead' : 'Chlorthalidone 6.25 mg OD (max 12.5 mg OD) — preferred diuretic per IGH-V';
  }
  if (!hasBeta && (hasCVD || hasAF)) {
    return 'Bisoprolol 2.5 mg OD (max 10 mg OD) — established CVD/AFib: β-blocker may be added at any step';
  }
  return 'Indapamide 1.5 mg OD (max 2.5 mg OD) — low metabolic side-effect diuretic';
}
