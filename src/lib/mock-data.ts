import { Patient, VitalReading, SmartGoal, OutreachCall } from '@/types';
import { getPatientAlertLevel, getLatestVitalsSummary } from './vitals-analyzer';
import { getHbA1cTierInfo } from './guidelines';

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

// Daily home BP readings per IGH-V HBPM protocol
function dailyBP(values: [number, number][]): VitalReading[] {
  return values.map(([sys, dia], i) => ({
    date: daysAgo(values.length - 1 - i),
    systolic: sys,
    diastolic: dia,
  }));
}

// Sparse SMBG per RSSDI Table 2/3 (not a flat daily rule) — pass [daysAgoOffset, glucose, type][]
function glucoseReadings(entries: [number, number, 'fasting' | 'post-meal'][]): VitalReading[] {
  return entries.map(([offset, glucose, glucoseType]) => ({
    date: daysAgo(offset),
    glucose,
    glucoseType,
  }));
}

function mergeVitals(...groups: VitalReading[][]): VitalReading[] {
  return groups.flat().sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0));
}

const rawPatients: Omit<Patient, 'alertStatus'>[] = [
  // --- Hypertension only ---
  {
    id: 'P001',
    name: 'Rajesh Kumar',
    age: 67,
    gender: 'Male',
    conditions: ['Hypertension'],
    comorbidities: ['Established CVD'],
    city: 'Mumbai',
    phoneNumber: '+91-98201-11234',
    physicianName: 'Dr. Anita Desai',
    enrollmentDate: daysAgo(70),
    htnStep: 2,
    diabetesStep: null,
    hba1cTier: null,
    hba1cReadings: [],
    medications: [
      { name: 'Telmisartan', genericName: 'Telmisartan', drugClass: 'ARB', dose: '80 mg', frequency: 'Once daily', startDate: daysAgo(70) },
      { name: 'Amlodipine', genericName: 'Amlodipine', drugClass: 'CCB', dose: '5 mg', frequency: 'Once daily', startDate: daysAgo(70) },
      { name: 'Chlorthalidone', genericName: 'Chlorthalidone', drugClass: 'Diuretic', dose: '6.25 mg', frequency: 'Once daily', startDate: daysAgo(35) },
    ],
    lastReadingTime: minutesAgo(12),
    vitals: dailyBP([
      [148, 92], [152, 95], [149, 93], [156, 98], [151, 94], [158, 100], [162, 102],
      [155, 96], [150, 93], [165, 104], [172, 108], [168, 106], [178, 114], [182, 116],
    ]),
    alerts: [
      {
        id: 'A001',
        patientId: 'P001',
        patientName: 'Rajesh Kumar',
        type: 'BP',
        message: 'Severe Hypertension (Stage III): BP 182/116 mmHg',
        severity: 'critical',
        timestamp: new Date(Date.now() - 12 * 60000).toISOString(),
        acknowledged: false,
      },
    ],
    coachingTier: 'High-touch',
    coachingCallsCompleted: 8,
    coachingCallsTarget: 14,
    outreachLog: [
      outreachCall({ id: 'O001-3', offset: 3, coordinatorName: 'Fathima Rasheed', coordinatorRole: 'Lifestyle Coach', callType: 'Tier Check-in', durationMin: 18, topics: ['Diet', 'Medication Adherence'], dietNotes: 'Still eating restaurant food 4-5x/week — sodium likely well above 2g/day target. Provided low-sodium thali swap list.', medAdherenceNotes: 'Missed evening Chlorthalidone dose twice this week — moved pillbox next to dinner plate as a cue.', summary: 'BP trending up on home readings; reinforced salt-reduction goal and adherence cue. Flagged rising trend to physician.' }),
      outreachCall({ id: 'O001-10', offset: 10, coordinatorName: 'Fathima Rasheed', coordinatorRole: 'Lifestyle Coach', callType: 'Tier Check-in', durationMin: 15, topics: ['Diet', 'Physical Activity'], dietNotes: 'Reports high-salt snacking in the evenings.', exerciseNotes: 'Walking 15 min/day, below 30 min goal — cites knee discomfort.', summary: 'Discussed low-impact alternatives to walking; set interim 20 min/day target.' }),
    ],
    smartGoals: [
      goal({ id: 'G001-1', category: 'Diet', description: 'Cut down added salt in diet over the next 2 weeks — no extra salt at the table, limit outside food to 2x/week', setDate: daysAgo(24), targetDate: daysAgo(10), status: 'At Risk', progressNote: 'Outside-food frequency still 4-5x/week at last check-in.' }),
      goal({ id: 'G001-2', category: 'Medication Adherence', description: 'Take evening Chlorthalidone at the same time as dinner, 7 days/week', setDate: daysAgo(24), targetDate: daysAgo(3), status: 'Partially Met', progressNote: 'Pillbox-by-plate cue introduced this week.' }),
      goal({ id: 'G001-3', category: 'Physical Activity', description: 'Walk 20 minutes/day, 5 days/week', setDate: daysAgo(10), targetDate: daysAgo(-4), status: 'On Track' }),
    ],
  },
  {
    id: 'P002',
    name: 'Priya Sharma',
    age: 52,
    gender: 'Female',
    conditions: ['Hypertension'],
    comorbidities: [],
    city: 'Delhi',
    phoneNumber: '+91-98110-44567',
    physicianName: 'Dr. Anita Desai',
    enrollmentDate: daysAgo(60),
    htnStep: 1,
    diabetesStep: null,
    hba1cTier: null,
    hba1cReadings: [],
    medications: [
      { name: 'Losartan', genericName: 'Losartan', drugClass: 'ARB', dose: '50 mg', frequency: 'Once daily', startDate: daysAgo(60) },
      { name: 'Amlodipine', genericName: 'Amlodipine', drugClass: 'CCB', dose: '5 mg', frequency: 'Once daily', startDate: daysAgo(60) },
    ],
    lastReadingTime: minutesAgo(8),
    vitals: dailyBP([
      [158, 98], [162, 102], [155, 96], [168, 106], [160, 100], [165, 104], [170, 108],
      [162, 102], [158, 98], [172, 110], [180, 118], [175, 112], [182, 120], [188, 124],
    ]),
    alerts: [
      {
        id: 'A002',
        patientId: 'P002',
        patientName: 'Priya Sharma',
        type: 'BP',
        message: 'Hypertensive Crisis / Emergency: BP 188/124 mmHg — immediate attention required',
        severity: 'critical',
        timestamp: new Date(Date.now() - 8 * 60000).toISOString(),
        acknowledged: false,
      },
    ],
    coachingTier: 'High-touch',
    coachingCallsCompleted: 6,
    coachingCallsTarget: 14,
    outreachLog: [
      outreachCall({ id: 'O002-2', offset: 2, coordinatorName: 'Fathima Rasheed', coordinatorRole: 'Lifestyle Coach', callType: 'Tier Check-in', durationMin: 20, topics: ['Diet', 'Medication Adherence', 'Sleep & Stress'], dietNotes: 'High work-stress week, ordered in most nights — high sodium.', medAdherenceNotes: 'Adherent, no missed doses.', summary: 'BP crisis reading discussed; escalated to Nivara physician same call. Reinforced stress-linked eating pattern.' }),
      outreachCall({ id: 'O002-1', offset: 1, coordinatorName: 'Dr. Vikram Nair (backup physician)', coordinatorRole: 'Nurse', callType: 'Nurse Medication Check-in', durationMin: 10, topics: ['Medication Adherence'], medAdherenceNotes: 'Confirmed both current medications taken as prescribed this morning.', summary: 'Follow-up nurse call after crisis-level reading to confirm adherence before physician-directed dose change takes effect.' }),
    ],
    smartGoals: [
      goal({ id: 'G002-1', category: 'Diet', description: 'Cut down added salt in diet over the next 2 weeks — cook dinner at home at least 5 nights/week', setDate: daysAgo(20), targetDate: daysAgo(6), status: 'At Risk', progressNote: 'Work travel disrupted home cooking this week.' }),
      goal({ id: 'G002-2', category: 'Physical Activity', description: '150 min/week moderate activity (brisk walking)', setDate: daysAgo(20), targetDate: daysAgo(-8), status: 'On Track' }),
    ],
  },
  {
    id: 'P003',
    name: 'Anand Patel',
    age: 61,
    gender: 'Male',
    conditions: ['Hypertension'],
    comorbidities: [],
    city: 'Ahmedabad',
    phoneNumber: '+91-98250-55678',
    physicianName: 'Dr. Vikram Nair',
    enrollmentDate: daysAgo(90),
    htnStep: 3,
    diabetesStep: null,
    hba1cTier: null,
    hba1cReadings: [],
    medications: [
      { name: 'Telmisartan', genericName: 'Telmisartan', drugClass: 'ARB', dose: '80 mg', frequency: 'Once daily', startDate: daysAgo(90) },
      { name: 'Amlodipine', genericName: 'Amlodipine', drugClass: 'CCB', dose: '10 mg', frequency: 'Once daily', startDate: daysAgo(90) },
      { name: 'Chlorthalidone', genericName: 'Chlorthalidone', drugClass: 'Diuretic', dose: '12.5 mg', frequency: 'Once daily', startDate: daysAgo(60) },
    ],
    lastReadingTime: minutesAgo(45),
    vitals: dailyBP([
      [142, 90], [145, 92], [140, 88], [138, 87], [142, 89], [136, 86], [134, 85],
      [138, 87], [135, 86], [133, 85], [131, 84], [134, 85], [132, 84], [130, 83],
    ]),
    alerts: [],
    coachingTier: 'Moderate-touch',
    coachingCallsCompleted: 5,
    coachingCallsTarget: 8,
    outreachLog: [
      outreachCall({ id: 'O003-6', offset: 6, coordinatorName: 'Rohan Bhatt', coordinatorRole: 'Lifestyle Coach', callType: 'Tier Check-in', durationMin: 16, topics: ['Diet', 'Physical Activity'], dietNotes: 'Sodium intake down since switching to home-cooked Gujarati thali with less pickle/papad.', exerciseNotes: 'Walking 25 min/day, 5 days/week — consistent.', summary: 'BP trending down toward target on max triple therapy; positive reinforcement given.' }),
    ],
    smartGoals: [
      goal({ id: 'G003-1', category: 'Diet', description: 'Limit pickle/papad (high-sodium) to 2x/week', setDate: daysAgo(28), targetDate: daysAgo(14), status: 'Met', progressNote: 'Down to 1-2x/week consistently.' }),
      goal({ id: 'G003-2', category: 'Physical Activity', description: 'Walk 25 min/day, 5 days/week', setDate: daysAgo(28), targetDate: daysAgo(-2), status: 'On Track' }),
    ],
  },
  {
    id: 'P004',
    name: 'Kavitha Reddy',
    age: 48,
    gender: 'Female',
    conditions: ['Hypertension'],
    comorbidities: [],
    city: 'Bangalore',
    phoneNumber: '+91-99800-66789',
    physicianName: 'Dr. Anita Desai',
    enrollmentDate: daysAgo(45),
    htnStep: 1,
    diabetesStep: null,
    hba1cTier: null,
    hba1cReadings: [],
    medications: [
      { name: 'Perindopril', genericName: 'Perindopril', drugClass: 'ACE', dose: '4 mg', frequency: 'Once daily', startDate: daysAgo(45) },
      { name: 'Amlodipine', genericName: 'Amlodipine', drugClass: 'CCB', dose: '5 mg', frequency: 'Once daily', startDate: daysAgo(45) },
    ],
    lastReadingTime: minutesAgo(120),
    vitals: dailyBP([
      [128, 82], [130, 84], [126, 80], [124, 79], [128, 81], [122, 78], [125, 80],
      [123, 78], [121, 77], [124, 79], [120, 76], [122, 78], [119, 76], [121, 77],
    ]),
    alerts: [],
    coachingTier: 'Maintenance-touch',
    coachingCallsCompleted: 2,
    coachingCallsTarget: 5,
    outreachLog: [
      outreachCall({ id: 'O004-18', offset: 18, coordinatorName: 'Rohan Bhatt', coordinatorRole: 'Lifestyle Coach', callType: 'Week 1 Initial Assessment', durationMin: 40, topics: ['Diet', 'Physical Activity', 'Medication Adherence', 'Sleep & Stress'], dietNotes: 'Baseline diet moderate-sodium, home-cooked mostly.', exerciseNotes: 'Sedentary desk job, minimal structured activity at baseline.', summary: 'Baseline assessment complete; BP at target already on dual therapy. Set initial activity goal.' }),
    ],
    smartGoals: [
      goal({ id: 'G004-1', category: 'Physical Activity', description: 'Start 20 min brisk walk, 4 days/week, building to 150 min/week', setDate: daysAgo(18), targetDate: daysAgo(4), status: 'Met', progressNote: 'Now walking 30 min, 5 days/week.' }),
    ],
  },

  // --- Diabetes only ---
  {
    id: 'P005',
    name: 'Mohammed Farooq',
    age: 55,
    gender: 'Male',
    conditions: ['Diabetes'],
    comorbidities: ['Cost-Sensitive'],
    city: 'Hyderabad',
    phoneNumber: '+91-98490-77890',
    physicianName: 'Dr. Sunita Rao',
    enrollmentDate: daysAgo(56),
    weightKg: 82,
    htnStep: null,
    diabetesStep: 'dual',
    hba1cTier: getHbA1cTierInfo(2),
    hba1cReadings: [
      { date: daysAgo(56), value: 9.8 },
      { date: daysAgo(14), value: 9.4 },
    ],
    medications: [
      { name: 'Metformin (SR)', genericName: 'Metformin', drugClass: 'Biguanide', dose: '1000 mg', frequency: 'Once daily, evening meal', startDate: daysAgo(56) },
      { name: 'Glimepiride', genericName: 'Glimepiride', drugClass: 'Sulfonylurea', dose: '2 mg', frequency: 'Once daily with breakfast', startDate: daysAgo(28) },
    ],
    lastReadingTime: minutesAgo(20),
    vitals: glucoseReadings([
      [13, 168, 'fasting'], [11, 175, 'fasting'], [9, 182, 'fasting'], [7, 190, 'fasting'],
      [5, 245, 'fasting'], [3, 288, 'fasting'], [1, 340, 'fasting'], [0, 320, 'post-meal'],
    ]),
    alerts: [
      {
        id: 'A005',
        patientId: 'P005',
        patientName: 'Mohammed Farooq',
        type: 'Glucose',
        message: 'Severe Hyperglycemia: Fasting glucose 340 mg/dL',
        severity: 'critical',
        timestamp: new Date(Date.now() - 20 * 60000).toISOString(),
        acknowledged: false,
      },
    ],
    coachingTier: 'High-touch',
    coachingCallsCompleted: 7,
    coachingCallsTarget: 14,
    outreachLog: [
      outreachCall({ id: 'O005-1', offset: 1, coordinatorName: 'Divya Menon', coordinatorRole: 'Lifestyle Coach', callType: 'Tier Check-in', durationMin: 20, topics: ['Diet', 'Medication Adherence'], dietNotes: 'Skipping breakfast most days, then large carb-heavy lunch — glucose spikes correlate.', medAdherenceNotes: 'Reports missing Glimepiride 3x this week when breakfast skipped (patient self-adjusting to avoid hypo, unaware sulfonylurea still needs food timing guidance).', summary: 'Sustained fasting glucose ≥130 mg/dL flagged to physician; medication-timing education given; physician alert already sent for today\'s 340 mg/dL reading.' }),
      outreachCall({ id: 'O005-8', offset: 8, coordinatorName: 'Divya Menon', coordinatorRole: 'Lifestyle Coach', callType: 'Tier Check-in', durationMin: 18, topics: ['Diet', 'Physical Activity'], dietNotes: 'Frequent sugary tea (5-6 cups/day).', summary: 'Discussed swapping to sugar-free tea; cost-sensitive snack alternatives provided.' }),
    ],
    smartGoals: [
      goal({ id: 'G005-1', category: 'Diet', description: 'Eat breakfast daily instead of skipping, to stabilize glucose swings', setDate: daysAgo(22), targetDate: daysAgo(8), status: 'Not Met', progressNote: 'Still skipping breakfast 4-5x/week.' }),
      goal({ id: 'G005-2', category: 'Medication Adherence', description: 'Take Glimepiride with breakfast every day, no self-adjusting without calling the coach first', setDate: daysAgo(8), targetDate: daysAgo(-6), status: 'At Risk' }),
    ],
  },
  {
    id: 'P006',
    name: 'Saranya Krishnan',
    age: 49,
    gender: 'Female',
    conditions: ['Diabetes'],
    comorbidities: [],
    city: 'Chennai',
    phoneNumber: '+91-94890-88901',
    physicianName: 'Dr. Sunita Rao',
    enrollmentDate: daysAgo(50),
    weightKg: 64,
    htnStep: null,
    diabetesStep: 'metformin',
    hba1cTier: getHbA1cTierInfo(1),
    hba1cReadings: [
      { date: daysAgo(50), value: 6.9 },
      { date: daysAgo(10), value: 6.6 },
    ],
    medications: [
      { name: 'Metformin (SR)', genericName: 'Metformin', drugClass: 'Biguanide', dose: '1500 mg', frequency: 'Once daily, evening meal', startDate: daysAgo(50) },
    ],
    lastReadingTime: minutesAgo(60),
    vitals: glucoseReadings([
      [12, 118, 'fasting'], [10, 128, 'post-meal'], [9, 122, 'fasting'], [6, 132, 'post-meal'],
      [5, 116, 'fasting'], [2, 124, 'post-meal'], [1, 112, 'fasting'],
    ]),
    alerts: [],
    coachingTier: 'Maintenance-touch',
    coachingCallsCompleted: 2,
    coachingCallsTarget: 5,
    outreachLog: [
      outreachCall({ id: 'O006-16', offset: 16, coordinatorName: 'Divya Menon', coordinatorRole: 'Lifestyle Coach', callType: 'Week 1 Initial Assessment', durationMin: 35, topics: ['Diet', 'Physical Activity', 'Medication Adherence'], dietNotes: 'Rice-heavy diet, moderate portions.', exerciseNotes: 'Yoga 2x/week at baseline.', summary: 'Tier 1 HbA1c target confirmed; already close to target on metformin alone.' }),
    ],
    smartGoals: [
      goal({ id: 'G006-1', category: 'Diet', description: 'Swap white rice for brown rice/millets at dinner, 5 nights/week', setDate: daysAgo(16), targetDate: daysAgo(2), status: 'Met', progressNote: 'Consistent for 3 weeks, reports better post-dinner readings.' }),
    ],
  },
  {
    id: 'P007',
    name: 'Ramesh Gupta',
    age: 63,
    gender: 'Male',
    conditions: ['Diabetes'],
    comorbidities: ['Higher Hypoglycemia Risk'],
    city: 'Delhi',
    phoneNumber: '+91-98100-99012',
    physicianName: 'Dr. Vikram Nair',
    enrollmentDate: daysAgo(75),
    weightKg: 78,
    htnStep: null,
    diabetesStep: 'insulin-basal',
    hba1cTier: getHbA1cTierInfo(2),
    hba1cReadings: [
      { date: daysAgo(75), value: 8.6 },
      { date: daysAgo(21), value: 7.3 },
    ],
    medications: [
      { name: 'Insulin Glargine', genericName: 'Insulin Glargine', drugClass: 'Insulin', dose: '18 units', frequency: 'Once daily, bedtime', startDate: daysAgo(40) },
      { name: 'Metformin (SR)', genericName: 'Metformin', drugClass: 'Biguanide', dose: '1000 mg', frequency: 'Once daily, evening meal', startDate: daysAgo(75) },
    ],
    lastReadingTime: minutesAgo(180),
    vitals: glucoseReadings([
      [12, 98, 'fasting'], [10, 102, 'fasting'], [8, 95, 'fasting'], [6, 105, 'fasting'],
      [4, 92, 'fasting'], [2, 99, 'fasting'], [0, 96, 'fasting'],
    ]),
    alerts: [],
    coachingTier: 'High-touch',
    coachingCallsCompleted: 10,
    coachingCallsTarget: 14,
    outreachLog: [
      outreachCall({ id: 'O007-4', offset: 4, coordinatorName: 'Divya Menon', coordinatorRole: 'Lifestyle Coach', callType: 'Tier Check-in', durationMin: 15, topics: ['Medication Adherence', 'Diet'], medAdherenceNotes: 'Consistent bedtime glargine injection, correct technique confirmed via video call.', dietNotes: 'Stable meal timing, no recent hypoglycemia symptoms reported.', summary: 'Insulin patient — weekly cadence maintained per High-touch tier. FBG well controlled, no titration change needed this week.' }),
      outreachCall({ id: 'O007-11', offset: 11, coordinatorName: 'Nurse Kavya Suresh', coordinatorRole: 'Nurse', callType: 'Nurse Medication Check-in', durationMin: 12, topics: ['Medication Adherence', 'Device/Monitoring Support'], medAdherenceNotes: 'Reviewed insulin pen storage and rotation of injection sites.', summary: 'Routine nurse check-in on insulin technique and cold-chain storage during a home power outage.' }),
    ],
    smartGoals: [
      goal({ id: 'G007-1', category: 'Diet', description: 'Keep dinner timing within a consistent 1-hour window to match insulin dosing', setDate: daysAgo(30), targetDate: daysAgo(16), status: 'Met' }),
      goal({ id: 'G007-2', category: 'Physical Activity', description: 'Evening walk 15 min after dinner, 5 days/week (post-prandial glucose support)', setDate: daysAgo(16), targetDate: daysAgo(2), status: 'Partially Met', progressNote: 'Averaging 3 days/week.' }),
    ],
  },

  // --- Hypertension + Diabetes (combined) ---
  {
    id: 'P008',
    name: 'Lakshmi Venkataraman',
    age: 70,
    gender: 'Female',
    conditions: ['Hypertension', 'Diabetes'],
    comorbidities: ['Established CVD', 'CKD', 'Elderly'],
    city: 'Bangalore',
    phoneNumber: '+91-80000-10123',
    physicianName: 'Dr. Sunita Rao',
    enrollmentDate: daysAgo(65),
    weightKg: 58,
    htnStep: 2,
    diabetesStep: 'dual',
    hba1cTier: getHbA1cTierInfo(3),
    hba1cReadings: [
      { date: daysAgo(65), value: 8.9 },
      { date: daysAgo(21), value: 8.3 },
    ],
    medications: [
      { name: 'Telmisartan', genericName: 'Telmisartan', drugClass: 'ARB', dose: '40 mg', frequency: 'Once daily', startDate: daysAgo(65) },
      { name: 'Amlodipine', genericName: 'Amlodipine', drugClass: 'CCB', dose: '5 mg', frequency: 'Once daily', startDate: daysAgo(65) },
      { name: 'Chlorthalidone', genericName: 'Chlorthalidone', drugClass: 'Diuretic', dose: '6.25 mg', frequency: 'Once daily', startDate: daysAgo(30) },
      { name: 'Metformin (SR)', genericName: 'Metformin', drugClass: 'Biguanide', dose: '1000 mg', frequency: 'Once daily, evening meal', startDate: daysAgo(65) },
      { name: 'Empagliflozin', genericName: 'Empagliflozin', drugClass: 'SGLT2i', dose: '10 mg', frequency: 'Once daily', startDate: daysAgo(30) },
    ],
    lastReadingTime: minutesAgo(15),
    vitals: mergeVitals(
      dailyBP([
        [140, 88], [144, 91], [138, 86], [148, 94], [142, 89], [146, 93], [150, 96],
        [148, 94], [152, 98], [155, 100], [158, 104], [162, 108], [168, 112], [172, 116],
      ]),
      glucoseReadings([[6, 148, 'fasting'], [3, 155, 'fasting'], [1, 162, 'fasting'], [0, 158, 'fasting']])
    ),
    alerts: [
      {
        id: 'A008',
        patientId: 'P008',
        patientName: 'Lakshmi Venkataraman',
        type: 'BP',
        message: 'Severe Hypertension (Stage III): BP 172/116 mmHg',
        severity: 'critical',
        timestamp: new Date(Date.now() - 15 * 60000).toISOString(),
        acknowledged: false,
      },
    ],
    coachingTier: 'High-touch',
    coachingCallsCompleted: 9,
    coachingCallsTarget: 14,
    outreachLog: [
      outreachCall({ id: 'O008-2', offset: 2, coordinatorName: 'Fathima Rasheed', coordinatorRole: 'Lifestyle Coach', callType: 'Tier Check-in', durationMin: 20, topics: ['Diet', 'Medication Adherence', 'Physical Activity'], dietNotes: 'Family cooking is high-salt; daughter-in-law now included in calls to help modify recipes.', medAdherenceNotes: 'Adherent to all 5 medications, uses a weekly pillbox.', exerciseNotes: 'Limited mobility, chair-based exercises introduced.', summary: 'Both BP and fasting glucose trending above individualized (relaxed, Tier 3) targets — flagged for physician review this call.' }),
      outreachCall({ id: 'O008-9', offset: 9, coordinatorName: 'Nurse Kavya Suresh', coordinatorRole: 'Nurse', callType: 'Nurse Medication Check-in', durationMin: 10, topics: ['Medication Adherence', 'Device/Monitoring Support'], medAdherenceNotes: 'Confirmed correct BP cuff placement after a series of unusually high readings.', summary: 'Technique check ruled out cuff-fit as the cause of elevated readings.' }),
    ],
    smartGoals: [
      goal({ id: 'G008-1', category: 'Diet', description: 'Cut down added salt in diet over the next 2 weeks — family meals cooked with ≤1/2 tsp salt per dish', setDate: daysAgo(12), targetDate: daysAgo(-2), status: 'At Risk', progressNote: 'Daughter-in-law onboarded to help; too early to confirm change.' }),
      goal({ id: 'G008-2', category: 'Physical Activity', description: 'Chair-based exercises 10 min/day, 4 days/week', setDate: daysAgo(12), targetDate: daysAgo(-2), status: 'On Track' }),
    ],
  },
  {
    id: 'P009',
    name: 'Narayan Bose',
    age: 65,
    gender: 'Male',
    conditions: ['Hypertension', 'Diabetes'],
    comorbidities: ['Elderly', 'DKD'],
    city: 'Kolkata',
    phoneNumber: '+91-98300-11234',
    physicianName: 'Dr. Vikram Nair',
    enrollmentDate: daysAgo(80),
    weightKg: 75,
    htnStep: 3,
    diabetesStep: 'triple',
    hba1cTier: getHbA1cTierInfo(2),
    hba1cReadings: [
      { date: daysAgo(80), value: 7.8 },
      { date: daysAgo(25), value: 7.1 },
    ],
    medications: [
      { name: 'Telmisartan', genericName: 'Telmisartan', drugClass: 'ARB', dose: '80 mg', frequency: 'Once daily', startDate: daysAgo(80) },
      { name: 'Amlodipine', genericName: 'Amlodipine', drugClass: 'CCB', dose: '10 mg', frequency: 'Once daily', startDate: daysAgo(80) },
      { name: 'Chlorthalidone', genericName: 'Chlorthalidone', drugClass: 'Diuretic', dose: '12.5 mg', frequency: 'Once daily', startDate: daysAgo(50) },
      { name: 'Metformin (SR)', genericName: 'Metformin', drugClass: 'Biguanide', dose: '1500 mg', frequency: 'Once daily, evening meal', startDate: daysAgo(80) },
      { name: 'Sitagliptin', genericName: 'Sitagliptin', drugClass: 'DPP4i', dose: '100 mg', frequency: 'Once daily', startDate: daysAgo(50) },
      { name: 'Dapagliflozin', genericName: 'Dapagliflozin', drugClass: 'SGLT2i', dose: '5 mg', frequency: 'Once daily', startDate: daysAgo(20) },
    ],
    lastReadingTime: minutesAgo(40),
    vitals: mergeVitals(
      dailyBP([
        [138, 86], [140, 88], [136, 84], [134, 83], [138, 85], [132, 82], [130, 81],
        [134, 83], [131, 82], [129, 80], [128, 80], [130, 81], [127, 79], [129, 80],
      ]),
      glucoseReadings([[8, 128, 'fasting'], [4, 122, 'fasting'], [1, 118, 'fasting']])
    ),
    alerts: [
      {
        id: 'A009',
        patientId: 'P009',
        patientName: 'Narayan Bose',
        type: 'Glucose',
        message: 'Above fasting target: 128 mg/dL',
        severity: 'warning',
        timestamp: new Date(Date.now() - 40 * 60000).toISOString(),
        acknowledged: true,
      },
    ],
    coachingTier: 'Moderate-touch',
    coachingCallsCompleted: 5,
    coachingCallsTarget: 8,
    outreachLog: [
      outreachCall({ id: 'O009-5', offset: 5, coordinatorName: 'Rohan Bhatt', coordinatorRole: 'Lifestyle Coach', callType: 'Tier Check-in', durationMin: 15, topics: ['Diet', 'Physical Activity'], dietNotes: 'Bengali diet high in rice/fish curry — discussed portion control rather than elimination.', exerciseNotes: 'Morning walks 20 min, 4 days/week.', summary: 'Both BP and glucose near target on triple therapy; biweekly cadence continuing.' }),
    ],
    smartGoals: [
      goal({ id: 'G009-1', category: 'Diet', description: 'Reduce rice portion at lunch by one-third, replace with extra vegetables', setDate: daysAgo(19), targetDate: daysAgo(5), status: 'Partially Met', progressNote: 'Consistent about half the week.' }),
      goal({ id: 'G009-2', category: 'Physical Activity', description: 'Morning walk 20 min/day, 5 days/week', setDate: daysAgo(19), targetDate: daysAgo(5), status: 'On Track' }),
    ],
  },
  {
    id: 'P010',
    name: 'Deepa Nambiar',
    age: 57,
    gender: 'Female',
    conditions: ['Hypertension', 'Diabetes'],
    comorbidities: [],
    city: 'Kochi',
    phoneNumber: '+91-94470-22345',
    physicianName: 'Dr. Anita Desai',
    enrollmentDate: daysAgo(12),
    weightKg: 68,
    htnStep: 1,
    diabetesStep: 'metformin',
    hba1cTier: getHbA1cTierInfo(2),
    hba1cReadings: [{ date: daysAgo(12), value: 7.6 }],
    medications: [
      { name: 'Ramipril', genericName: 'Ramipril', drugClass: 'ACE', dose: '2.5 mg', frequency: 'Once daily', startDate: daysAgo(12) },
      { name: 'Amlodipine', genericName: 'Amlodipine', drugClass: 'CCB', dose: '5 mg', frequency: 'Once daily', startDate: daysAgo(12) },
      { name: 'Metformin (IR)', genericName: 'Metformin', drugClass: 'Biguanide', dose: '500 mg', frequency: 'Twice daily with meals', startDate: daysAgo(12) },
    ],
    lastReadingTime: minutesAgo(25),
    vitals: mergeVitals(
      dailyBP([
        [136, 86], [134, 85], [138, 87], [132, 84], [135, 85], [130, 83], [133, 84],
        [128, 82], [131, 83], [126, 81], [129, 82],
      ]),
      glucoseReadings([[8, 142, 'fasting'], [5, 138, 'fasting'], [2, 130, 'fasting']])
    ),
    alerts: [],
    coachingTier: 'High-touch',
    coachingCallsCompleted: 1,
    coachingCallsTarget: 14,
    outreachLog: [
      outreachCall({ id: 'O010-1', offset: 1, coordinatorName: 'Divya Menon', coordinatorRole: 'Lifestyle Coach', callType: 'Week 1 Initial Assessment', durationMin: 42, topics: ['Diet', 'Physical Activity', 'Medication Adherence', 'Tobacco/Alcohol Use'], dietNotes: 'Newly diagnosed — baseline diet high in rice and fried snacks; no major changes attempted yet.', exerciseNotes: 'Currently sedentary.', medAdherenceNotes: 'New to all 3 medications — reviewed timing and metformin GI-tolerance counseling.', summary: 'Newly diagnosed (<3 months), assigned High-touch tier per protocol. Baseline SMART goals set this call.' }),
    ],
    smartGoals: [
      goal({ id: 'G010-1', category: 'Diet', description: 'Cut down added salt in diet over the next 2 weeks — no pickle/papad, taste before salting', setDate: daysAgo(1), targetDate: daysAgo(-13), status: 'On Track' }),
      goal({ id: 'G010-2', category: 'Physical Activity', description: 'Start 10 min walk after dinner, building toward 150 min/week', setDate: daysAgo(1), targetDate: daysAgo(-13), status: 'On Track' }),
      goal({ id: 'G010-3', category: 'Medication Adherence', description: 'Take metformin with meals both times daily to reduce GI upset and support adherence', setDate: daysAgo(1), targetDate: daysAgo(-13), status: 'On Track' }),
    ],
  },
];

function outreachCall(params: {
  id: string;
  offset: number;
  coordinatorName: string;
  coordinatorRole: OutreachCall['coordinatorRole'];
  callType: OutreachCall['callType'];
  durationMin: number;
  topics: OutreachCall['topics'];
  dietNotes?: string;
  exerciseNotes?: string;
  medAdherenceNotes?: string;
  summary: string;
}): OutreachCall {
  return {
    id: params.id,
    date: daysAgo(params.offset),
    coordinatorName: params.coordinatorName,
    coordinatorRole: params.coordinatorRole,
    callType: params.callType,
    durationMin: params.durationMin,
    topics: params.topics,
    dietNotes: params.dietNotes,
    exerciseNotes: params.exerciseNotes,
    medAdherenceNotes: params.medAdherenceNotes,
    summary: params.summary,
  };
}

function goal(params: {
  id: string;
  category: SmartGoal['category'];
  description: string;
  setDate: string;
  targetDate: string;
  status: SmartGoal['status'];
  progressNote?: string;
}): SmartGoal {
  return params;
}

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
    .filter((p) => !condition || condition === 'All' || p.conditions.includes(condition as Patient['conditions'][number]))
    .map((p) => {
      const latestVitals = getLatestVitalsSummary(p);
      return {
        id: p.id,
        name: p.name,
        age: p.age,
        conditions: p.conditions,
        city: p.city,
        alertStatus: p.alertStatus,
        lastReadingTime: p.lastReadingTime,
        latestVitals,
        coachingTier: p.coachingTier,
        coachingCallsCompleted: p.coachingCallsCompleted,
        coachingCallsTarget: p.coachingCallsTarget,
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
  const outreachThisProgram = mockPatients.reduce((sum, p) => sum + p.coachingCallsCompleted, 0);

  return { total, critical, warning, stable, activeAlerts, outreachThisProgram };
}

export function getRecentAlerts() {
  return mockPatients
    .flatMap((p) => p.alerts)
    .filter((a) => !a.acknowledged)
    .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
    .slice(0, 10);
}
