import { Patient, Alert } from '@/types';
import { getPatientAlertLevel, getLatestVitalsSummary } from './vitals-analyzer';

function daysAgo(n: number): string {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d.toISOString().split('T')[0];
}

function minutesAgo(n: number): string {
  if (n < 60) return `${n} minutes ago`;
  const h = Math.floor(n / 60);
  if (h < 24) return `${h} hour${h > 1 ? 's' : ''} ago`;
  const days = Math.floor(h / 24);
  return `${days} day${days > 1 ? 's' : ''} ago`;
}

const rawPatients: Omit<Patient, 'alertStatus'>[] = [
  // --- COPD Patients (3) ---
  {
    id: 'P001',
    name: 'Rajesh Kumar',
    age: 67,
    gender: 'Male',
    condition: 'COPD',
    city: 'Mumbai',
    phoneNumber: '+91-98201-11234',
    physicianName: 'Dr. Anita Desai',
    enrollmentDate: '2024-01-15',
    treatmentStep: 2,
    medications: [
      { name: 'Telmisartan', genericName: 'Telmisartan', drugClass: 'ARB' as const, dose: '40 mg', frequency: 'Once daily', startDate: '2024-01-15' },
      { name: 'Amlodipine', genericName: 'Amlodipine', drugClass: 'CCB' as const, dose: '5 mg', frequency: 'Once daily', startDate: '2024-01-15' },
      { name: 'Chlorthalidone', genericName: 'Chlorthalidone', drugClass: 'Diuretic' as const, dose: '12.5 mg', frequency: 'Once daily', startDate: '2024-03-01' },
    ],
    lastReadingTime: minutesAgo(12),
    vitals: Array.from({ length: 14 }, (_, i) => ({
      date: daysAgo(13 - i),
      o2Sat: [88, 87, 89, 86, 88, 85, 87, 88, 84, 86, 85, 87, 84, 83][i],
      systolic: [138, 142, 140, 145, 138, 142, 144, 141, 139, 143, 146, 140, 144, 147][i],
      diastolic: [88, 90, 87, 92, 88, 90, 91, 89, 88, 91, 93, 89, 91, 94][i],
      heartRate: [88, 92, 90, 94, 88, 92, 93, 91, 89, 93, 95, 91, 93, 96][i],
      weight: [72, 72.2, 72.1, 72.3, 72.5, 72.4, 72.6, 72.5, 72.8, 72.7, 73, 72.9, 73.2, 73.5][i],
    })),
    alerts: [
      {
        id: 'A001',
        patientId: 'P001',
        patientName: 'Rajesh Kumar',
        type: 'O2 Sat',
        message: 'SpO2 dropped to 83% - severe hypoxia detected',
        severity: 'critical',
        timestamp: new Date(Date.now() - 12 * 60000).toISOString(),
        acknowledged: false,
      },
    ],
  },
  {
    id: 'P002',
    name: 'Meena Iyer',
    age: 58,
    gender: 'Female',
    condition: 'COPD',
    city: 'Chennai',
    phoneNumber: '+91-94440-22345',
    physicianName: 'Dr. Anita Desai',
    enrollmentDate: '2024-02-10',
    treatmentStep: 1,
    medications: [
      { name: 'Amlodipine', genericName: 'Amlodipine', drugClass: 'CCB' as const, dose: '5 mg', frequency: 'Once daily', startDate: '2024-02-10' },
      { name: 'Indapamide', genericName: 'Indapamide', drugClass: 'Diuretic' as const, dose: '1.5 mg', frequency: 'Once daily', startDate: '2024-02-10' },
    ],
    lastReadingTime: minutesAgo(35),
    vitals: Array.from({ length: 14 }, (_, i) => ({
      date: daysAgo(13 - i),
      o2Sat: [93, 94, 92, 93, 94, 93, 92, 94, 93, 92, 93, 94, 93, 92][i],
      systolic: [122, 124, 120, 126, 122, 124, 126, 123, 121, 125, 127, 122, 124, 126][i],
      diastolic: [78, 80, 77, 81, 78, 80, 81, 79, 77, 80, 82, 78, 80, 81][i],
      heartRate: [78, 80, 76, 82, 78, 80, 82, 79, 77, 81, 83, 78, 80, 82][i],
      weight: [56, 56.2, 56.1, 56, 56.3, 56.2, 56.4, 56.3, 56.5, 56.4, 56.6, 56.5, 56.7, 56.8][i],
    })),
    alerts: [
      {
        id: 'A002',
        patientId: 'P002',
        patientName: 'Meena Iyer',
        type: 'O2 Sat',
        message: 'SpO2 at 92% - mild hypoxia, monitoring required',
        severity: 'warning',
        timestamp: new Date(Date.now() - 35 * 60000).toISOString(),
        acknowledged: false,
      },
    ],
  },
  {
    id: 'P003',
    name: 'Subramaniam Pillai',
    age: 72,
    gender: 'Male',
    condition: 'COPD',
    city: 'Hyderabad',
    phoneNumber: '+91-99000-33456',
    physicianName: 'Dr. Vikram Nair',
    enrollmentDate: '2023-11-20',
    treatmentStep: 1,
    medications: [
      { name: 'Ramipril', genericName: 'Ramipril', drugClass: 'ACE' as const, dose: '2.5 mg', frequency: 'Once daily', startDate: '2024-03-05' },
      { name: 'Amlodipine', genericName: 'Amlodipine', drugClass: 'CCB' as const, dose: '5 mg', frequency: 'Once daily', startDate: '2024-03-05' },
    ],
    lastReadingTime: minutesAgo(90),
    vitals: Array.from({ length: 14 }, (_, i) => ({
      date: daysAgo(13 - i),
      o2Sat: [96, 97, 96, 97, 95, 96, 97, 96, 95, 97, 96, 97, 96, 95][i],
      systolic: [118, 120, 116, 122, 118, 120, 122, 119, 117, 121, 123, 118, 120, 122][i],
      diastolic: [74, 76, 73, 78, 74, 76, 78, 75, 73, 77, 79, 74, 76, 78][i],
      heartRate: [72, 74, 70, 76, 72, 74, 76, 73, 71, 75, 77, 72, 74, 76][i],
      weight: [68, 68.1, 68, 68.2, 68.1, 68.3, 68.2, 68.4, 68.3, 68.5, 68.4, 68.6, 68.5, 68.7][i],
    })),
    alerts: [],
  },

  // --- Hypertension Patients (3) ---
  {
    id: 'P004',
    name: 'Priya Sharma',
    age: 52,
    gender: 'Female',
    condition: 'Hypertension',
    city: 'Delhi',
    phoneNumber: '+91-98110-44567',
    physicianName: 'Dr. Anita Desai',
    enrollmentDate: '2024-03-05',
    treatmentStep: 2,
    medications: [
      { name: 'Losartan', genericName: 'Losartan', drugClass: 'ARB' as const, dose: '50 mg', frequency: 'Once daily', startDate: '2024-01-20' },
      { name: 'Amlodipine', genericName: 'Amlodipine', drugClass: 'CCB' as const, dose: '5 mg', frequency: 'Once daily', startDate: '2024-01-20' },
      { name: 'Chlorthalidone', genericName: 'Chlorthalidone', drugClass: 'Diuretic' as const, dose: '12.5 mg', frequency: 'Once daily', startDate: '2024-02-15' },
    ],
    lastReadingTime: minutesAgo(8),
    vitals: Array.from({ length: 14 }, (_, i) => ({
      date: daysAgo(13 - i),
      systolic: [158, 162, 155, 168, 160, 165, 170, 162, 158, 172, 180, 175, 182, 188][i],
      diastolic: [98, 102, 96, 106, 100, 104, 108, 102, 98, 110, 118, 112, 120, 124][i],
      heartRate: [84, 88, 82, 90, 86, 88, 92, 88, 84, 92, 96, 90, 94, 98][i],
      weight: [74, 74.2, 74.1, 74.3, 74.2, 74.4, 74.3, 74.5, 74.4, 74.6, 74.5, 74.7, 74.6, 74.8][i],
    })),
    alerts: [
      {
        id: 'A003',
        patientId: 'P004',
        patientName: 'Priya Sharma',
        type: 'BP',
        message: 'Hypertensive Crisis: BP 188/124 mmHg - immediate attention required',
        severity: 'critical',
        timestamp: new Date(Date.now() - 8 * 60000).toISOString(),
        acknowledged: false,
      },
    ],
  },
  {
    id: 'P005',
    name: 'Anand Patel',
    age: 61,
    gender: 'Male',
    condition: 'Hypertension',
    city: 'Ahmedabad',
    phoneNumber: '+91-98250-55678',
    physicianName: 'Dr. Vikram Nair',
    enrollmentDate: '2024-01-28',
    treatmentStep: 3,
    medications: [
      { name: 'Telmisartan', genericName: 'Telmisartan', drugClass: 'ARB' as const, dose: '80 mg', frequency: 'Once daily', startDate: '2023-11-10' },
      { name: 'Amlodipine', genericName: 'Amlodipine', drugClass: 'CCB' as const, dose: '10 mg', frequency: 'Once daily', startDate: '2023-11-10' },
      { name: 'Chlorthalidone', genericName: 'Chlorthalidone', drugClass: 'Diuretic' as const, dose: '25 mg', frequency: 'Once daily', startDate: '2023-12-01' },
    ],
    lastReadingTime: minutesAgo(45),
    vitals: Array.from({ length: 14 }, (_, i) => ({
      date: daysAgo(13 - i),
      systolic: [142, 145, 140, 148, 142, 146, 144, 142, 145, 143, 141, 144, 142, 140][i],
      diastolic: [90, 93, 88, 95, 90, 93, 92, 90, 93, 91, 89, 92, 90, 88][i],
      heartRate: [76, 78, 74, 80, 76, 78, 77, 76, 78, 77, 75, 77, 76, 74][i],
      weight: [82, 82.2, 82.1, 82.3, 82.2, 82.4, 82.3, 82.5, 82.4, 82.6, 82.5, 82.7, 82.6, 82.8][i],
    })),
    alerts: [
      {
        id: 'A004',
        patientId: 'P005',
        patientName: 'Anand Patel',
        type: 'BP',
        message: 'Stage 2 Hypertension: BP 148/95 mmHg',
        severity: 'warning',
        timestamp: new Date(Date.now() - 45 * 60000).toISOString(),
        acknowledged: false,
      },
    ],
  },
  {
    id: 'P006',
    name: 'Kavitha Reddy',
    age: 48,
    gender: 'Female',
    condition: 'Hypertension',
    city: 'Bangalore',
    phoneNumber: '+91-99800-66789',
    physicianName: 'Dr. Anita Desai',
    enrollmentDate: '2024-04-12',
    treatmentStep: 1,
    medications: [
      { name: 'Perindopril', genericName: 'Perindopril', drugClass: 'ACE' as const, dose: '4 mg', frequency: 'Once daily', startDate: '2024-04-01' },
      { name: 'Amlodipine', genericName: 'Amlodipine', drugClass: 'CCB' as const, dose: '5 mg', frequency: 'Once daily', startDate: '2024-04-01' },
    ],
    lastReadingTime: minutesAgo(120),
    vitals: Array.from({ length: 14 }, (_, i) => ({
      date: daysAgo(13 - i),
      systolic: [128, 130, 126, 132, 128, 130, 132, 129, 127, 131, 133, 128, 130, 132][i],
      diastolic: [82, 84, 80, 86, 82, 84, 86, 83, 81, 85, 87, 82, 84, 86][i],
      heartRate: [70, 72, 68, 74, 70, 72, 74, 71, 69, 73, 75, 70, 72, 74][i],
      weight: [62, 62.2, 62.1, 62.3, 62.2, 62.4, 62.3, 62.5, 62.4, 62.6, 62.5, 62.7, 62.6, 62.8][i],
    })),
    alerts: [
      {
        id: 'A005',
        patientId: 'P006',
        patientName: 'Kavitha Reddy',
        type: 'BP',
        message: 'Elevated BP: Stage 1 Hypertension detected',
        severity: 'warning',
        timestamp: new Date(Date.now() - 120 * 60000).toISOString(),
        acknowledged: true,
      },
    ],
  },

  // --- Diabetes Patients (3) ---
  {
    id: 'P007',
    name: 'Mohammed Farooq',
    age: 55,
    gender: 'Male',
    condition: 'Diabetes',
    city: 'Hyderabad',
    phoneNumber: '+91-98490-77890',
    physicianName: 'Dr. Sunita Rao',
    enrollmentDate: '2023-12-01',
    treatmentStep: 1,
    medications: [
      { name: 'Metformin', genericName: 'Metformin', drugClass: 'Other' as const, dose: '500 mg', frequency: 'Twice daily', startDate: '2023-08-15' },
      { name: 'Glimepiride', genericName: 'Glimepiride', drugClass: 'Other' as const, dose: '1 mg', frequency: 'Once daily', startDate: '2023-08-15' },
    ],
    lastReadingTime: minutesAgo(20),
    vitals: Array.from({ length: 14 }, (_, i) => ({
      date: daysAgo(13 - i),
      glucose: [142, 156, 138, 168, 145, 160, 175, 155, 148, 178, 320, 290, 340, 310][i],
      glucoseType: 'fasting' as const,
      systolic: [132, 135, 130, 138, 132, 136, 134, 132, 135, 133, 131, 134, 132, 130][i],
      diastolic: [84, 86, 82, 88, 84, 86, 85, 84, 86, 85, 83, 85, 84, 82][i],
      heartRate: [78, 80, 76, 82, 78, 80, 79, 78, 80, 79, 77, 79, 78, 76][i],
      weight: [88, 88.2, 88.1, 88.3, 88.2, 88.4, 88.3, 88.5, 88.4, 88.6, 88.5, 88.7, 88.6, 88.8][i],
    })),
    alerts: [
      {
        id: 'A006',
        patientId: 'P007',
        patientName: 'Mohammed Farooq',
        type: 'Glucose',
        message: 'Severe Hyperglycemia: Fasting glucose 340 mg/dL',
        severity: 'critical',
        timestamp: new Date(Date.now() - 20 * 60000).toISOString(),
        acknowledged: false,
      },
    ],
  },
  {
    id: 'P008',
    name: 'Saranya Krishnan',
    age: 49,
    gender: 'Female',
    condition: 'Diabetes',
    city: 'Chennai',
    phoneNumber: '+91-94890-88901',
    physicianName: 'Dr. Sunita Rao',
    enrollmentDate: '2024-02-20',
    treatmentStep: 1,
    medications: [
      { name: 'Metformin', genericName: 'Metformin', drugClass: 'Other' as const, dose: '1000 mg', frequency: 'Twice daily', startDate: '2023-10-20' },
      { name: 'Sitagliptin', genericName: 'Sitagliptin', drugClass: 'Other' as const, dose: '100 mg', frequency: 'Once daily', startDate: '2024-01-10' },
      { name: 'Ramipril', genericName: 'Ramipril', drugClass: 'ACE' as const, dose: '5 mg', frequency: 'Once daily', startDate: '2024-01-10' },
    ],
    lastReadingTime: minutesAgo(60),
    vitals: Array.from({ length: 14 }, (_, i) => ({
      date: daysAgo(13 - i),
      glucose: [118, 122, 116, 126, 118, 124, 120, 118, 124, 122, 116, 120, 118, 116][i],
      glucoseType: 'fasting' as const,
      systolic: [124, 126, 122, 128, 124, 126, 128, 125, 123, 127, 129, 124, 126, 128][i],
      diastolic: [78, 80, 76, 82, 78, 80, 82, 79, 77, 81, 83, 78, 80, 82][i],
      heartRate: [72, 74, 70, 76, 72, 74, 76, 73, 71, 75, 77, 72, 74, 76][i],
      weight: [64, 64.2, 64.1, 64.3, 64.2, 64.4, 64.3, 64.5, 64.4, 64.6, 64.5, 64.7, 64.6, 64.8][i],
    })),
    alerts: [
      {
        id: 'A007',
        patientId: 'P008',
        patientName: 'Saranya Krishnan',
        type: 'Glucose',
        message: 'Prediabetes range: Fasting glucose 116 mg/dL',
        severity: 'warning',
        timestamp: new Date(Date.now() - 60 * 60000).toISOString(),
        acknowledged: false,
      },
    ],
  },
  {
    id: 'P009',
    name: 'Ramesh Gupta',
    age: 63,
    gender: 'Male',
    condition: 'Diabetes',
    city: 'Delhi',
    phoneNumber: '+91-98100-99012',
    physicianName: 'Dr. Vikram Nair',
    enrollmentDate: '2023-10-15',
    treatmentStep: 1,
    medications: [
      { name: 'Insulin Glargine', genericName: 'Insulin Glargine', drugClass: 'Other' as const, dose: '20 units', frequency: 'Once daily (bedtime)', startDate: '2024-02-01' },
      { name: 'Metformin', genericName: 'Metformin', drugClass: 'Other' as const, dose: '500 mg', frequency: 'Twice daily', startDate: '2024-02-01' },
    ],
    lastReadingTime: minutesAgo(180),
    vitals: Array.from({ length: 14 }, (_, i) => ({
      date: daysAgo(13 - i),
      glucose: [95, 98, 92, 102, 95, 100, 96, 95, 99, 97, 93, 96, 95, 93][i],
      glucoseType: 'fasting' as const,
      systolic: [118, 120, 116, 122, 118, 120, 122, 119, 117, 121, 123, 118, 120, 122][i],
      diastolic: [76, 78, 74, 80, 76, 78, 80, 77, 75, 79, 81, 76, 78, 80][i],
      heartRate: [68, 70, 66, 72, 68, 70, 72, 69, 67, 71, 73, 68, 70, 72][i],
      weight: [78, 78.1, 78, 78.2, 78.1, 78.3, 78.2, 78.4, 78.3, 78.5, 78.4, 78.6, 78.5, 78.7][i],
    })),
    alerts: [],
  },

  // --- Heart Failure Patients (3) ---
  {
    id: 'P010',
    name: 'Lakshmi Venkataraman',
    age: 70,
    gender: 'Female',
    condition: 'Heart Failure',
    city: 'Bangalore',
    phoneNumber: '+91-80000-10123',
    physicianName: 'Dr. Sunita Rao',
    enrollmentDate: '2023-09-01',
    treatmentStep: 2,
    medications: [
      { name: 'Ramipril', genericName: 'Ramipril', drugClass: 'ACE' as const, dose: '5 mg', frequency: 'Once daily', startDate: '2023-12-01' },
      { name: 'Bisoprolol', genericName: 'Bisoprolol', drugClass: 'BetaBlocker' as const, dose: '5 mg', frequency: 'Once daily', startDate: '2023-12-01' },
      { name: 'Furosemide', genericName: 'Furosemide', drugClass: 'Diuretic' as const, dose: '40 mg', frequency: 'Once daily', startDate: '2023-12-01' },
    ],
    lastReadingTime: minutesAgo(15),
    vitals: Array.from({ length: 14 }, (_, i) => ({
      date: daysAgo(13 - i),
      weight: [58, 58.5, 59, 59.2, 59.8, 60.2, 60.5, 61, 61.8, 62.5, 63.2, 64, 65, 67.5][i],
      o2Sat: [92, 91, 93, 90, 92, 91, 90, 89, 88, 87, 86, 85, 84, 83][i],
      systolic: [140, 144, 138, 148, 142, 146, 150, 148, 152, 155, 158, 162, 168, 172][i],
      diastolic: [88, 91, 86, 94, 89, 93, 96, 94, 98, 100, 104, 108, 112, 116][i],
      heartRate: [88, 92, 86, 94, 90, 93, 96, 94, 98, 100, 104, 108, 112, 116][i],
    })),
    alerts: [
      {
        id: 'A008',
        patientId: 'P010',
        patientName: 'Lakshmi Venkataraman',
        type: 'Weight',
        message: 'Critical weight gain: +2.5kg in 48h - decompensation risk',
        severity: 'critical',
        timestamp: new Date(Date.now() - 15 * 60000).toISOString(),
        acknowledged: false,
      },
      {
        id: 'A009',
        patientId: 'P010',
        patientName: 'Lakshmi Venkataraman',
        type: 'O2 Sat',
        message: 'Severe hypoxia: SpO2 83%',
        severity: 'critical',
        timestamp: new Date(Date.now() - 15 * 60000).toISOString(),
        acknowledged: false,
      },
    ],
  },
  {
    id: 'P011',
    name: 'Narayan Bose',
    age: 65,
    gender: 'Male',
    condition: 'Heart Failure',
    city: 'Kolkata',
    phoneNumber: '+91-98300-11234',
    physicianName: 'Dr. Vikram Nair',
    enrollmentDate: '2024-01-10',
    treatmentStep: 3,
    medications: [
      { name: 'Sacubitril/Valsartan', genericName: 'Sacubitril/Valsartan', drugClass: 'ARNI' as const, dose: '50 mg', frequency: 'Twice daily', startDate: '2023-09-15' },
      { name: 'Carvedilol', genericName: 'Carvedilol', drugClass: 'BetaBlocker' as const, dose: '12.5 mg', frequency: 'Twice daily', startDate: '2023-09-15' },
      { name: 'Spironolactone', genericName: 'Spironolactone', drugClass: 'MRA' as const, dose: '25 mg', frequency: 'Once daily', startDate: '2024-01-01' },
    ],
    lastReadingTime: minutesAgo(40),
    vitals: Array.from({ length: 14 }, (_, i) => ({
      date: daysAgo(13 - i),
      weight: [72, 72.2, 72.4, 72.6, 72.5, 72.7, 72.9, 73.2, 73.5, 73.8, 74, 74.3, 74.5, 75][i],
      o2Sat: [93, 94, 92, 93, 94, 93, 92, 91, 92, 91, 90, 91, 90, 89][i],
      systolic: [138, 140, 136, 142, 138, 140, 142, 139, 137, 141, 143, 138, 140, 142][i],
      diastolic: [86, 88, 84, 90, 86, 88, 90, 87, 85, 89, 91, 86, 88, 90][i],
      heartRate: [82, 84, 80, 86, 82, 84, 86, 83, 81, 85, 87, 82, 84, 86][i],
    })),
    alerts: [
      {
        id: 'A010',
        patientId: 'P011',
        patientName: 'Narayan Bose',
        type: 'Weight',
        message: 'Weight gain 3kg over 14 days - monitoring required',
        severity: 'warning',
        timestamp: new Date(Date.now() - 40 * 60000).toISOString(),
        acknowledged: false,
      },
    ],
  },
  {
    id: 'P012',
    name: 'Deepa Nambiar',
    age: 57,
    gender: 'Female',
    condition: 'Heart Failure',
    city: 'Kochi',
    phoneNumber: '+91-94470-22345',
    physicianName: 'Dr. Anita Desai',
    enrollmentDate: '2024-03-22',
    treatmentStep: 2,
    medications: [
      { name: 'Enalapril', genericName: 'Enalapril', drugClass: 'ACE' as const, dose: '5 mg', frequency: 'Twice daily', startDate: '2024-01-15' },
      { name: 'Bisoprolol', genericName: 'Bisoprolol', drugClass: 'BetaBlocker' as const, dose: '2.5 mg', frequency: 'Once daily', startDate: '2024-01-15' },
      { name: 'Furosemide', genericName: 'Furosemide', drugClass: 'Diuretic' as const, dose: '40 mg', frequency: 'Once daily', startDate: '2024-01-15' },
    ],
    lastReadingTime: minutesAgo(25),
    vitals: Array.from({ length: 14 }, (_, i) => ({
      date: daysAgo(13 - i),
      weight: [55, 55.1, 55, 55.2, 55.1, 55.3, 55.2, 55.4, 55.3, 55.5, 55.4, 55.6, 55.5, 55.7][i],
      o2Sat: [96, 97, 96, 97, 96, 97, 95, 96, 97, 96, 95, 97, 96, 96][i],
      systolic: [126, 128, 124, 130, 126, 128, 130, 127, 125, 129, 131, 126, 128, 130][i],
      diastolic: [80, 82, 78, 84, 80, 82, 84, 81, 79, 83, 85, 80, 82, 84][i],
      heartRate: [72, 74, 70, 76, 72, 74, 76, 73, 71, 75, 77, 72, 74, 76][i],
    })),
    alerts: [],
  },
];

// Compute alertStatus for each patient
export const mockPatients: Patient[] = rawPatients.map((p) => ({
  ...p,
  alertStatus: getPatientAlertLevel(p as Patient),
}));

export function getPatientById(id: string): Patient | undefined {
  return mockPatients.find((p) => p.id === id);
}

export function getPatientSummaries(condition?: string) {
  return mockPatients
    .filter((p) => !condition || condition === 'All' || p.condition === condition)
    .map((p) => {
      const latestVitals = getLatestVitalsSummary(p);
      return {
        id: p.id,
        name: p.name,
        age: p.age,
        condition: p.condition,
        city: p.city,
        alertStatus: p.alertStatus,
        lastReadingTime: p.lastReadingTime,
        latestVitals,
      };
    });
}

export function getDashboardStats() {
  const total = mockPatients.length;
  const critical = mockPatients.filter((p) => p.alertStatus === 'critical').length;
  const warning = mockPatients.filter((p) => p.alertStatus === 'warning').length;
  const stable = mockPatients.filter(
    (p) => p.alertStatus === 'stable' || p.alertStatus === 'normal'
  ).length;
  const activeAlerts = mockPatients.flatMap((p) => p.alerts).filter((a) => !a.acknowledged).length;

  return { total, critical, warning, stable, activeAlerts };
}

export function getRecentAlerts() {
  return mockPatients
    .flatMap((p) => p.alerts)
    .filter((a) => !a.acknowledged)
    .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
    .slice(0, 10);
}
