export type Condition = 'COPD' | 'Hypertension' | 'Diabetes' | 'Heart Failure';

export interface Medication {
  name: string;
  genericName: string;
  drugClass: 'ACE' | 'ARB' | 'CCB' | 'Diuretic' | 'BetaBlocker' | 'MRA' | 'AlphaBlocker' | 'Central' | 'ARNI' | 'Other';
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

export interface EscalationRecommendation {
  shouldEscalate: boolean;
  reason: EscalationReason;
  currentStep: number;
  nextStep: number;
  consecutiveElevatedCount: number;
  escalationThreshold: number;
  recommendedAddition: string;
  recommendedRegimen: string[];
  contraindications: string[];
  guidelineReference: string;
  urgency: 'routine' | 'urgent' | 'immediate';
}

export type AlertStatus = 'critical' | 'warning' | 'stable' | 'normal';

export interface VitalReading {
  date: string; // ISO date string
  systolic?: number;
  diastolic?: number;
  glucose?: number;
  glucoseType?: 'fasting' | 'post-meal';
  o2Sat?: number;
  weight?: number; // kg
  heartRate?: number;
}

export interface Alert {
  id: string;
  patientId: string;
  patientName: string;
  type: 'BP' | 'Glucose' | 'O2 Sat' | 'Weight';
  message: string;
  severity: AlertStatus;
  timestamp: string;
  acknowledged: boolean;
}

export interface Patient {
  id: string;
  name: string;
  age: number;
  gender: 'Male' | 'Female';
  condition: Condition;
  city: string;
  phoneNumber: string;
  physicianName: string;
  enrollmentDate: string;
  vitals: VitalReading[];
  alerts: Alert[];
  alertStatus: AlertStatus;
  lastReadingTime: string; // "X minutes/hours ago"
  medications: Medication[];
  treatmentStep: number;
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
  condition: Condition;
  city: string;
  alertStatus: AlertStatus;
  lastReadingTime: string;
  latestVitals: {
    bp?: string;
    glucose?: number;
    o2Sat?: number;
    weight?: number;
  };
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
    condition: Condition;
    gender: string;
  };
  latestVitals: VitalReading;
  last14DaysVitals: VitalReading[];
  currentAlerts: Alert[];
}
