import Foundation
import Combine

final class PatientViewModel: ObservableObject {
    let profile: PatientProfile
    let vitals: VitalsStore
    let bleManager: BLEManager

    @Published private(set) var latestBPStatus: VitalStatus?
    @Published private(set) var latestGlucoseStatus: VitalStatus?
    /// Set right after a fresh BLE reading lands, so Home can show a warm,
    /// status-aware confirmation before it fades.
    @Published private(set) var postMeasurementMessage: PostMeasurementMessage?

    private var vitalsCancellable: AnyCancellable?
    private var bleCancellable: AnyCancellable?

    init(profile: PatientProfile = DemoPatientData.patient, vitals: VitalsStore = VitalsStore(), bleManager: BLEManager = BLEManager()) {
        self.profile = profile
        self.vitals = vitals
        self.bleManager = bleManager

        bleManager.onBPReading = { [weak self] parsed in
            guard let self else { return }
            self.vitals.addBPReading(
                systolic: parsed.systolic,
                diastolic: parsed.diastolic,
                pulse: parsed.pulseRate,
                date: parsed.timestamp ?? Date()
            )
            if let target = self.profile.bpTarget {
                let status = ClinicalGuidelines.analyzeBP(systolic: parsed.systolic, diastolic: parsed.diastolic, target: target)
                self.showReassurance(for: status.level)
            }
        }

        bleManager.onGlucoseReading = { [weak self] parsed in
            guard let self, let mgDl = parsed.glucoseMgDl else { return }
            self.vitals.addGlucoseReading(
                mgDl: mgDl,
                sampleType: parsed.sampleType,
                date: parsed.timestamp ?? Date()
            )
            if let tier = self.profile.hba1cTier {
                let targets = ClinicalGuidelines.glucoseTargets(forTier: tier.tier)
                let status = ClinicalGuidelines.analyzeGlucose(glucose: mgDl, sampleType: parsed.sampleType, targets: targets)
                self.showReassurance(for: status.level)
            }
        }

        // Re-derive status labels any time the underlying history changes
        // (new BLE reading, retag, etc).
        vitalsCancellable = vitals.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.refreshStatus() }
        }

        // `vitals` and `bleManager` are their own ObservableObjects held by
        // reference here, so their @Published changes (scan results,
        // connection state, ...) don't automatically propagate to anything
        // observing PatientViewModel. Relay them through explicitly so
        // @EnvironmentObject var viewModel: PatientViewModel actually
        // re-renders when e.g. BLEManager finds a device or connects.
        bleCancellable = bleManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }

        refreshStatus()
    }

    private func showReassurance(for level: VitalStatusLevel) {
        postMeasurementMessage = PostMeasurementMessage(level: level, text: ClinicalGuidelines.reassuranceMessage(for: level))
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.postMeasurementMessage = nil
        }
    }

    func refreshStatus() {
        if let bp = vitals.latestBP, let target = profile.bpTarget {
            latestBPStatus = ClinicalGuidelines.analyzeBP(systolic: bp.systolic, diastolic: bp.diastolic, target: target)
        }
        if let glucose = vitals.latestGlucose, let tier = profile.hba1cTier {
            let targets = ClinicalGuidelines.glucoseTargets(forTier: tier.tier)
            latestGlucoseStatus = ClinicalGuidelines.analyzeGlucose(glucose: glucose.glucoseMgDl, sampleType: glucose.sampleType, targets: targets)
        }
    }

    /// Whether the patient has logged at least one BP or glucose reading today
    /// (BLE or otherwise) — drives the Home screen's "thank you" vs. "take a
    /// measurement" prompt.
    var tookReadingToday: Bool {
        let calendar = Calendar.current
        let bpToday = vitals.latestBP.map { calendar.isDateInToday($0.date) } ?? false
        let glucoseToday = vitals.latestGlucose.map { calendar.isDateInToday($0.date) } ?? false
        return bpToday || glucoseToday
    }
}
