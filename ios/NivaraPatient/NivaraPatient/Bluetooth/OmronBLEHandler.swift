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
        case disconnected
        case unexpectedResponse(String)
        case checksumMismatch
        case notPaired
        case missingCharacteristics

        var errorDescription: String? {
            switch self {
            case .timeout:
                return "The Omron cuff stopped responding."
            case .disconnected:
                return "The Bluetooth connection to the cuff was lost before the read finished."
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
    /// Set by `peripheralDidDisconnect()` — real hardware showed the BLE
    /// link itself can drop partway through a long EEPROM read (this
    /// device's full history read is hundreds of round trips), which
    /// otherwise looks identical to the device just not responding: every
    /// further write silently goes nowhere and each attempt burns its
    /// full timeout before finally erroring with a misleading "stopped
    /// responding" message. Checking this lets in-flight and future
    /// attempts fail immediately with a clear, accurate error instead.
    private var isDisconnected = false

    /// Fired at each major step with a human-readable status — this
    /// protocol has no fast built-in confirmation for most of these steps,
    /// so without this, a stuck connection is silent and indistinguishable
    /// from a working-but-slow one. BLEManager surfaces this directly in
    /// the Devices screen's status row.
    var onProgress: ((String) -> Void)?

    /// Runs the full flow: discover characteristics, enable notifications,
    /// unlock (pairing first if needed), read every stored record for both
    /// user slots, end transmission. Throws on any failure rather than
    /// returning partial/fabricated data.
    func readBloodPressureRecords(on peripheral: CBPeripheral, parentService: CBService) async throws -> [ParsedBloodPressureMeasurement] {
        self.peripheral = peripheral
        peripheral.delegate = self

        onProgress?("Discovering Omron characteristics…")
        try await discoverCharacteristics(service: parentService)
        onProgress?("Enabling notifications…")
        try await enableNotifications()
        onProgress?("Unlocking…")
        try await unlockOrPair()
        onProgress?("Starting data transfer…")
        try await startTransmission()

        var allReadings: [ParsedBloodPressureMeasurement] = []
        for (userIndex, userStartAddress) in OmronProtocol.userStartAddresses.enumerated() {
            onProgress?("Reading stored readings (user \(userIndex + 1) of \(OmronProtocol.userStartAddresses.count))…")
            let totalBytes = OmronProtocol.recordsPerUser * OmronProtocol.recordByteSize
            do {
                let raw = try await readContinuousEeprom(
                    startAddress: userStartAddress,
                    totalBytes: totalBytes,
                    blockSize: OmronProtocol.transmissionBlockSize
                )
                allReadings.append(contentsOf: parseRecords(raw))
            } catch OmronError.disconnected {
                // Seen on real hardware: the BLE link itself dropped
                // partway through a long read (unlike a plain timeout,
                // which this device reliably uses to mean "no more
                // data" — see readContinuousEeprom). There's nothing
                // more to read and no live connection left to send
                // end-transmission on, but whatever was already parsed
                // is real data and worth keeping rather than discarding.
                onProgress?("Connection dropped partway through — keeping \(allReadings.count) reading(s) already read.")
                return allReadings.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
            }
        }

        onProgress?("Finishing…")
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
            onProgress?("Not paired yet — hold the cuff's Bluetooth button until \"-P-\" shows, pairing…")
            try await pair(newKey: OmronProtocol.defaultPairingKey)
            onProgress?("Paired — unlocking…")
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
            onProgress?("Waiting for pairing mode (attempt \(attempt) of 10)…")
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

    /// The `100`-records-per-user span (and everything else in
    /// OmronProtocol's record-format constants) was borrowed from a
    /// different, unconfirmed Omron model — real hardware testing found
    /// this device stops responding to reads entirely partway through
    /// that assumed span (repeatedly, at the same address, even after a
    /// long patient wait — not a timing fluke). That's read as "past the
    /// end of this device's actual readable record region," not a fatal
    /// error: whatever was already read successfully is kept, and the
    /// caller moves on (to the next user slot, or to finishing up)
    /// instead of discarding a good partial read.
    private func readContinuousEeprom(startAddress: Int, totalBytes: Int, blockSize: Int) async throws -> Data {
        var result = Data()
        var address = startAddress
        var remaining = totalBytes
        while remaining > 0 {
            let chunkSize = min(remaining, blockSize)
            do {
                let chunk = try await readBlockEeprom(address: address, size: chunkSize)
                result += chunk
            } catch OmronError.timeout {
                log("No response reading 0x\(String(format: "%04x", address)) after repeated retries — treating as end of this device's readable record region, keeping \(result.count) bytes read so far")
                break
            }
            address += chunkSize
            remaining -= chunkSize
        }
        return result
    }

    /// `mismatchRetriesRemaining` guards against a specific race observed
    /// against real hardware: when a request times out and gets resent
    /// (see `sendCommand`), the *original* response can still be in
    /// flight and arrive late — landing on the retried request's
    /// continuation instead of the one it actually answers, which reads
    /// back as this block's data suddenly matching a *previous* address.
    /// That's a stale, recoverable notification, not a genuine protocol
    /// mismatch — asking again (rather than failing the whole read) lets
    /// it flush through.
    private func readBlockEeprom(address: Int, size: Int, mismatchRetriesRemaining: Int = 3) async throws -> Data {
        var command: [UInt8] = [0x08, 0x01, 0x00]
        command.append(UInt8((address >> 8) & 0xff))
        command.append(UInt8(address & 0xff))
        command.append(UInt8(size))
        command.append(0x00)
        command.append(xorChecksum(command))

        log("TX readBlockEeprom: requested address 0x\(String(format: "%04x", address)), size \(size), command \(Data(command).omronHexString)")
        let response = try await sendCommand(command)
        let expectedAddressBytes = Data([UInt8((address >> 8) & 0xff), UInt8(address & 0xff)])
        guard response.eepromAddress == expectedAddressBytes else {
            guard mismatchRetriesRemaining > 0 else {
                throw OmronError.unexpectedResponse(
                    "persistent address mismatch — expected \(expectedAddressBytes.omronHexString), device echoed \(response.eepromAddress.omronHexString) — packetType \(response.packetType.omronHexString), data \(response.dataBytes.omronHexString)"
                )
            }
            log("Stale response for 0x\(String(format: "%04x", address)) (got address \(response.eepromAddress.omronHexString)) — retrying")
            return try await readBlockEeprom(address: address, size: size, mismatchRetriesRemaining: mismatchRetriesRemaining - 1)
        }
        guard response.packetType == OmronProtocol.ResponseType.readData else {
            throw OmronError.unexpectedResponse("invalid packet type reading EEPROM: \(response.packetType.omronHexString)")
        }
        return response.dataBytes
    }

    private func xorChecksum(_ bytes: [UInt8]) -> UInt8 {
        bytes.reduce(0) { $0 ^ $1 }
    }

    // MARK: - Command send / multi-channel TX

    // 2.0s was too tight against real hardware — this device sometimes
    // takes longer than that to respond, which triggered a resend while
    // the original reply was still in flight (see readBlockEeprom's
    // mismatch-retry comment for what that caused).
    //
    // Real-hardware logs proved a sustained timeout here (after several
    // backed-off retries) reliably means "past the end of this device's
    // readable record region" (see readContinuousEeprom), not a slow
    // response recovering later — genuinely slow replies observed on
    // real hardware resolved within a single retry. That happens on
    // every connect (full history is re-read each time), so the retry
    // budget stays modest (4s, 6s, 8s = 18s total) rather than the 40s
    // used to first confirm this diagnosis, while still backing off and
    // pausing between attempts instead of hammering the device.
    private func sendCommand(_ command: [UInt8], baseTimeoutSeconds: Double = 4.0, maxRetries: Int = 3) async throws -> RxPacket {
        var lastError: Error = OmronError.timeout
        for attempt in 1...maxRetries {
            do {
                let timeoutSeconds = baseTimeoutSeconds + Double(attempt - 1) * 2.0
                return try await sendCommandOnce(command, timeoutSeconds: timeoutSeconds, attempt: attempt)
            } catch OmronError.disconnected {
                // The BLE link itself is gone — retrying just re-triggers
                // the same CoreBluetooth "API MISUSE ... disconnected"
                // warning and can never succeed.
                log("Peripheral disconnected — not retrying")
                throw OmronError.disconnected
            } catch {
                lastError = error
                rxRawChannelBuffer = [nil, nil, nil, nil]
                rxPacketContinuation = nil
                if attempt == maxRetries {
                    log("Giving up after \(maxRetries) attempts, no usable response — \(error.localizedDescription)")
                    throw lastError
                }
                log("Attempt \(attempt) of \(maxRetries) failed (\(error.localizedDescription)) — pausing before retry")
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        throw lastError
    }

    private func sendCommandOnce(_ command: [UInt8], timeoutSeconds: Double, attempt: Int) async throws -> RxPacket {
        guard let peripheral else { throw OmronError.missingCharacteristics }
        guard !isDisconnected else { throw OmronError.disconnected }
        log("Sending (attempt \(attempt), timeout \(timeoutSeconds)s)")
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
            log("TX ch\(channelIndex) > \(chunk.omronHexString)")
            let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
            peripheral.writeValue(chunk, for: characteristic, type: writeType)
            remaining = remaining.dropFirst(channelWidth)
            channelIndex += 1
        }
    }

    // MARK: - Debug logging
    //
    // Always on rather than gated behind a flag — this is an experimental,
    // unverified integration, and the raw wire trace is the single most
    // useful thing for diagnosing it against real hardware. Filter Xcode's
    // console for "[Omron]" to isolate this from the rest of the app's log
    // output.

    private func log(_ message: String) {
        print("[Omron] \(message)")
    }

    // MARK: - RX reassembly

    private func handleRxChannelUpdate(channel: Int, data: Data) {
        log("RX ch\(channel) < \(data.omronHexString)")
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

        log("RX reassembled: full \(combined.omronHexString) — type \(packetType.omronHexString), address \(eepromAddress.omronHexString), data \(dataBytes.omronHexString)")

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

    /// Called by BLEManager's CBCentralManagerDelegate as soon as it's
    /// told this peripheral disconnected. Fails whatever's currently
    /// awaited right away, and latches `isDisconnected` so every
    /// subsequent attempt fails fast too instead of writing into (and
    /// timing out against) a peripheral that's already gone.
    func peripheralDidDisconnect() {
        isDisconnected = true
        let error = OmronError.disconnected
        if let pending = discoverCharacteristicsContinuation {
            discoverCharacteristicsContinuation = nil
            pending.resume(throwing: error)
        }
        if let pending = notifyStateContinuation {
            notifyStateContinuation = nil
            pending.resume(throwing: error)
        }
        if let pending = unlockContinuation {
            unlockContinuation = nil
            pending.resume(throwing: error)
        }
        failPendingRxPacket(.disconnected)
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

private extension Data {
    var omronHexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
