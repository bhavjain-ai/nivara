import Foundation

/// Decodes the IEEE 11073-20601 16-bit SFLOAT format used throughout the
/// Bluetooth Health Device Profiles (glucose concentration, BP systolic/
/// diastolic/MAP/pulse, etc). Top 4 bits = signed exponent, bottom 12 bits =
/// signed mantissa; value = mantissa * 10^exponent. A handful of 12-bit
/// mantissa values are reserved for NaN / +Inf / -Inf / "not at this
/// resolution" and must be checked before sign-extension.
enum IEEE11073 {
    static func decodeSFLOAT(_ raw: UInt16) -> Double? {
        let rawMantissa: UInt16 = raw & 0x0FFF
        let rawExponent: UInt16 = (raw >> 12) & 0x000F

        switch rawMantissa {
        case 0x07FF: return nil // NaN
        case 0x0800: return nil // NRes (not at this resolution)
        case 0x07FE: return Double.infinity
        case 0x0802: return -Double.infinity
        case 0x0801: return nil // reserved for future use
        default: break
        }

        var mantissa = Int(rawMantissa)
        if mantissa >= 0x0800 { mantissa -= 0x1000 } // sign-extend 12-bit two's complement

        var exponent = Int(rawExponent)
        if exponent >= 0x8 { exponent -= 0x10 } // sign-extend 4-bit two's complement

        return Double(mantissa) * pow(10.0, Double(exponent))
    }
}
