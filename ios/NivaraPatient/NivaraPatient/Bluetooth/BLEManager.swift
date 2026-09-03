import Foundation
import CoreBluetooth

/// Scans for, connects to, and streams live readings from BLE peripherals that
/// implement the standard Bluetooth SIG Glucose Service (0x1808) and/or Blood
/// Pressure Service (0x1810) — e.g. an Accu-Chek Instant meter or a BLE-enabled
/// home BP cuff. This talks to the device directly over CoreBluetooth; it does
/// not go through the manufacturer's own app or HealthKit.
///
/// `CBCentralManager` is created with `queue: nil`, so every delegate callback
/// below already arrives on the main thread — safe to publish straight to
/// `@Published` properties that SwiftUI observes.
final class BLEManager: NSObject, ObservableObject {

    enum ConnectionState: Equatable {
        case poweredOff
        case unauthorized
        case idle
        case scanning
        case connecting(String)
        case connected(String)
        case failed(String)
    }

    struct DiscoveredDevice: Identifiable, Equatable {
        enum Kind { case glucose, bloodPressure, unknown }
        let id: UUID
        let name: String
        let rssi: Int
        let kind: Kind
    }

    @Published private(set) var state: ConnectionState = .idle
    @Published private(set) var discoveredDevices: [DiscoveredDevice] = []
    @Published private(set) var connectedDeviceName: String?

    /// Fires whenever a live glucose reading arrives from a connected device.
    var onGlucoseReading: ((ParsedGlucoseMeasurement) -> Void)?
    /// Fires whenever a live BP reading arrives from a connected device.
    var onBPReading: ((ParsedBloodPressureMeasurement) -> Void)?

    private var centralManager: CBCentralManager!
    private var peripherals: [UUID: CBPeripheral] = [:]
    /// Most recent Glucose Measurement Context result per peripheral, consumed
    /// by the very next Glucose Measurement notification from that peripheral.
    private var pendingMealContext: [UUID: GlucoseSampleType] = [:]

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        discoveredDevices.removeAll()
        state = .scanning
        centralManager.scanForPeripherals(
            withServices: [GATT.glucoseService, GATT.bloodPressureService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScanning() {
        centralManager.stopScan()
        if case .scanning = state { state = .idle }
    }

    func connect(to device: DiscoveredDevice) {
        guard let peripheral = peripherals[device.id] else { return }
        stopScanning()
        state = .connecting(device.name)
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        for peripheral in peripherals.values where peripheral.state == .connected {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedDeviceName = nil
        state = .idle
    }

    private func requestLastRecord(on characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        // Record Access Control Point: "Report stored records" (opcode 0x01),
        // operator "Last record" (0x06) — pulls the most recent stored reading
        // immediately on connect, in addition to whatever the meter pushes live
        // for a fresh test taken while connected.
        let command: [UInt8] = [0x01, 0x06]
        peripheral.writeValue(Data(command), for: characteristic, type: .withResponse)
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOff: state = .poweredOff
        case .unauthorized: state = .unauthorized
        case .poweredOn: state = .idle
        default: break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        peripherals[peripheral.identifier] = peripheral

        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "Unknown Device"
        let advertisedServices = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let kind: DiscoveredDevice.Kind
        if advertisedServices.contains(GATT.glucoseService) {
            kind = .glucose
        } else if advertisedServices.contains(GATT.bloodPressureService) {
            kind = .bloodPressure
        } else {
            kind = .unknown
        }

        let device = DiscoveredDevice(id: peripheral.identifier, name: name, rssi: RSSI.intValue, kind: kind)
        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[index] = device
        } else {
            discoveredDevices.append(device)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([GATT.glucoseService, GATT.bloodPressureService])
        connectedDeviceName = peripheral.name ?? "Device"
        state = .connected(peripheral.name ?? "Device")
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        state = .failed(error?.localizedDescription ?? "Couldn't connect to \(peripheral.name ?? "device").")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedDeviceName = nil
        state = .idle
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == GATT.glucoseService {
                peripheral.discoverCharacteristics(
                    [GATT.glucoseMeasurement, GATT.glucoseMeasurementContext, GATT.recordAccessControlPoint],
                    for: service
                )
            } else if service.uuid == GATT.bloodPressureService {
                peripheral.discoverCharacteristics(
                    [GATT.bloodPressureMeasurement, GATT.intermediateCuffPressure],
                    for: service
                )
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            switch characteristic.uuid {
            case GATT.glucoseMeasurement, GATT.glucoseMeasurementContext, GATT.bloodPressureMeasurement, GATT.intermediateCuffPressure:
                peripheral.setNotifyValue(true, for: characteristic)
            case GATT.recordAccessControlPoint:
                peripheral.setNotifyValue(true, for: characteristic)
                requestLastRecord(on: characteristic, peripheral: peripheral)
            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }

        switch characteristic.uuid {
        case GATT.glucoseMeasurementContext:
            if GlucoseContextParser.hasMealField(data) {
                pendingMealContext[peripheral.identifier] = .postMeal
            }

        case GATT.glucoseMeasurement:
            guard let parsed = GlucoseMeasurementParser.parse(data) else { return }
            var reading = parsed
            if let inferredType = pendingMealContext.removeValue(forKey: peripheral.identifier) {
                reading = ParsedGlucoseMeasurement(
                    sequenceNumber: parsed.sequenceNumber,
                    timestamp: parsed.timestamp,
                    glucoseMgDl: parsed.glucoseMgDl,
                    sampleType: inferredType
                )
            }
            onGlucoseReading?(reading)

        case GATT.bloodPressureMeasurement:
            guard let parsed = BloodPressureMeasurementParser.parse(data) else { return }
            onBPReading?(parsed)

        default:
            break
        }
    }
}
