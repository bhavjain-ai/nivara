import Foundation
import CoreBluetooth

/// Speaks Omron's proprietary BLE protocol to read every stored blood
/// pressure record off the cuff — see OmronProtocol.swift for the full
/// EXPERIMENTAL disclaimer and where these details came from.
///
/// This owns its own `CBPeripheralDelegate` conformance. BLEManager hands
/// off `peripheral.delegate` to an instance of this class once it detects
/// the Omron parent service (rather than threading this multi-step
/// handshake through BLEManager's own, much simpler standard-GATT delegate
/// methods), and retains that instance until `readBloodPressureRecords`
/// finishes.
///
/// Ported step-for-step from omblepy's Python implementation, which is
/// itself async/await-shaped — `CheckedContinuation` bridges each
/// CoreBluetooth delegate callback into a single `await` point, since
/// nothing here ever has more than one request in flight at a time.
final class OmronBLEHandler: NSObject {

    enum OmronError: LocalizedError {
        case timeout
        case unexpectedResponse(String)
        case checksumMismatch
        case notPaired
        case missingCharacteristics

        var errorDescription: String? {
            switch self {
            case .timeout:
                return "The Omron cuff stopped responding."
            case .unexpectedResponse(let detail):
                return "Unexpected response from the Omron cuff (\(detail)). This is an experimental integration — the record format may not match your exact model."
            case .checksumMismatch:
                return "Data was corrupted in transit from the Omron cuff."
            case .notPaired:
                return "This Omron cuff isn't paired yet. Hold its Bluetooth button until \"-P-\" blinks on the display, then try connecting again."
            case .missingCharacteristics:
                return "Expected Omron characteristics weren't found on this device."
            }
        }
    }

    private struct RxPacket {
        let packetType: Data
        let eepromAddress: Data
        let dataBytes: Data
    }

    private weak var peripheral: CBPeripheral?
    private var rxCharacteristics: [CBCharacteristic?] = [nil, nil, nil, nil]
    private var txCharacteristics: [CBCharacteristic?] = [nil, nil, nil, nil]
    private var unlockCharacteristic: CBCharacteristic?

    private var rxRawChannelBuffer: [Data?] = [nil, nil, nil, nil]

    private var discoverCharacteristicsContinuation: CheckedContinuation<Void, Error>?
    private var notifyStateContinuation: CheckedContinuation<Void, Error>?
    private var pendingNotifyStateCount = 0
    private var unlockContinuation: CheckedContinuation<Data, Error>?
    private var rxPacketContinuation: CheckedContinuation<RxPacket, Error>?

    /// Runs the full flow: discover characteristics, enable notifications,
    /// unlock (pairing first if needed), read every stored record for both
    /// user slots, end transmission. Throws on any failure rather than
    /// returning partial/fabricated data.
    func readBloodPressureRecords(on peripheral: CBPeripheral, parentService: CBService) async throws -> [ParsedBloodPressureMeasurement] {
        self.peripheral = peripheral
        peripheral.delegate = self

        try await discoverCharacteristics(service: parentService)
        try await enableNotifications()
        try await unlockOrPair()
        try await startTransmission()

        var allReadings: [ParsedBloodPressureMeasurement] = []
        for userStartAddress in OmronProtocol.userStartAddresses {
            let totalBytes = OmronProtocol.recordsPerUser * OmronProtocol.recordByteSize
            let raw = try await readContinuousEeprom(
                startAddress: userStartAddress,
                totalBytes: totalBytes,
                blockSize: OmronProtocol.transmissionBlockSize
            )
            allReadings.append(contentsOf: parseRecords(raw))
        }

        try await endTransmission()
        return allReadings.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
    }

    // MARK: - Characteristic discovery

    private func discoverCharacteristics(service: CBService) async throws {
        guard let peripheral else { throw OmronError.missingCharacteristics }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.discoverCharacteristicsContinuation = continuation
            peripheral.discoverCharacteristics(nil, for: service)
        }
        guard let characteristics = service.characteristics else { throw OmronError.missingCharacteristics }
        for characteristic in characteristics {
            if let rxIndex = OmronProtocol.rxChannels.firstIndex(of: characteristic.uuid) {
                rxCharacteristics[rxIndex] = characteristic
            } else if let txIndex = OmronProtocol.txChannels.firstIndex(of: characteristic.uuid) {
                txCharacteristics[txIndex] = characteristic
            } else if characteristic.uuid == OmronProtocol.unlockCharacteristic {
                unlockCharacteristic = characteristic
            }
        }
        guard rxCharacteristics.allSatisfy({ $0 != nil }),
              txCharacteristics.allSatisfy({ $0 != nil }),
              unlockCharacteristic != nil else {
            throw OmronError.missingCharacteristics
        }
    }

    private func enableNotifications() async throws {
        guard let peripheral, let unlockCharacteristic else { throw OmronError.missingCharacteristics }
        let allCharacteristics = rxCharacteristics.compactMap { $0 } + [unlockCharacteristic]
        guard allCharacteristics.count == 5 else { throw OmronError.missingCharacteristics }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.notifyStateContinuation = continuation
            self.pendingNotifyStateCount = allCharacteristics.count
            for characteristic in allCharacteristics {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    // MARK: - Unlock / pairing

    private func unlockOrPair() async throws {
        do {
            try await unlock(key: OmronProtocol.defaultPairingKey)
        } catch {
            // Most likely cause: this cuff has never been paired with this
            // app's key before. Attempt pairing — if the cuff isn't
            // physically in pairing mode, this fails cleanly with a clear
            // error after ~10s rather than doing anything harmful.
            try await pair(newKey: OmronProtocol.defaultPairingKey)
            try await unlock(key: OmronProtocol.defaultPairingKey)
        }
    }

    private func unlock(key: [UInt8]) async throws {
        let response = try await writeToUnlockCharacteristic(Data([0x01] + key))
        guard response.count >= 2, response.prefix(2) == OmronProtocol.ResponseType.unlockAccepted else {
            throw OmronError.notPaired
        }
    }

    private func pair(newKey: [UInt8]) async throws {
        var enteredProgrammingMode = false
        for attempt in 1...10 {
            let response = try await writeToUnlockCharacteristic(Data([0x02] + [UInt8](repeating: 0, count: 16)))
            if response.count >= 2, response.prefix(2) == OmronProtocol.ResponseType.enterKeyProgrammingMode {
                enteredProgrammingMode = true
                break
            }
            if attempt < 10 {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        guard enteredProgrammingMode else {
            throw OmronError.notPaired
        }

        let response = try await writeToUnlockCharacteristic(Data([0x00] + newKey))
        guard response.count >= 2, response.prefix(2) == OmronProtocol.ResponseType.keyProgrammed else {
            throw OmronError.unexpectedResponse("pairing key was rejected")
        }
    }

    /// Writes to the unlock characteristic and waits for the device's reply
    /// — which, per the protocol, arrives as a *notification* on that same
    /// characteristic, not as a write-completion callback.
    ///
    /// omblepy's own reference implementation has no timeout here at all —
    /// it just waits indefinitely, implying a wrong/rejected key still gets
    /// an explicit response in practice. Since that's an assumption this
    /// port can't verify against real hardware, a timeout is added
    /// defensively: better to fail with a clear error after a few seconds
    /// than to leave the connect flow hanging forever if that assumption
    /// turns out to be wrong for this model.
    private func writeToUnlockCharacteristic(_ payload: Data, timeoutSeconds: Double = 5.0) async throws -> Data {
        guard let peripheral, let unlockCharacteristic else { throw OmronError.missingCharacteristics }
        return try await withCheckedThrowingContinuation { continuation in
            self.unlockContinuation = continuation
            peripheral.writeValue(payload, for: unlockCharacteristic, type: .withResponse)
            // Safe without a lock: this closure and didUpdateValueFor both
            // run on the main queue (see OmronBLEHandler's own delegate
            // callbacks and BLEManager's `queue: nil` central manager), so
            // whichever fires first clears unlockContinuation and the other
            // finds it already nil.
            DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds) { [weak self] in
                guard let self, let pending = self.unlockContinuation else { return }
                self.unlockContinuation = nil
                pending.resume(throwing: OmronError.timeout)
            }
        }
    }

    // MARK: - Transmission control

    private func startTransmission() async throws {
        let response = try await sendCommand(OmronProtocol.startDataReadout)
        guard response.packetType == OmronProtocol.ResponseType.startTransmission else {
            throw OmronError.unexpectedResponse("invalid response starting transmission")
        }
    }

    private func endTransmission() async throws {
        let response = try await sendCommand(OmronProtocol.stopDataReadout)
        guard response.packetType == OmronProtocol.ResponseType.endTransmission else {
            throw OmronError.unexpectedResponse("invalid response ending transmission")
        }
        if let statusByte = response.dataBytes.first, statusByte != 0 {
            throw OmronError.unexpectedResponse("device reported error status \(statusByte)")
        }
    }

    // MARK: - EEPROM reads

    private func readContinuousEeprom(startAddress: Int, totalBytes: Int, blockSize: Int) async throws -> Data {
        var result = Data()
        var address = startAddress
        var remaining = totalBytes
        while remaining > 0 {
            let chunkSize = min(remaining, blockSize)
            let chunk = try await readBlockEeprom(address: address, size: chunkSize)
            result += chunk
            address += chunkSize
            remaining -= chunkSize
        }
        return result
    }

    private func readBlockEeprom(address: Int, size: Int) async throws -> Data {
        var command: [UInt8] = [0x08, 0x01, 0x00]
        command.append(UInt8((address >> 8) & 0xff))
        command.append(UInt8(address & 0xff))
        command.append(UInt8(size))
        command.append(0x00)
        command.append(xorChecksum(command))

        let response = try await sendCommand(command)
        let expectedAddressBytes = Data([UInt8((address >> 8) & 0xff), UInt8(address & 0xff)])
        guard response.eepromAddress == expectedAddressBytes else {
            throw OmronError.unexpectedResponse("address mismatch reading EEPROM")
        }
        guard response.packetType == OmronProtocol.ResponseType.readData else {
            throw OmronError.unexpectedResponse("invalid packet type reading EEPROM")
        }
        return response.dataBytes
    }

    private func xorChecksum(_ bytes: [UInt8]) -> UInt8 {
        bytes.reduce(0) { $0 ^ $1 }
    }

    // MARK: - Command send / multi-channel TX

    private func sendCommand(_ command: [UInt8], timeoutSeconds: Double = 2.0, maxRetries: Int = 5) async throws -> RxPacket {
        var lastError: Error = OmronError.timeout
        for attempt in 1...maxRetries {
            do {
                return try await sendCommandOnce(command, timeoutSeconds: timeoutSeconds)
            } catch {
                lastError = error
                rxRawChannelBuffer = [nil, nil, nil, nil]
                rxPacketContinuation = nil
                if attempt == maxRetries { throw lastError }
            }
        }
        throw lastError
    }

    private func sendCommandOnce(_ command: [UInt8], timeoutSeconds: Double) async throws -> RxPacket {
        guard let peripheral else { throw OmronError.missingCharacteristics }
        try writeChunked(command, on: peripheral)

        return try await withCheckedThrowingContinuation { continuation in
            self.rxPacketContinuation = continuation
            // Both this timeout and the RX-completion path (didUpdateValueFor)
            // run on the same queue as CBCentralManager (main — see
            // BLEManager's `queue: nil` init), so there is no real race here:
            // whichever fires first clears rxPacketContinuation, and the
            // second arrival finds it already nil and no-ops.
            DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds) { [weak self] in
                guard let self, let pending = self.rxPacketContinuation else { return }
                self.rxPacketContinuation = nil
                pending.resume(throwing: OmronError.timeout)
            }
        }
    }

    private func writeChunked(_ command: [UInt8], on peripheral: CBPeripheral) throws {
        let channelWidth = 16
        var remaining = command[...]
        var channelIndex = 0
        while !remaining.isEmpty {
            guard channelIndex < txCharacteristics.count, let characteristic = txCharacteristics[channelIndex] else {
                throw OmronError.missingCharacteristics
            }
            let chunk = Data(remaining.prefix(channelWidth))
            let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
            peripheral.writeValue(chunk, for: characteristic, type: writeType)
            remaining = remaining.dropFirst(channelWidth)
            channelIndex += 1
        }
    }

    // MARK: - RX reassembly

    private func handleRxChannelUpdate(channel: Int, data: Data) {
        rxRawChannelBuffer[channel] = data
        guard let firstChannelData = rxRawChannelBuffer[0], let sizeByte = firstChannelData.first else { return }

        let packetSize = Int(sizeByte)
        let requiredChannelCount = (packetSize + 15) / 16
        guard requiredChannelCount >= 1, requiredChannelCount <= 4 else {
            failPendingRxPacket(.unexpectedResponse("packet claims \(requiredChannelCount) channels"))
            return
        }
        for index in 0..<requiredChannelCount where rxRawChannelBuffer[index] == nil {
            return // still waiting on another channel for this same packet
        }

        var combined = Data()
        for index in 0..<requiredChannelCount {
            combined += rxRawChannelBuffer[index]!
        }
        combined = combined.prefix(packetSize)
        rxRawChannelBuffer = [nil, nil, nil, nil]

        guard combined.count >= 6 else {
            failPendingRxPacket(.unexpectedResponse("packet too short"))
            return
        }

        let checksum = combined.reduce(UInt8(0)) { $0 ^ $1 }
        guard checksum == 0 else {
            failPendingRxPacket(.checksumMismatch)
            return
        }

        let bytes = [UInt8](combined)
        let packetType = Data(bytes[1..<3])
        let eepromAddress = Data(bytes[3..<5])
        let expectedNumDataBytes = Int(bytes[5])
        let dataBytes: Data
        if expectedNumDataBytes > combined.count - 8 {
            dataBytes = Data(repeating: 0xff, count: expectedNumDataBytes)
        } else if packetType == OmronProtocol.ResponseType.endTransmission {
            dataBytes = Data(bytes[6..<7])
        } else {
            let end = min(6 + expectedNumDataBytes, bytes.count)
            dataBytes = Data(bytes[6..<end])
        }

        guard let pending = rxPacketContinuation else { return }
        rxPacketContinuation = nil
        pending.resume(returning: RxPacket(packetType: packetType, eepromAddress: eepromAddress, dataBytes: dataBytes))
    }

    private func failPendingRxPacket(_ error: OmronError) {
        rxRawChannelBuffer = [nil, nil, nil, nil]
        guard let pending = rxPacketContinuation else { return }
        rxPacketContinuation = nil
        pending.resume(throwing: error)
    }

    // MARK: - Record parsing

    private func parseRecords(_ raw: Data) -> [ParsedBloodPressureMeasurement] {
        let recordSize = OmronProtocol.recordByteSize
        var results: [ParsedBloodPressureMeasurement] = []
        var offset = raw.startIndex
        while offset + recordSize <= raw.endIndex {
            let recordBytes = [UInt8](raw[offset..<(offset + recordSize)])
            offset += recordSize
            if recordBytes.allSatisfy({ $0 == 0xff }) { continue } // empty ring-buffer slot
            if let reading = OmronRecordParser.parse(recordBytes) {
                results.append(reading)
            }
        }
        return results
    }
}

// MARK: - CBPeripheralDelegate

extension OmronBLEHandler: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            discoverCharacteristicsContinuation?.resume(throwing: error)
        } else {
            discoverCharacteristicsContinuation?.resume(returning: ())
        }
        discoverCharacteristicsContinuation = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            notifyStateContinuation?.resume(throwing: error)
            notifyStateContinuation = nil
            return
        }
        pendingNotifyStateCount -= 1
        if pendingNotifyStateCount <= 0 {
            notifyStateContinuation?.resume(returning: ())
            notifyStateContinuation = nil
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }

        if characteristic.uuid == OmronProtocol.unlockCharacteristic {
            guard let pending = unlockContinuation else { return }
            unlockContinuation = nil
            pending.resume(returning: data)
            return
        }
        if let rxIndex = OmronProtocol.rxChannels.firstIndex(of: characteristic.uuid) {
            handleRxChannelUpdate(channel: rxIndex, data: data)
        }
    }
}
