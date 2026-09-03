import Foundation

/// Reads a little-endian UInt16 out of `data` starting at byte `offset`
/// (offset is relative to data.startIndex, so this is safe for Data slices too).
func readUInt16LE(_ data: Data, at offset: Int) -> UInt16 {
    let i = data.startIndex + offset
    return UInt16(data[i]) | (UInt16(data[i + 1]) << 8)
}

/// Parses the Bluetooth SIG "Date Time" characteristic format (7 bytes:
/// year uint16 LE, month, day, hours, minutes, seconds — each uint8) used as
/// the Base Time / Time Stamp field in both the Glucose and Blood Pressure
/// measurement characteristics. A year of 0 means "unknown" per spec.
func readDateTime(_ data: Data, at offset: Int) -> Date? {
    guard data.count >= offset + 7 else { return nil }
    let i = data.startIndex + offset
    let year = Int(data[i]) | (Int(data[i + 1]) << 8)
    let month = Int(data[i + 2])
    let day = Int(data[i + 3])
    let hour = Int(data[i + 4])
    let minute = Int(data[i + 5])
    let second = Int(data[i + 6])
    guard year > 0, month > 0, day > 0 else { return nil }

    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    comps.hour = hour
    comps.minute = minute
    comps.second = second
    return Calendar.current.date(from: comps)
}
