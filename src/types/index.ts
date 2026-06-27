export type Condition = 'COPD' | 'Hypertension' | 'Diabetes' | 'Heart Failure';

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
