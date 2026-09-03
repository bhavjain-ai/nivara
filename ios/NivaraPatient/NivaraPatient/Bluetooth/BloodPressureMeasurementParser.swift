import Foundation

struct ParsedBloodPressureMeasurement {
    let systolic: Int
    let diastolic: Int
    let meanArterialPressure: Int?
    let pulseRate: Int?
    let timestamp: Date?
}

/// Parses the Blood Pressure Measurement characteristic (0x2A35) per the
/// Bluetooth SIG Blood Pressure Service spec.
///
/// Layout: Flags(1) | Systolic(2, SFLOAT) | Diastolic(2, SFLOAT) | MAP(2, SFLOAT)
/// | [Time Stamp(7, Date Time)] | [Pulse Rate(2, SFLOAT)] | [User ID(1)]
/// | [Measurement Status(2)] — bracketed fields present only if their flag bit is set.
enum BloodPressureMeasurementParser {
    static func parse(_ data: Data) -> ParsedBloodPressureMeasurement? {
        guard data.count >= 7 else { return nil } // flags + sys + dia + map is the minimum
        var offset = 0

        let flags = data[data.startIndex]
        offset += 1

        let unitsAreKPa = flags & 0x01 != 0
        let timestampPresent = flags & 0x02 != 0
        let pulsePresent = flags & 0x04 != 0

        let sysRaw = readUInt16LE(data, at: offset); offset += 2
        let diaRaw = readUInt16LE(data, at: offset); offset += 2
        let mapRaw = readUInt16LE(data, at: offset); offset += 2

        guard let sysVal = IEEE11073.decodeSFLOAT(sysRaw),
              let diaVal = IEEE11073.decodeSFLOAT(diaRaw) else { return nil }
        let mapVal = IEEE11073.decodeSFLOAT(mapRaw)

        // 1 kPa = 7.50062 mmHg. Nivara (and the physician dashboard) works in mmHg throughout.
        let factor = unitsAreKPa ? 7.50062 : 1.0

        var timestamp: Date?
        if timestampPresent, data.count >= offset + 7 {
            timestamp = readDateTime(data, at: offset)
            offset += 7
        }

        var pulse: Int?
        if pulsePresent, data.count >= offset + 2 {
            let pulseRaw = readUInt16LE(data, at: offset)
            offset += 2
            pulse = IEEE11073.decodeSFLOAT(pulseRaw).map { Int($0.rounded()) }
        }

        return ParsedBloodPressureMeasurement(
            systolic: Int((sysVal * factor).rounded()),
            diastolic: Int((diaVal * factor).rounded()),
            meanArterialPressure: mapVal.map { Int(($0 * factor).rounded()) },
            pulseRate: pulse,
            timestamp: timestamp
        )
    }
}
