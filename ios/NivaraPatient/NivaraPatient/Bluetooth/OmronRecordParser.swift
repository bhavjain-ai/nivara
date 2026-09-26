import Foundation

/// Decodes the cuff's "latest reading" data into the same
/// `ParsedBloodPressureMeasurement` the rest of the app already consumes
/// from the standard-profile path.
///
/// Field offsets below are not reverse-engineered guesses — they're read
/// directly off two real HCI/BLE sniffer captures (Apple PacketLogger) of
/// the official OMRON connect app syncing with this exact cuff (BP786N /
/// HEM-7321T-Z), against two independent known-ground-truth readings
/// (111/71 mmHg pulse 67bpm, and 112/73 mmHg). See OmronProtocol.swift's
/// record-format doc comment for the full derivation.
enum OmronRecordParser {
    /// Decodes one 14-byte "values" ring record. Returns nil for a blank
    /// (unwritten, all-0xFF) ring slot or an implausible value — callers
    /// scanning the ring should treat either as "not a real reading" and
    /// keep looking, rather than trust a fabricated/empty slot.
    static func parseValuesRecord(_ record: [UInt8]) -> (systolic: Int, diastolic: Int, pulse: Int)? {
        guard record.count >= 4 else { return nil }
        if record.allSatisfy({ $0 == 0xff }) { return nil }

        let diastolic = Int(record[0])
        let systolic = Int(record[1]) + 25
        let pulse = Int(record[3])

        guard systolic > diastolic, systolic < 300, diastolic > 0 else { return nil }
        return (systolic: systolic, diastolic: diastolic, pulse: pulse)
    }

    static func parseLatestReading(metadata: [UInt8], latestValuesRecord: [UInt8]) -> ParsedBloodPressureMeasurement? {
        guard metadata.count > 27, let values = parseValuesRecord(latestValuesRecord) else { return nil }

        let month = Int(metadata[22])
        let year = Int(metadata[23]) + 2000
        let hour = Int(metadata[24])
        let day = Int(metadata[25])
        let minute = Int(metadata[27])

        guard month >= 1, month <= 12, day >= 1, day <= 31, hour <= 23, minute <= 59 else { return nil }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        let timestamp = Calendar(identifier: .gregorian).date(from: components)

        return ParsedBloodPressureMeasurement(
            systolic: values.systolic,
            diastolic: values.diastolic,
            meanArterialPressure: nil,
            pulseRate: values.pulse,
            timestamp: timestamp
        )
    }
}
