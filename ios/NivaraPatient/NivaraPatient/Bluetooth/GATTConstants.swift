import CoreBluetooth

/// Bluetooth SIG adopted GATT service/characteristic UUIDs. These are public,
/// standard profiles (not vendor-specific) — the same ones apps like Glooko,
/// mySugr, and Tidepool use to talk to BLE-enabled meters and cuffs without
/// going through the manufacturer's own app.
///
/// References:
///  - Glucose Service: https://www.bluetooth.com/specifications/specs/glucose-service-1-0/
///  - Blood Pressure Service: https://www.bluetooth.com/specifications/specs/blood-pressure-service-1-1-1/
enum GATT {
    // MARK: Services
    static let glucoseService = CBUUID(string: "1808")
    static let bloodPressureService = CBUUID(string: "1810")
    static let deviceInformationService = CBUUID(string: "180A")
    static let batteryService = CBUUID(string: "180F")

    // MARK: Glucose Service characteristics
    static let glucoseMeasurement = CBUUID(string: "2A18")
    static let glucoseMeasurementContext = CBUUID(string: "2A34")
    static let glucoseFeature = CBUUID(string: "2A51")
    static let recordAccessControlPoint = CBUUID(string: "2A52")

    // MARK: Blood Pressure Service characteristics
    static let bloodPressureMeasurement = CBUUID(string: "2A35")
    static let intermediateCuffPressure = CBUUID(string: "2A36")
    static let bloodPressureFeature = CBUUID(string: "2A49")

    // MARK: Common
    static let batteryLevel = CBUUID(string: "2A19")
    static let manufacturerNameString = CBUUID(string: "2A29")
}
