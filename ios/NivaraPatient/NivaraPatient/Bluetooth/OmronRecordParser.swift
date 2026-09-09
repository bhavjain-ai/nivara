import Foundation

/// Decodes a single stored blood-pressure record from an Omron cuff's
/// EEPROM into the same `ParsedBloodPressureMeasurement` the rest of the app
/// already consumes from the standard-profile path.
///
/// EXPERIMENTAL — see OmronProtocol.swift's doc comment for the full
/// rationale. Field offsets below are ported from omblepy's `hem-7342t.py`
/// (Omron BP7450), the closest documented sibling to this app's actual
/// target device (Omron BP786N / HEM-7321T-Z), not a confirmed match for it.
enum OmronRecordParser {
    static func parse(_ recordBytes: [UInt8]) -> ParsedBloodPressureMeasurement? {
        guard recordBytes.count == OmronProtocol.recordByteSize else { return nil }

        let minute = Int(bitsToInt(recordBytes, 68, 73))
        let second = min(Int(bitsToInt(recordBytes, 74, 79)), 59) // device can report up to 63
        let month = Int(bitsToInt(recordBytes, 82, 85))
        let day = Int(bitsToInt(recordBytes, 86, 90))
        let hour = Int(bitsToInt(recordBytes, 91, 95))
        let year = Int(bitsToInt(recordBytes, 98, 103)) + 2000
        let pulse = Int(bitsToInt(recordBytes, 104, 111))
        let diastolic = Int(bitsToInt(recordBytes, 112, 119))
        let systolic = Int(bitsToInt(recordBytes, 120, 127)) + 25

        guard month >= 1, month <= 12, day >= 1, day <= 31, hour <= 23, minute <= 59 else {
            // Guards against treating an empty/garbage EEPROM slot (or a
            // record format that doesn't actually match this device) as a
            // real reading — fail this one record rather than show a
            // fabricated date.
            return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        let timestamp = Calendar(identifier: .gregorian).date(from: components)

        guard systolic > diastolic, systolic < 300, diastolic > 0 else {
            // Same defensive intent as above, applied to the vital values
            // themselves — a genuinely wrong record-format guess is far
            // more likely to produce an impossible reading than a
            // plausible-but-wrong one, but this is not a guarantee.
            return nil
        }

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
