import Foundation

/// Holds the patient's BP / glucose / HbA1c history: seeded from demo data on
/// first launch, appended to live as BLE readings arrive, and persisted to disk
/// (plain JSON files in the app's Documents directory) so history survives an
/// app relaunch.
final class VitalsStore: ObservableObject {
    @Published private(set) var bpReadings: [BPReading] = []
    @Published private(set) var glucoseReadings: [GlucoseReading] = []
    @Published private(set) var hba1cReadings: [HbA1cReading] = []

    private let bpFilename = "bp_readings.json"
    private let glucoseFilename = "glucose_readings.json"

    init(seed: PatientProfile = DemoPatientData.patient) {
        loadPersisted()
        if bpReadings.isEmpty {
            bpReadings = DemoPatientData.demoBPReadings
        }
        if glucoseReadings.isEmpty {
            glucoseReadings = DemoPatientData.demoGlucoseReadings
        }
        hba1cReadings = DemoPatientData.demoHbA1cReadings
    }

    var latestBP: BPReading? { bpReadings.last }
    var latestGlucose: GlucoseReading? { glucoseReadings.last }
    var latestHbA1c: HbA1cReading? { hba1cReadings.last }

    func addBPReading(systolic: Int, diastolic: Int, pulse: Int?, date: Date = Date(), source: ReadingSource = .bleDevice) {
        // The standard-profile BLE path only ever offers one fresh/last-
        // stored reading per connect, so duplicates were never a practical
        // concern before. The Omron path (OmronBLEHandler) re-reads a
        // cuff's *entire* stored history on every connect, so without this
        // guard, reconnecting would re-append the same historical readings
        // every time.
        guard !bpReadings.contains(where: { $0.date == date && $0.systolic == systolic && $0.diastolic == diastolic }) else { return }
        let reading = BPReading(date: date, systolic: systolic, diastolic: diastolic, pulse: pulse, source: source)
        bpReadings.append(reading)
        bpReadings.sort { $0.date < $1.date }
        persist()
    }

    func addGlucoseReading(mgDl: Int, sampleType: GlucoseSampleType, date: Date = Date(), source: ReadingSource = .bleDevice) {
        let reading = GlucoseReading(date: date, glucoseMgDl: mgDl, sampleType: sampleType, source: source)
        glucoseReadings.append(reading)
        glucoseReadings.sort { $0.date < $1.date }
        persist()
    }

    /// Lets the patient correct the fasting/post-meal guess the app made for
    /// the most recent BLE reading (meters don't reliably signal which one it was).
    func retagLatestGlucose(as sampleType: GlucoseSampleType) {
        guard let last = glucoseReadings.popLast() else { return }
        let retagged = GlucoseReading(id: last.id, date: last.date, glucoseMgDl: last.glucoseMgDl, sampleType: sampleType, source: last.source)
        glucoseReadings.append(retagged)
        persist()
    }

    private func documentsURL(_ filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
    }

    private func persist() {
        try? JSONEncoder.nivara.encode(bpReadings).write(to: documentsURL(bpFilename))
        try? JSONEncoder.nivara.encode(glucoseReadings).write(to: documentsURL(glucoseFilename))
    }

    private func loadPersisted() {
        if let data = try? Data(contentsOf: documentsURL(bpFilename)),
           let decoded = try? JSONDecoder.nivara.decode([BPReading].self, from: data) {
            bpReadings = decoded
        }
        if let data = try? Data(contentsOf: documentsURL(glucoseFilename)),
           let decoded = try? JSONDecoder.nivara.decode([GlucoseReading].self, from: data) {
            glucoseReadings = decoded
        }
    }
}
