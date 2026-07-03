import { Patient, Medication, EscalationRecommendation, EscalationReason, ElevatedReading, TitrationTarget } from '@/types';

// Max doses per IGH V Table 24 (2025-2026)
const MAX_DOSES: Record<string, { max: string; unit: string }> = {
  Amlodipine: { max: '10', unit: 'mg OD' },
  'S-Amlodipine': { max: '5', unit: 'mg OD' },
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
  Chlorthalidone: { max: '25', unit: 'mg OD' },
  Hydrochlorothiazide: { max: '12.5', unit: 'mg OD' },
  Indapamide: { max: '2.5', unit: 'mg OD' },
  Bisoprolol: { max: '10', unit: 'mg OD' },
  Nebivolol: { max: '5', unit: 'mg OD' },
  Metoprolol: { max: '100', unit: 'mg BD' },
  Carvedilol: { max: '25', unit: 'mg BD' },
  Spironolactone: { max: '50', unit: 'mg OD' },
  Eplerenone: { max: '50', unit: 'mg OD' },
  Furosemide: { max: '80', unit: 'mg OD' },
  Doxazosin: { max: '4', unit: 'mg OD' },
};

function parseDoseMg(dose: string): number {
  const match = dose.match(/[\d.]+/);
  return match ? parseFloat(match[0]) : 0;
}

function isAtMaxDose(med: Medication): boolean {
  const maxInfo = MAX_DOSES[med.name];
  if (!maxInfo) return false;
  const current = parseDoseMg(med.dose);
  const max = parseFloat(maxInfo.max);
  return current >= max;
}

// Pick the single drug with the most room to titrate (lowest % of max)
function pickTitrationTarget(meds: Medication[]): TitrationTarget | null {
  let best: { med: Medication; ratio: number } | null = null;

  for (const med of meds) {
    const maxInfo = MAX_DOSES[med.name];
    if (!maxInfo) continue;
    const current = parseDoseMg(med.dose);
    const max = parseFloat(maxInfo.max);
    if (current >= max) continue; // already at max
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
    note: `Up-titrate ${best.med.name} first — it has the most headroom (${best.med.dose} → ${maxInfo.max} ${maxInfo.unit}). Reassess in 2 weeks before adjusting other drugs. Do NOT up-titrate all drugs simultaneously (IGH V: gradual reduction preferred).`,
  };
}

export function getEscalationRecommendation(patient: Patient): EscalationRecommendation {
  const vitals = [...patient.vitals].reverse(); // most recent first

  const elevatedReadings: ElevatedReading[] = [];
  let consecutiveSevere = 0;
  let consecutiveElevated = 0;
  let crisisDetected = false;
  let crisisReading: ElevatedReading | null = null;

  for (const v of vitals) {
    if (!v.systolic || !v.diastolic) break;

    if (v.systolic >= 180 || v.diastolic >= 120) {
      crisisDetected = true;
      crisisReading = { date: v.date, systolic: v.systolic, diastolic: v.diastolic };
      break;
    }

    if (v.systolic >= 160 || v.diastolic >= 100) {
      consecutiveSevere++;
      elevatedReadings.push({ date: v.date, systolic: v.systolic, diastolic: v.diastolic });
    } else if (v.systolic >= 140 || v.diastolic >= 90) {
      consecutiveElevated++;
      elevatedReadings.push({ date: v.date, systolic: v.systolic, diastolic: v.diastolic });
    } else {
      break; // controlled reading breaks the streak
    }
  }

  if (crisisReading) elevatedReadings.unshift(crisisReading);

  const currentStep = patient.treatmentStep || 1;
  const condition = patient.condition;

  const contraindications: string[] = [];
  if (condition === 'COPD') {
    contraindications.push('Beta-blockers relatively contraindicated in COPD — prefer ACE/ARB + CCB + Diuretic pathway');
  }
  if (condition === 'Heart Failure') {
    contraindications.push('Non-dihydropyridine CCBs (verapamil, diltiazem) contraindicated in HF');
    contraindications.push('Prefer loop diuretics (furosemide) over thiazides in HF with fluid overload');
  }

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

  const nextStep = Math.min(currentStep + 1, 6) as 1 | 2 | 3 | 4 | 5 | 6;

  const { recommendedAddition, recommendedRegimen, titrationTarget } = getNextStepRegimen(
    currentStep,
    patient.medications,
    condition
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
    guidelineReference: 'IGH V (2025-2026), Figure 14 — Step-care approach for combination therapy in hypertension',
    urgency,
  };
}

function getNextStepRegimen(
  currentStep: number,
  currentMeds: Medication[],
  condition: string
): { recommendedAddition: string; recommendedRegimen: string[]; titrationTarget: TitrationTarget | null } {
  const existingClasses = currentMeds.map((m) => m.drugClass);
  const hasCOPD = condition === 'COPD';
  const hasHF = condition === 'Heart Failure';

  if (currentStep === 1) {
    const addition = getMissingDrugClass(existingClasses, hasCOPD, hasHF);
    return {
      recommendedAddition: addition,
      recommendedRegimen: [...currentMeds.map((m) => `${m.name} ${m.dose} ${m.frequency}`), `+ ${addition}`],
      titrationTarget: null,
    };
  }

  if (currentStep === 2) {
    // Step 3: Up-titrate ONE drug — the one with the most headroom
    const target = pickTitrationTarget(currentMeds);
    if (!target) {
      return {
        recommendedAddition: 'All drugs already at maximum doses — proceed to Step 4 (add MRA)',
        recommendedRegimen: currentMeds.map((m) => `${m.name} ${m.dose} ${m.frequency} ← already at max`),
        titrationTarget: null,
      };
    }
    return {
      recommendedAddition: `Up-titrate ${target.drugName} from ${target.currentDose} → ${target.targetDose} (IGH V Step 3 — one drug at a time, reassess in 2 weeks)`,
      recommendedRegimen: currentMeds.map((m) =>
        m.name === target.drugName
          ? `${m.name} ${m.dose} → ${target.targetDose} ⬆ (titrate first)`
          : `${m.name} ${m.dose} ${m.frequency} (unchanged)`
      ),
      titrationTarget: target,
    };
  }

  if (currentStep === 3) {
    return {
      recommendedAddition: 'Add Spironolactone 25 mg OD — Resistant HTN (IGH V Step 4 / PATHWAY-2 trial: superior to doxazosin/bisoprolol as 4th agent)',
      recommendedRegimen: [
        ...currentMeds.map((m) => `${m.name} ${m.dose} ${m.frequency}`),
        '+ Spironolactone 25 mg OD (new)',
      ],
      titrationTarget: null,
    };
  }

  if (currentStep === 4) {
    return {
      recommendedAddition: 'Add Doxazosin 1 mg OD (alpha-blocker) — IGH V Step 5; up-titrate to 4 mg OD if tolerated; monitor for orthostatic hypotension',
      recommendedRegimen: [
        ...currentMeds.map((m) => `${m.name} ${m.dose} ${m.frequency}`),
        '+ Doxazosin 1 mg OD (new) → titrate to 4 mg OD',
      ],
      titrationTarget: null,
    };
  }

  if (currentStep === 5) {
    return {
      recommendedAddition: 'Refer for Renal Denervation Therapy evaluation — IGH V Step 6',
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

function getMissingDrugClass(existing: string[], hasCOPD: boolean, hasHF: boolean): string {
  const hasCCB = existing.includes('CCB');
  const hasACEorARB = existing.includes('ACE') || existing.includes('ARB');
  const hasDiuretic = existing.includes('Diuretic');
  const hasBeta = existing.includes('BetaBlocker');

  // Preferred triple per IGH V / ACCOMPLISH: ACE/ARB + CCB + Diuretic
  if (!hasDiuretic) return 'Chlorthalidone 12.5 mg OD (max 25 mg OD) — preferred diuretic per IGH V';
  if (!hasCCB) return 'Amlodipine 5 mg OD (max 10 mg OD)';
  if (!hasACEorARB) return 'Telmisartan 40 mg OD (max 80 mg OD)';
  if (!hasBeta && !hasCOPD && !hasHF) return 'Bisoprolol 2.5 mg OD (max 10 mg OD) — selective beta-blocker';
  return 'Indapamide 1.5 mg OD (max 2.5 mg OD) — low metabolic side-effect diuretic';
}
