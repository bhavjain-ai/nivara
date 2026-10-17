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
        /// Omron only: BLE-connected, but still working through the
        /// proprietary handshake/read in the background — see
        /// OmronBLEHandler. The associated string is a human-readable
        /// progress step, so a stuck connection is visibly stuck
        /// *somewhere specific* rather than indistinguishable from one
        /// that's silently working.
        case readingOmronHistory(String)
        case connected(String)
        case failed(String)
    }

    struct DiscoveredDevice: Identifiable, Equatable {
        enum Kind { case glucose, bloodPressure, omronBloodPressure, unknown }
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
    /// Retains the Omron protocol handler for a peripheral's connection
    /// lifetime — see OmronBLEHandler.swift. Keyed by peripheral identifier
    /// so multiple sequential connections don't collide.
    private var omronHandlers: [UUID: OmronBLEHandler] = [:]
    /// The peripheral a connect() call is currently in flight for, so a
    /// stale timeout (see connect(to:)) can tell "this connection attempt
    /// already resolved one way or another" from "still waiting."
    private var connectingPeripheralID: UUID?

    /// Persists the identifier of the last device the patient successfully
    /// connected to, so a later app open can reconnect directly (see
    /// `autoReconnectIfKnownDevice`) instead of requiring a manual "Scan for
    /// Devices" tap every single time — the friction uncle specifically
    /// flagged. Deliberately never cleared on disconnect: a dropped
    /// connection (read finished, OS cleanup, out of range) isn't the
    /// patient switching devices, so the next auto-reconnect should still
    /// target the same one.
    private static let lastKnownPeripheralDefaultsKey = "ble.lastKnownPeripheralID"

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        discoveredDevices.removeAll()
        state = .scanning
        // Omron's parent service is included defensively — omblepy (the
        // reference implementation this app's Omron support is ported from)
        // scans unfiltered and only confirms the service post-connection,
        // which suggests Omron cuffs may not actually advertise it. If so,
        // an Omron cuff simply won't appear in discoveredDevices below;
        // that's a known possible gap, not a crash risk (this UUID is
        // otherwise inert in the filter — standard-profile discovery is
        // unaffected either way).
        centralManager.scanForPeripherals(
            withServices: [GATT.glucoseService, GATT.bloodPressureService, OmronProtocol.parentService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScanning() {
        centralManager.stopScan()
        if case .scanning = state { state = .idle }
    }

    /// Reconnects to the last device the patient successfully connected to,
    /// without requiring a manual "Scan for Devices" tap — called when Home
    /// appears (and again from `centralManagerDidUpdateState` in case
    /// Bluetooth wasn't ready yet the first time this was called, e.g. right
    /// at cold launch). Uses `retrievePeripherals(withIdentifiers:)` rather
    /// than a fresh scan — CoreBluetooth already knows this peripheral from
    /// a prior connection, so this can connect directly instead of waiting
    /// on advertisement packets.
    ///
    /// Silently no-ops rather than erroring if there's no known device yet
    /// (first-time patient), Bluetooth isn't ready, a connection is already
    /// in flight/established, or the known device isn't currently in range
    /// (retrievePeripherals simply returns empty) — this is a best-effort
    /// background convenience the patient didn't explicitly ask for on this
    /// particular screen visit, not a user-initiated action whose failure
    /// deserves an error banner. The manual Devices screen remains the
    /// explicit, visible way to pair a new device or retry a real failure.
    func autoReconnectIfKnownDevice() {
        guard centralManager.state == .poweredOn else { return }
        guard case .idle = state else { return }
        guard let idString = UserDefaults.standard.string(forKey: Self.lastKnownPeripheralDefaultsKey),
              let id = UUID(uuidString: idString) else { return }

        guard let peripheral = centralManager.retrievePeripherals(withIdentifiers: [id]).first else { return }
        peripherals[peripheral.identifier] = peripheral
        let device = DiscoveredDevice(id: peripheral.identifier, name: peripheral.name ?? Translations.string("ble_device_fallback_name"), rssi: 0, kind: .unknown)
        connect(to: device)
    }

    func connect(to device: DiscoveredDevice) {
        guard let peripheral = peripherals[device.id] else { return }
        stopScanning()
        state = .connecting(device.name)
        connectingPeripheralID = device.id
        centralManager.connect(peripheral, options: nil)

        // CoreBluetooth's connect() has no built-in timeout — if the
        // peripheral never actually accepts the connection (as opposed to
        // explicitly rejecting it, which would fire didFailToConnect),
        // neither didConnect nor didFailToConnect fires at all, and the UI
        // would otherwise sit on "Connecting…" forever with no way to
        // recover short of relaunching the app.
        let timeoutDeviceID = device.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self, self.connectingPeripheralID == timeoutDeviceID else { return }
            self.connectingPeripheralID = nil
            self.centralManager.cancelPeripheralConnection(peripheral)
            self.state = .failed(Translations.string("ble_error_couldnt_connect_timeout", device.name))
        }
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

    /// Omron cuffs don't implement the standard GATT services above at all
    /// — see OmronBLEHandler.swift. Hands `peripheral.delegate` off to a
    /// dedicated handler instance (retained in `omronHandlers` for the
    /// duration of the read) rather than threading this multi-step,
    /// proprietary handshake through this class's own, much simpler
    /// standard-GATT delegate methods.
    private func handleOmronConnection(peripheral: CBPeripheral, service: CBService) {
        let handler = OmronBLEHandler()
        omronHandlers[peripheral.identifier] = handler
        let deviceName = peripheral.name ?? Translations.string("ble_omron_fallback_name")
        handler.onProgress = { [weak self] message in
            // OmronBLEHandler isn't @MainActor-isolated, so code resuming
            // after an `await` inside it (unlike BLEManager's own
            // `Task { @MainActor in }` below) isn't guaranteed to land back
            // on the main thread — dispatch explicitly rather than mutate
            // `state` (@Published) from a possibly-background thread.
            DispatchQueue.main.async {
                self?.state = .readingOmronHistory("\(deviceName): \(message)")
            }
        }
        state = .readingOmronHistory("\(deviceName): \(Translations.string("omron_progress_connecting"))")
        Task { @MainActor in
            do {
                let readings = try await handler.readBloodPressureRecords(on: peripheral, parentService: service)
                for reading in readings {
                    self.onBPReading?(reading)
                }
                if readings.isEmpty {
                    self.state = .failed(Translations.string("ble_error_no_recent_reading"))
                } else {
                    self.state = .connected(deviceName)
                }
            } catch {
                self.state = .failed(error.localizedDescription)
            }
            self.omronHandlers[peripheral.identifier] = nil
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOff: state = .poweredOff
        case .unauthorized: state = .unauthorized
        case .poweredOn:
            state = .idle
            // Covers the cold-launch race where Home's onAppear (and its
            // own autoReconnectIfKnownDevice() call) fires before
            // CoreBluetooth has finished reporting its real state.
            autoReconnectIfKnownDevice()
        default: break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        peripherals[peripheral.identifier] = peripheral

        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? Translations.string("ble_device_unknown_name")
        let advertisedServices = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let kind: DiscoveredDevice.Kind
        if advertisedServices.contains(GATT.glucoseService) {
            kind = .glucose
        } else if advertisedServices.contains(GATT.bloodPressureService) {
            kind = .bloodPressure
        } else if advertisedServices.contains(OmronProtocol.parentService) {
            kind = .omronBloodPressure
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
        connectingPeripheralID = nil
        peripheral.delegate = self
        peripheral.discoverServices([GATT.glucoseService, GATT.bloodPressureService, OmronProtocol.parentService])
        let resolvedName = peripheral.name ?? Translations.string("ble_device_fallback_name")
        connectedDeviceName = resolvedName
        state = .connected(resolvedName)
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: Self.lastKnownPeripheralDefaultsKey)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectingPeripheralID = nil
        // error?.localizedDescription is a CoreBluetooth/system-generated
        // message (when present) and is shown as-is, untranslated — iOS
        // itself doesn't localize it per the app's selected language.
        state = .failed(error?.localizedDescription ?? Translations.string("ble_error_couldnt_connect_generic", peripheral.name ?? Translations.string("ble_device_fallback_name")))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedDeviceName = nil
        // Real hardware showed the BLE link itself can drop partway
        // through a long Omron history read — if a handler is still
        // working on this peripheral, let it fail whatever it's
        // awaiting right away (see OmronBLEHandler.peripheralDidDisconnect)
        // and finish through its own success/failure path, rather than
        // stomping its in-progress `.readingOmronHistory` state here.
        if let handler = omronHandlers[peripheral.identifier] {
            handler.peripheralDidDisconnect()
            return
        }
        state = .idle
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        if let omronService = services.first(where: { $0.uuid == OmronProtocol.parentService }) {
            handleOmronConnection(peripheral: peripheral, service: omronService)
            return
        }

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
