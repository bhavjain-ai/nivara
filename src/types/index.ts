export type Condition = 'Hypertension' | 'Diabetes';

// Comorbidity/risk tags that modify the HTN and Diabetes titration ladders
// (IGH-V Comorbidity Modifiers table; RSSDI/ADA Diabetes Comorbidity Modifiers table)
export type Comorbidity =
  | 'Established CVD'
  | 'Heart Failure (HFrEF)'
  | 'DKD'
  | 'CKD'
  | 'Elderly'
  | 'Higher Hypoglycemia Risk'
  | 'Cost-Sensitive'
  | 'Gout'
  | 'Atrial Fibrillation'
  | 'Frail / Orthostatic Hypotension'
  | 'BMI >= 27 with weight-related comorbidity';

export interface Medication {
  name: string;
  genericName: string;
  drugClass:
    | 'ACE'
    | 'ARB'
    | 'CCB'
    | 'Diuretic'
    | 'BetaBlocker'
    | 'MRA'
    | 'AlphaBlocker'
    | 'Central'
    | 'ARNI'
    | 'Biguanide'
    | 'SGLT2i'
    | 'GLP1'
    | 'DPP4i'
    | 'Sulfonylurea'
    | 'TZD'
    | 'Insulin'
    | 'Other';
  dose: string;
  frequency: string;
  startDate: string;
}

export interface MedicationStep {
  step: 1 | 2 | 3 | 4 | 5 | 6;
  label: string;
  drugs: Medication[];
}

export type EscalationReason = 'consecutive_elevated' | 'consecutive_severe' | 'crisis' | 'none';

export interface ElevatedReading {
  date: string;
  systolic: number;
  diastolic: number;
}

export interface TitrationTarget {
  drugName: string;
  currentDose: string;
  targetDose: string; // specific max dose from IGH-V Table 24
  note: string;
}

export interface EscalationRecommendation {
  shouldEscalate: boolean;
  reason: EscalationReason;
  currentStep: number;
  nextStep: number;
  consecutiveElevatedCount: number;
  escalationThreshold: number;
  recommendedAddition: string;
  recommendedRegimen: string[];
  elevatedReadings: ElevatedReading[]; // actual dates + values that triggered this
  titrationTarget: TitrationTarget | null; // one drug to up-titrate
  contraindications: string[];
  guidelineReference: string;
  urgency: 'routine' | 'urgent' | 'immediate';
  onPostTitrationHold: boolean; // trigger logic suspended 2 weeks after any med change
}

// --- Diabetes titration ---

export type DiabetesStep =
  | 'metformin'
  | 'dual'
  | 'triple'
  | 'pioglitazone-trial'
  | 'insulin-basal'
  | 'insulin-basal-plus'
  | 'insulin-basal-bolus'
  | 'insulin-premix';

export interface DiabetesEscalationRecommendation {
  shouldEscalate: boolean;
  currentStep: DiabetesStep;
  currentStepLabel: string;
  sustainedHighReadings: ElevatedReading[]; // reused shape: systolic/diastolic unused, glucose stored via message
  glucoseReadingsTriggering: { date: string; glucose: number }[];
  recommendedAddition: string;
  recommendedRegimen: string[];
  insulinTrigger: string | null; // reason for bypassing to insulin, if applicable
  contraindications: string[];
  guidelineReference: string;
  urgency: 'routine' | 'urgent' | 'immediate';
  onPostTitrationHold: boolean;
}

export type AlertStatus = 'critical' | 'warning' | 'stable' | 'normal';

export interface VitalReading {
  date: string; // ISO date string
  systolic?: number;
  diastolic?: number;
  glucose?: number;
  glucoseType?: 'fasting' | 'post-meal';
}

export interface HbA1cReading {
  date: string;
  value: number; // percent
}

export interface Alert {
  id: string;
  patientId: string;
  patientName: string;
  type: 'BP' | 'Glucose';
  message: string;
  severity: AlertStatus;
  timestamp: string;
  acknowledged: boolean;
}

// --- HbA1c / glucose individualization (RSSDI 2022/2024, ADA 2026) ---

export interface HbA1cTierInfo {
  tier: 1 | 2 | 3;
  target: string; // e.g. "6.5%"
  targetValue: number; // numeric ceiling used for "at target" comparisons
}

export type GlucosePopulationTier = 'standard' | 'relaxed';

export interface GlucoseTargetRange {
  population: GlucosePopulationTier;
  fastingLow: number;
  fastingHigh: number;
  postprandialHigh: number;
}

// --- Lifestyle coaching / care-coordinator outreach ---

export type CoachingTier = 'High-touch' | 'Moderate-touch' | 'Maintenance-touch';

export type CoordinatorRole = 'Lifestyle Coach' | 'Nurse';

export type OutreachTopic =
  | 'Diet'
  | 'Physical Activity'
  | 'Medication Adherence'
  | 'Tobacco/Alcohol Use'
  | 'Sleep & Stress'
  | 'Device/Monitoring Support';

export interface OutreachCall {
  id: string;
  date: string;
  coordinatorName: string;
  coordinatorRole: CoordinatorRole;
  callType: 'Week 1 Initial Assessment' | 'Tier Check-in' | 'Week 12 Closing Assessment' | 'Nurse Medication Check-in';
  durationMin: number;
  topics: OutreachTopic[];
  dietNotes?: string;
  exerciseNotes?: string;
  medAdherenceNotes?: string;
  summary: string;
}

export type SmartGoalCategory = 'Diet' | 'Physical Activity' | 'Medication Adherence' | 'Tobacco/Alcohol Use';
export type SmartGoalStatus = 'On Track' | 'At Risk' | 'Met' | 'Partially Met' | 'Not Met';

export interface SmartGoal {
  id: string;
  category: SmartGoalCategory;
  description: string; // e.g. "Cut down added salt in diet over the next 2 weeks"
  setDate: string;
  targetDate: string;
  status: SmartGoalStatus;
  progressNote?: string;
}

export interface Patient {
  id: string;
  name: string;
  age: number;
  gender: 'Male' | 'Female';
  conditions: Condition[];
  comorbidities: Comorbidity[];
  city: string;
  phoneNumber: string;
  physicianName: string;
  enrollmentDate: string;
  weightKg?: number; // baseline demographic attribute — used for insulin dose calc, not a tracked vital
  vitals: VitalReading[];
  hba1cReadings: HbA1cReading[];
  hba1cTier: HbA1cTierInfo | null; // null if patient has no diabetes
  alerts: Alert[];
  alertStatus: AlertStatus;
  lastReadingTime: string; // "X minutes/hours ago"
  medications: Medication[];
  htnStep: number | null; // 1-6, null if patient has no hypertension
  diabetesStep: DiabetesStep | null; // null if patient has no diabetes
  coachingTier: CoachingTier;
  coachingCallsCompleted: number;
  coachingCallsTarget: number; // fixed per tier: 14 High / 8 Moderate / 5 Maintenance (incl. Week 1 & 12)
  outreachLog: OutreachCall[];
  smartGoals: SmartGoal[];
}

export interface VitalStatus {
  status: AlertStatus;
  message: string;
  guideline: string;
}

export interface PatientSummary {
  id: string;
  name: string;
  age: number;
  conditions: Condition[];
  city: string;
  alertStatus: AlertStatus;
  lastReadingTime: string;
  latestVitals: {
    bp?: string;
    glucose?: number;
    glucoseType?: 'fasting' | 'post-meal';
  };
  coachingTier: CoachingTier;
  coachingCallsCompleted: number;
  coachingCallsTarget: number;
}

export interface AIInsight {
  summary: string;
  riskLevel: 'Low' | 'Moderate' | 'High' | 'Critical';
  recommendations: string[];
  alertTriggers: string[];
  guidelinesReferenced: string[];
}

export interface AnalyzeVitalsRequest {
  patient: {
    name: string;
    age: number;
    conditions: Condition[];
    gender: string;
  };
  latestVitals: VitalReading;
  last14DaysVitals: VitalReading[];
  currentAlerts: Alert[];
}
