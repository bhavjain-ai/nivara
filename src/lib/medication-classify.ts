// Which drug classes belong to the diabetes regimen vs. the hypertension
// one — shared between MedicationPanel.tsx (splitting a patient's
// medications into the two titration panels) and the medication API routes
// (deciding medication_changes.related_condition for a new/edited/removed
// medication), so the two stay in sync.
export const DIABETES_DRUG_CLASSES = ['Biguanide', 'SGLT2i', 'GLP1', 'DPP4i', 'Sulfonylurea', 'TZD', 'Insulin'];

export function conditionForDrugClass(drugClass: string): 'Hypertension' | 'Diabetes' {
  return DIABETES_DRUG_CLASSES.includes(drugClass) ? 'Diabetes' : 'Hypertension';
}
