import Foundation

/// Swift port of the web dashboard's src/lib/guidelines.ts, kept logically identical
/// so a reading classifies the same way here as it would for the physician.
enum ClinicalGuidelines {

    static func hba1cTierInfo(tier: Int) -> HbA1cTierInfo {
        switch tier {
        case 1: return HbA1cTierInfo(tier: 1, targetLabel: "6.5%", targetValue: 6.5)
        case 3: return HbA1cTierInfo(tier: 3, targetLabel: "7.5–8.0%", targetValue: 8.0)
        default: return HbA1cTierInfo(tier: 2, targetLabel: "<7.0%", targetValue: 7.0)
        }
    }

    static func glucoseTargets(forTier tier: Int) -> GlucoseTargetRange {
        if tier == 3 {
            return GlucoseTargetRange(population: .relaxed, fastingLow: 90, fastingHigh: 150, postprandialHigh: 250)
        }
        return GlucoseTargetRange(population: .standard, fastingLow: 80, fastingHigh: 130, postprandialHigh: 180)
    }

    // MARK: - Blood pressure (IGH-V 2025-2026, Fig. 14 / Table 1)

    private static func classifyBPStage(systolic: Int, diastolic: Int) -> (level: VitalStatusLevel, label: String)? {
        if systolic >= 180 || diastolic >= 120 {
            return (.critical, "Hypertensive Crisis / Emergency")
        }
        if diastolic >= 110 {
            return (.critical, "Severe Hypertension (Stage III)")
        }
        if systolic >= 160 || diastolic >= 100 {
            return (.critical, "Moderate Hypertension (Stage II)")
        }
        if systolic >= 140 || diastolic >= 90 {
            return (.warning, "Mild Hypertension (Stage I)")
        }
        return nil
    }

    static func analyzeBP(systolic: Int, diastolic: Int, target: BPTarget) -> VitalStatus {
        if let stage = classifyBPStage(systolic: systolic, diastolic: diastolic) {
            let guideline = (systolic >= 180 || diastolic >= 120)
                ? "IGH-V: SBP ≥180 or DBP ≥120 mmHg is an urgent alert threshold — contact your care team now."
                : "IGH-V Step-Care Table 1 (presenting BP severity): \(stage.label)."
            return VitalStatus(level: stage.level, message: "\(stage.label): \(systolic)/\(diastolic) mmHg", guideline: guideline)
        }

        if systolic > target.systolic || diastolic > target.diastolic {
            return VitalStatus(
                level: .warning,
                message: "Above your target: \(systolic)/\(diastolic) mmHg",
                guideline: "Your target is \(target.label)."
            )
        }

        return VitalStatus(
            level: .normal,
            message: "At target: \(systolic)/\(diastolic) mmHg",
            guideline: "Within your target (\(target.label))."
        )
    }

    // MARK: - Blood glucose (RSSDI 2022/2024, ADA Standards of Care 2026)

    static func analyzeGlucose(glucose: Int, sampleType: GlucoseSampleType, targets: GlucoseTargetRange) -> VitalStatus {
        if glucose < 54 {
            return VitalStatus(
                level: .critical,
                message: "Very Low Glucose: \(glucose) mg/dL",
                guideline: "RSSDI/ADA: <54 mg/dL (Level 2 hypoglycemia) — contact your care team immediately."
            )
        }
        if glucose < 70 {
            return VitalStatus(
                level: .critical,
                message: "Low Glucose: \(glucose) mg/dL",
                guideline: "RSSDI/ADA: <70 mg/dL (Level 1 hypoglycemia) — treat now and tell a family member."
            )
        }
        if glucose > 300 {
            return VitalStatus(
                level: .critical,
                message: "Very High Glucose: \(glucose) mg/dL",
                guideline: "RSSDI/ADA: >300 mg/dL — contact your care team."
            )
        }

        let targetLabel = targets.population == .relaxed ? "your relaxed target range" : "your target range"

        switch sampleType {
        case .fasting:
            if glucose > targets.fastingHigh {
                return VitalStatus(
                    level: .warning,
                    message: "Above fasting target: \(glucose) mg/dL",
                    guideline: "Fasting target \(targets.fastingLow)–\(targets.fastingHigh) mg/dL (\(targetLabel))."
                )
            }
            if glucose < targets.fastingLow {
                return VitalStatus(
                    level: .warning,
                    message: "Below fasting target: \(glucose) mg/dL",
                    guideline: "Fasting target \(targets.fastingLow)–\(targets.fastingHigh) mg/dL (\(targetLabel))."
                )
            }
            return VitalStatus(
                level: .normal,
                message: "At fasting target: \(glucose) mg/dL",
                guideline: "Fasting target \(targets.fastingLow)–\(targets.fastingHigh) mg/dL."
            )
        case .postMeal:
            if glucose > targets.postprandialHigh {
                return VitalStatus(
                    level: .warning,
                    message: "Above post-meal target: \(glucose) mg/dL",
                    guideline: "Post-meal (2hr) target <\(targets.postprandialHigh) mg/dL (\(targetLabel))."
                )
            }
            return VitalStatus(
                level: .normal,
                message: "At post-meal target: \(glucose) mg/dL",
                guideline: "Post-meal (2hr) target <\(targets.postprandialHigh) mg/dL."
            )
        }
    }
}
