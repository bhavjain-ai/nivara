import Foundation

struct ParsedGlucoseMeasurement {
    let sequenceNumber: UInt16
    let timestamp: Date?
    let glucoseMgDl: Int?
    let sampleType: GlucoseSampleType
}

/// Parses the Glucose Measurement characteristic (0x2A18) per the Bluetooth SIG
/// Glucose Service spec.
///
/// Layout: Flags(1) | Sequence Number(2, LE) | Base Time(7, Date Time) |
/// [Time Offset(2, sint16 minutes)] | [Glucose Concentration(2, SFLOAT) +
/// Type-Sample Location(1)] | [Sensor Status Annunciation(2)]
/// — bracketed fields are present only if their flag bit is set.
enum GlucoseMeasurementParser {
    static func parse(_ data: Data) -> ParsedGlucoseMeasurement? {
        guard data.count >= 10 else { return nil } // flags + seq + base time is the minimum
        var offset = 0

        let flags = data[data.startIndex]
        offset += 1

        let timeOffsetPresent = flags & 0x01 != 0
        let concentrationPresent = flags & 0x02 != 0
        let unitsAreMolPerL = flags & 0x04 != 0
        let statusPresent = flags & 0x08 != 0

        let sequenceNumber = readUInt16LE(data, at: offset)
        offset += 2

        let baseTime = readDateTime(data, at: offset)
        offset += 7

        var timestamp = baseTime
        if timeOffsetPresent {
            guard data.count >= offset + 2 else { return nil }
            let rawOffset = readUInt16LE(data, at: offset)
            let minutesOffset = Int(Int16(bitPattern: rawOffset))
            offset += 2
            if let base = baseTime {
                timestamp = Calendar.current.date(byAdding: .minute, value: minutesOffset, to: base)
            }
        }

        var glucoseMgDl: Int?
        if concentrationPresent {
            guard data.count >= offset + 3 else { return nil }
            let raw = readUInt16LE(data, at: offset)
            offset += 2
            offset += 1 // type-sample location byte — not surfaced in the UI

            if let value = IEEE11073.decodeSFLOAT(raw) {
                // Concentration is in kg/L unless the units flag says mol/L.
                // 1 kg/L = 100,000 mg/dL. 1 mol/L glucose ≈ 18,018.2 mg/dL.
                let mgdl = unitsAreMolPerL ? value * 18018.2 : value * 100_000.0
                glucoseMgDl = Int(mgdl.rounded())
            }
        }

        if statusPresent {
            offset += 2
        }

        // The meal-type nibble on this characteristic doesn't distinguish
        // fasting vs. post-meal — that lives on the Context characteristic
        // (0x2A34), which BLEManager correlates in before calling back.
        return ParsedGlucoseMeasurement(sequenceNumber: sequenceNumber, timestamp: timestamp, glucoseMgDl: glucoseMgDl, sampleType: .fasting)
    }
}

enum GlucoseContextParser {
    /// Best-effort signal only: returns true if the Glucose Measurement Context
    /// (0x2A34) carries a "Meal" field, which BLEManager treats as evidence the
    /// paired reading was taken after a meal. The meter doesn't send an explicit
    /// "fasting" flag, so this is a heuristic — the patient can retag any
    /// reading in the app (History tab) if this guess is wrong.
    static func hasMealField(_ data: Data) -> Bool {
        guard data.count >= 1 else { return false }
        let flags = data[data.startIndex]
        // Glucose Measurement Context flags, bit 2 = Meal field present.
        return flags & 0x04 != 0
    }
}
