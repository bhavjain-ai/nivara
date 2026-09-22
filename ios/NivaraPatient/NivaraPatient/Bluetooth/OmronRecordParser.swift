import Foundation

/// Decodes the cuff's "latest reading" EEPROM slots into the same
/// `ParsedBloodPressureMeasurement` the rest of the app already consumes
/// from the standard-profile path.
///
/// Field offsets below are not reverse-engineered guesses — they're read
/// directly off a real HCI/BLE sniffer capture (Apple PacketLogger) of the
/// official OMRON connect app syncing with this exact cuff (BP786N /
/// HEM-7321T-Z). All six metadata fields and both value fields decoded to
/// the exact values of a known real reading (111/71 mmHg, pulse 67bpm,
/// 18:48, 9/21) — see OmronProtocol.swift's record-format doc comment.
enum OmronRecordParser {
    static func parseLatestReading(metadata: [UInt8], values: [UInt8]) -> ParsedBloodPressureMeasurement? {
        guard metadata.count > 29, values.count > 3 else { return nil }

        let month = Int(metadata[22])
        let year = Int(metadata[23]) + 2000
        let hour = Int(metadata[24])
        let day = Int(metadata[25])
        let minute = Int(metadata[27])
        let systolic = Int(metadata[29])

        let diastolic = Int(values[0])
        let pulse = Int(values[3])

        guard month >= 1, month <= 12, day >= 1, day <= 31, hour <= 23, minute <= 59 else { return nil }
        guard systolic > diastolic, systolic < 300, diastolic > 0 else {
            // Guards against treating an empty/garbage EEPROM slot as a
            // real reading — fail rather than show a fabricated value.
            return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        let timestamp = Calendar(identifier: .gregorian).date(from: components)

        return ParsedBloodPressureMeasurement(
            systolic: systolic,
            diastolic: diastolic,
            meanArterialPressure: nil,
            pulseRate: pulse,
            timestamp: timestamp
        )
    }
}
