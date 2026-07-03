import { Patient, Medication, EscalationRecommendation, EscalationReason } from '@/types';

// IGH V Step-Care: A=ACE/ARB, B=BetaBlocker, C=CCB, D=Diuretic
// Step 1: Dual combination (low dose)
// Step 2: Triple (low dose)
// Step 3: Max tolerated triple
// Step 4: + MRA (spironolactone/eplerenone) for resistant HTN
// Step 5: + Alpha-blocker or centrally acting agent
// Step 6: Renal denervation (flag only, can't prescribe)

export function getEscalationRecommendation(patient: Patient): EscalationRecommendation {
  const vitals = [...patient.vitals].reverse(); // most recent first
  let consecutiveSevere = 0;
  let consecutiveElevated = 0;
  let crisisDetected = false;

  for (const v of vitals) {
    if (!v.systolic || !v.diastolic) break;
    if (v.systolic >= 180 || v.diastolic >= 120) { crisisDetected = true; break; }
    if (v.systolic >= 160 || v.diastolic >= 100) { consecutiveSevere++; }
    else if (v.systolic >= 140 || v.diastolic >= 90) { consecutiveElevated++; }
    else break; // controlled reading breaks the streak
  }

  const currentStep = patient.treatmentStep || 1;
  const condition = patient.condition;

  // Build contraindications list based on condition
  const contraindications: string[] = [];
  if (condition === 'COPD') {
    contraindications.push('Beta-blockers relatively contraindicated in COPD (bronchospasm risk) — prefer ACE/ARB + CCB + Diuretic');
  }
  if (condition === 'Heart Failure') {
    contraindications.push('Non-dihydropyridine CCBs (verapamil, diltiazem) contraindicated in HF');
    contraindications.push('Use loop diuretics (furosemide) rather than thiazides in HF with fluid overload');
  }

  let shouldEscalate = false;
  let reason: EscalationReason = 'none';
  let urgency: 'routine' | 'urgent' | 'immediate' = 'routine';
  let escalationThreshold = 3;
  const consecutiveElevatedCount = Math.max(consecutiveElevated, consecutiveSevere);

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

  const { recommendedAddition, recommendedRegimen } = getNextStepRegimen(
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
    contraindications,
    guidelineReference: 'IGH V (2025-2026), Figure 14 — Step-care approach for combination therapy in hypertension',
    urgency,
  };
}

function getNextStepRegimen(
  currentStep: number,
  currentMeds: Medication[],
  condition: string
): { recommendedAddition: string; recommendedRegimen: string[] } {
  const existingNames = currentMeds.map((m) => m.drugClass);
  const hasCOPD = condition === 'COPD';
  const hasHF = condition === 'Heart Failure';

  if (currentStep === 1) {
    const missing = getMissingDrugClass(existingNames, hasCOPD, hasHF);
    return {
      recommendedAddition: missing,
      recommendedRegimen: [...currentMeds.map((m) => `${m.name} ${m.dose}`), missing],
    };
  }
  if (currentStep === 2) {
    return {
      recommendedAddition:
        'Up-titrate existing triple therapy to maximally tolerated doses per IGH V Step 3',
      recommendedRegimen: currentMeds.map((m) => `${m.name} ${m.dose} → increase to max tolerated`),
    };
  }
  if (currentStep === 3) {
    return {
      recommendedAddition:
        'Add Spironolactone 25 mg OD (MRA) — Resistant HTN, per IGH V Step 4 / PATHWAY-2 trial',
      recommendedRegimen: [
        ...currentMeds.map((m) => `${m.name} ${m.dose}`),
        'Spironolactone 25 mg OD',
      ],
    };
  }
  if (currentStep === 4) {
    return {
      recommendedAddition:
        'Add Doxazosin 1 mg OD (alpha-blocker) — IGH V Step 5; monitor for orthostatic hypotension',
      recommendedRegimen: [
        ...currentMeds.map((m) => `${m.name} ${m.dose}`),
        'Doxazosin 1 mg OD',
      ],
    };
  }
  if (currentStep === 5) {
    return {
      recommendedAddition:
        'Refer for Renal Denervation Therapy evaluation — IGH V Step 6 (device-based intervention)',
      recommendedRegimen: [
        ...currentMeds.map((m) => `${m.name} ${m.dose}`),
        'Refer: Renal Denervation Therapy',
      ],
    };
  }
  return {
    recommendedAddition:
      'Already at maximum medical therapy — refer to hypertension specialist',
    recommendedRegimen: currentMeds.map((m) => `${m.name} ${m.dose}`),
  };
}

function getMissingDrugClass(existing: string[], hasCOPD: boolean, hasHF: boolean): string {
  const hasCCB = existing.includes('CCB');
  const hasACE = existing.includes('ACE') || existing.includes('ARB');
  const hasDiuretic = existing.includes('Diuretic');
  const hasBeta = existing.includes('BetaBlocker');

  if (!hasDiuretic) return 'Add Chlorthalidone 12.5 mg OD (preferred diuretic per IGH V)';
  if (!hasCCB) return 'Add Amlodipine 5 mg OD (CCB)';
  if (!hasACE) return 'Add Telmisartan 40 mg OD (ARB)';
  if (!hasBeta && !hasCOPD && !hasHF) return 'Add Bisoprolol 2.5 mg OD (selective beta-blocker)';
  return 'Add Indapamide 1.5 mg OD (alternative diuretic)';
}
