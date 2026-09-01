import Foundation

/// Bundled demo profile + seed vitals history so the app has something to show
/// before any BLE device is connected. Mirrors the shape (and one of the actual
/// patients) of the web dashboard's src/lib/mock-data.ts.
enum DemoPatientData {

    private static func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Date()) ?? Date()
    }

    static let patient = PatientProfile(
        name: "Anita Kumar",
        physicianName: "Dr. Sunita Rao",
        physicianPhone: "+91-80000-99999",
        conditions: [.hypertension, .diabetes],
        bpTarget: BPTarget(
            systolic: 129,
            diastolic: 79,
            label: "120–129/70–79 mmHg (diabetes-comorbid target, IGH-V/RSSDI 2022, where tolerated)"
        ),
        hba1cTier: ClinicalGuidelines.hba1cTierInfo(tier: 2),
        medications: [
            Medication(name: "Telmisartan", drugClass: "ARB", dose: "40 mg", frequency: "Once daily", startDate: daysAgo(60)),
            Medication(name: "Amlodipine", drugClass: "CCB", dose: "5 mg", frequency: "Once daily", startDate: daysAgo(60)),
            Medication(name: "Metformin (SR)", drugClass: "Biguanide", dose: "1000 mg", frequency: "Once daily, evening meal", startDate: daysAgo(60)),
        ],
        medicationHistory: [
            MedicationChange(date: daysAgo(60), description: "Started Telmisartan 40 mg + Amlodipine 5 mg (dual therapy)", relatedCondition: .hypertension),
            MedicationChange(date: daysAgo(60), description: "Started Metformin (SR) 500 mg", relatedCondition: .diabetes),
            MedicationChange(date: daysAgo(30), description: "Increased Metformin (SR) from 500 mg to 1000 mg", relatedCondition: .diabetes),
        ],
        coachingTier: .moderateTouch,
        coachingCallsCompleted: 4,
        coachingCallsTarget: 8,
        outreachLog: [
            OutreachCall(
                date: daysAgo(2),
                coordinatorName: "Dr. Sunita Rao",
                coordinatorRole: .physician,
                callType: "Telemedicine Consult",
                durationMin: 12,
                topics: ["Medication Adherence"],
                summary: "Reviewed your blood pressure trend and confirmed the current Telmisartan/Amlodipine dose is working well — no changes needed this visit."
            ),
            OutreachCall(
                date: daysAgo(30),
                coordinatorName: "Dr. Sunita Rao",
                coordinatorRole: .physician,
                callType: "Telemedicine Consult",
                durationMin: 15,
                topics: ["Medication Adherence"],
                summary: "Fasting glucose still above target on Metformin 500 mg, so increased the dose to 1000 mg and asked for a recheck in 2 weeks."
            ),
            OutreachCall(
                date: daysAgo(4),
                coordinatorName: "Rohan Bhatt",
                coordinatorRole: .dietician,
                callType: "Tier Check-in",
                durationMin: 16,
                topics: ["Diet", "Medication Adherence"],
                summary: "Reviewed home-cooked meals and salt use; adherence to all 3 medications confirmed via weekly pillbox."
            ),
            OutreachCall(
                date: daysAgo(18),
                coordinatorName: "Rohan Bhatt",
                coordinatorRole: .dietician,
                callType: "Tier Check-in",
                durationMin: 14,
                topics: ["Diet"],
                summary: "Set the sodium-reduction goal for the next two weeks and shared a low-salt Karnataka thali swap list."
            ),
            OutreachCall(
                date: daysAgo(11),
                coordinatorName: "Kavya Suresh",
                coordinatorRole: .coach,
                callType: "Coach Check-in",
                durationMin: 10,
                topics: ["Medication Adherence", "Device/Monitoring Support"],
                summary: "Walked through BP cuff placement and confirmed the Nivara app was pairing correctly over Bluetooth."
            ),
        ],
        smartGoals: [
            SmartGoal(
                category: "Diet",
                description: "Cut down added salt in diet over the next 2 weeks — no extra salt at the table, limit outside food to 2x/week",
                setDate: daysAgo(10),
                targetDate: daysAgo(-4),
                status: .onTrack,
                progressNote: "Down to eating out once this week."
            ),
            SmartGoal(
                category: "Physical Activity",
                description: "Walk 20 minutes/day, 5 days/week",
                setDate: daysAgo(10),
                targetDate: daysAgo(-4),
                status: .partiallyMet,
                progressNote: "Averaging 3 days/week so far."
            ),
        ]
    )

    /// Seed BP history so History charts aren't empty on first launch. The most
    /// recent seeded reading is dated yesterday (not today) so a fresh install
    /// correctly shows the "take a measurement" prompt rather than "thanks for
    /// measuring today" for a reading the patient never actually took.
    static let demoBPReadings: [BPReading] = {
        let values: [(Int, Int)] = [
            (138, 88), (134, 85), (136, 86), (132, 84), (130, 82),
            (128, 81), (131, 83), (127, 80), (126, 79), (129, 81),
        ]
        return values.enumerated().map { index, pair in
            BPReading(date: daysAgo(values.count - index), systolic: pair.0, diastolic: pair.1, pulse: 76, source: .demo)
        }
    }()

    /// Seed glucose history — sparse, matching the individualized SMBG frequency
    /// (not a flat daily test) that the titration protocol calls for.
    static let demoGlucoseReadings: [GlucoseReading] = {
        let values: [(Int, Int, GlucoseSampleType)] = [
            (8, 138, .fasting), (6, 145, .postMeal), (5, 132, .fasting),
            (3, 128, .fasting), (1, 140, .postMeal),
        ]
        return values.map { offset, glucose, type in
            GlucoseReading(date: daysAgo(offset), glucoseMgDl: glucose, sampleType: type, source: .demo)
        }
    }()

    static let demoHbA1cReadings: [HbA1cReading] = [
        HbA1cReading(date: daysAgo(60), value: 7.8),
        HbA1cReading(date: daysAgo(14), value: 7.2),
    ]
}
