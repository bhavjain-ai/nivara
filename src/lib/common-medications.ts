// Commonly prescribed Indian-market medications per drug class, for the
// dashboard's "Add medication" dropdown (MedicationPanel.tsx) — keeps data
// entry fast for the common case while still allowing free text for
// anything not on the list. Names/classes match what mock-data.ts and the
// titration-ladder logic (htn-titration.ts, diabetes-titration.ts) already
// reference, so a doctor picking from here stays consistent with what the
// app's own escalation recommendations call drugs by.
export const COMMON_MEDICATIONS: Record<string, string[]> = {
  ACE: ['Ramipril', 'Enalapril', 'Perindopril', 'Lisinopril'],
  ARB: ['Telmisartan', 'Losartan', 'Olmesartan', 'Azilsartan'],
  CCB: ['Amlodipine', 'Cilnidipine', 'Nifedipine (ER)'],
  Diuretic: ['Chlorthalidone', 'Hydrochlorothiazide', 'Indapamide'],
  BetaBlocker: ['Metoprolol (ER)', 'Bisoprolol', 'Atenolol'],
  MRA: ['Spironolactone', 'Eplerenone'],
  AlphaBlocker: ['Doxazosin', 'Prazosin'],
  Central: ['Clonidine', 'Methyldopa'],
  ARNI: ['Sacubitril/Valsartan'],
  Biguanide: ['Metformin (SR)', 'Metformin (IR)'],
  SGLT2i: ['Dapagliflozin', 'Empagliflozin', 'Canagliflozin'],
  GLP1: ['Liraglutide', 'Dulaglutide', 'Semaglutide'],
  DPP4i: ['Sitagliptin', 'Vildagliptin', 'Teneligliptin'],
  Sulfonylurea: ['Glimepiride', 'Gliclazide (MR)'],
  TZD: ['Pioglitazone'],
  Insulin: ['Insulin Glargine', 'Insulin Degludec', 'Insulin Aspart', 'Premix Insulin (70/30)'],
  Other: [],
};
