// Standard marketed tablet/capsule strengths for the drugs listed in
// COMMON_MEDICATIONS (common-medications.ts), used to populate the dose
// picker in MedicationPanel.tsx so "Dose" isn't a blank free-text field for
// the common case.
//
// This is general, widely-published pharmacology reference data (the
// strengths a given generic is normally sold in), not patient-specific
// dosing guidance — it does NOT account for brand-specific formulations,
// combination products, or market changes, and has NOT been checked against
// current product monographs by a pharmacist or physician. Treat this list
// as a data-entry convenience, not a clinical source of truth: verify it
// against actual product labeling before relying on it, and the dose field
// always falls back to free text (via "Other") for anything not listed here
// or any strength this list gets wrong.
export const DRUG_DOSE_OPTIONS: Record<string, string[]> = {
  // ACE
  Ramipril: ['1.25mg', '2.5mg', '5mg', '10mg'],
  Enalapril: ['2.5mg', '5mg', '10mg', '20mg'],
  Perindopril: ['2mg', '4mg', '8mg'],
  Lisinopril: ['2.5mg', '5mg', '10mg', '20mg'],

  // ARB
  Telmisartan: ['20mg', '40mg', '80mg'],
  Losartan: ['25mg', '50mg', '100mg'],
  Olmesartan: ['10mg', '20mg', '40mg'],
  Azilsartan: ['20mg', '40mg', '80mg'],

  // CCB
  Amlodipine: ['2.5mg', '5mg', '10mg'],
  Cilnidipine: ['5mg', '10mg', '20mg'],
  'Nifedipine (ER)': ['10mg', '20mg', '30mg', '60mg'],

  // Diuretic
  Chlorthalidone: ['6.25mg', '12.5mg', '25mg'],
  Hydrochlorothiazide: ['12.5mg', '25mg', '50mg'],
  Indapamide: ['1.5mg', '2.5mg'],

  // BetaBlocker
  'Metoprolol (ER)': ['25mg', '50mg', '100mg'],
  Bisoprolol: ['2.5mg', '5mg', '10mg'],
  Atenolol: ['25mg', '50mg', '100mg'],

  // MRA
  Spironolactone: ['25mg', '50mg', '100mg'],
  Eplerenone: ['25mg', '50mg'],

  // AlphaBlocker
  Doxazosin: ['1mg', '2mg', '4mg', '8mg'],
  Prazosin: ['1mg', '2.5mg', '5mg'],

  // Central
  Clonidine: ['0.1mg', '0.2mg', '0.3mg'],
  Methyldopa: ['250mg', '500mg'],

  // ARNI
  'Sacubitril/Valsartan': ['50mg', '100mg', '200mg'],

  // Biguanide
  'Metformin (SR)': ['500mg', '850mg', '1000mg'],
  'Metformin (IR)': ['500mg', '850mg', '1000mg'],

  // SGLT2i
  Dapagliflozin: ['5mg', '10mg'],
  Empagliflozin: ['10mg', '25mg'],
  Canagliflozin: ['100mg', '300mg'],

  // GLP1 (injectable)
  Liraglutide: ['0.6mg', '1.2mg', '1.8mg'],
  Dulaglutide: ['0.75mg', '1.5mg', '3mg', '4.5mg'],
  Semaglutide: ['0.25mg', '0.5mg', '1mg', '2mg'],

  // DPP4i
  Sitagliptin: ['25mg', '50mg', '100mg'],
  Vildagliptin: ['50mg'],
  Teneligliptin: ['20mg'],

  // Sulfonylurea
  Glimepiride: ['1mg', '2mg', '3mg', '4mg'],
  'Gliclazide (MR)': ['30mg', '60mg', '90mg'],

  // TZD
  Pioglitazone: ['15mg', '30mg', '45mg'],
};

// Insulins aren't sold in a fixed set of tablet-like strengths — the dose is
// a continuously titrated unit count specific to the patient, so a discrete
// preset list doesn't fit. Drugs in this set get a numeric input with a
// fixed "units" suffix instead of the DRUG_DOSE_OPTIONS dropdown.
export const UNIT_DOSED_DRUGS = new Set<string>([
  'Insulin Glargine',
  'Insulin Degludec',
  'Insulin Aspart',
  'Premix Insulin (70/30)',
]);

// Common clinical dosing-frequency phrasing, for the frequency picker.
// "Other" (free text) stays available for anything more specific, matching
// how the medication-name picker handles a drug not on its list.
export const FREQUENCY_OPTIONS: string[] = [
  'Once daily',
  'Once daily (morning)',
  'Once daily (evening)',
  'Once daily with breakfast',
  'Once daily at bedtime',
  'Twice daily',
  'Twice daily with meals',
  'Three times daily',
  'Four times daily',
  'Once weekly',
  'Every alternate day',
  'As needed',
];
