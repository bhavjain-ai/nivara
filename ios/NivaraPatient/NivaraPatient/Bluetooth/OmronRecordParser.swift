import Foundation

/// Decodes a single stored blood-pressure record from an Omron cuff's
/// EEPROM into the same `ParsedBloodPressureMeasurement` the rest of the app
/// already consumes from the standard-profile path.
///
/// Field offsets below are reverse-engineered directly against real BP786N /
/// HEM-7321T-Z hardware (see OmronProtocol.swift's record-format doc
/// comment for how) — this is no longer a guess borrowed from another
/// model. Confirmed against one real reading (93/67 mmHg, pulse 62, taken
/// ~14:35 device-local time): pulse, diastolic, systolic, minute, and hour
/// all decoded to that reading's exact values.
enum OmronRecordParser {
    static func parse(_ recordBytes: [UInt8]) -> ParsedBloodPressureMeasurement? {
        guard recordBytes.count == OmronProtocol.recordByteSize else { return nil }

        // Byte-aligned — confirmed exact matches, no scaling/offset needed
        // (the previous layout's "systolic + 25" was specific to the wrong
        // record format and doesn't apply here).
        let pulse = Int(recordBytes[4])
        let diastolic = Int(recordBytes[5])
        let systolic = Int(recordBytes[13])

        guard systolic > diastolic, systolic < 300, diastolic > 0 else {
            // Guards against treating an empty/garbage EEPROM slot as a
            // real reading — fail this one record rather than show a
            // fabricated value.
            return nil
        }

        // Bit-packed — confirmed exact matches against the same reading.
        let minute = Int(bitsToInt(recordBytes, 87, 92))
        let hour = Int(bitsToInt(recordBytes, 93, 97))
        guard hour <= 23, minute <= 59 else { return nil }

        // day/month/year were NOT independently confirmed — see
        // OmronProtocol.swift's doc comment: several candidate bit offsets
        // all looked equally plausible from one data point, unlike
        // minute/hour which each had exactly one bit offset that produced
        // the real value. Rather than guess and risk silently mislabeling
        // an old reading with a fabricated recent-looking date, every
        // record is timestamped using the *phone's* current date combined
        // with the device's (confirmed) hour:minute. This is correct for
        // the one thing this app actually uses the timestamp for — "is
        // this reading from the last few minutes" (see
        // OmronBLEHandler.freshestReading) — as long as the cuff's clock
        // is on the same day as the phone, which holds for the read-right-
        // after-taking-a-measurement flow this app relies on. It is NOT a
        // real historical date for older stored records; an old record
        // would only be mistaken for a fresh one if its hour:minute
        // happens to land within the freshness window purely by chance.
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        let timestamp = Calendar(identifier: .gregorian).date(from: components)

        return ParsedBloodPressureMeasurement(
            systolic: systolic,
            diastolic: diastolic,
            meanArterialPressure: nil,
            pulseRate: pulse,
            timestamp: timestamp
        )
    }

    /// A direct port of omblepy's `_bytearrayBitsToInt`: treats the whole
    /// byte array as one big integer (endianness per
    /// `OmronProtocol.deviceEndianessIsLittle`) and extracts the bit range
    /// `[firstValidBitIdx, lastValidBitIdx]`, where bit 0 is the most
    /// significant bit of that big integer — NOT necessarily the first byte
    /// in memory order once endianness is taken into account.
    private static func bitsToInt(_ bytes: [UInt8], _ firstValidBitIdx: Int, _ lastValidBitIdx: Int) -> UInt64 {
        let byteCount = bytes.count
        var result: UInt64 = 0
        for bitIdx in firstValidBitIdx...lastValidBitIdx {
            let byteOrderIndex = bitIdx / 8
            let byteIndex = OmronProtocol.deviceEndianessIsLittle ? (byteCount - 1 - byteOrderIndex) : byteOrderIndex
            let bitInByte = 7 - (bitIdx % 8) // 7 = most significant bit of the byte
            let bit = (bytes[byteIndex] >> bitInByte) & 0x01
            result = (result << 1) | UInt64(bit)
        }
        return result
    }
}
