import CoreBluetooth

/// Omron's proprietary BLE protocol — NOT part of the Bluetooth SIG standard
/// this app otherwise uses (see GATTConstants.swift). Omron BP cuffs don't
/// implement the standard Blood Pressure Service (0x1810) at all, so none of
/// GlucoseMeasurementParser/BloodPressureMeasurementParser/IEEE11073 applies
/// here — this is a from-scratch, separate protocol.
///
/// EXPERIMENTAL. Ported from the open-source, reverse-engineered omblepy
/// project (https://github.com/userx14/omblepy, MIT-licensed at the time of
/// writing), which documents that Omron doesn't publish this protocol
/// anywhere — every detail below was independently reverse-engineered by
/// that project's contributors, not sourced from Omron.
///
/// omblepy's own documentation states the low-level communication protocol
/// below (UUIDs, command framing, pairing handshake) is the same across
/// every Omron BLE device they've tested, and that's held up against real
/// BP786N/HEM-7321T-Z hardware — confirmed independently by a real BLE
/// sniffer capture of the official OMRON connect app using this exact
/// framing. The *record format* (memory addresses, byte layout of the
/// latest reading) is device-specific and was NOT sourced from omblepy —
/// see the record-format section below for where it actually came from.
enum OmronProtocol {
    // MARK: - BLE UUIDs (universal across Omron BLE devices, per omblepy)

    static let parentService = CBUUID(string: "ecbe3980-c9a2-11e1-b1bd-0002a5d5c51b")

    /// Device → app, 4 parallel channels — reassembled in sequence by
    /// OmronBLEHandler since a single response can span more than one
    /// channel's 16-byte MTU.
    static let rxChannels: [CBUUID] = [
        CBUUID(string: "49123040-aee8-11e1-a74d-0002a5d5c51b"),
        CBUUID(string: "4d0bf320-aee8-11e1-a0d9-0002a5d5c51b"),
        CBUUID(string: "5128ce60-aee8-11e1-b84b-0002a5d5c51b"),
        CBUUID(string: "560f1420-aee8-11e1-8184-0002a5d5c51b"),
    ]

    /// App → device, 4 parallel channels — a command is split into 16-byte
    /// chunks written across these in sequence.
    static let txChannels: [CBUUID] = [
        CBUUID(string: "db5b55e0-aee7-11e1-965e-0002a5d5c51b"),
        CBUUID(string: "e0b8a060-aee7-11e1-92f4-0002a5d5c51b"),
        CBUUID(string: "0ae12b00-aee8-11e1-a192-0002a5d5c51b"),
        CBUUID(string: "10e1ba60-aee8-11e1-89e5-0002a5d5c51b"),
    ]

    static let unlockCharacteristic = CBUUID(string: "b305b680-aee7-11e1-a730-0002a5d5c51b")

    // MARK: - Pairing key

    /// The same arbitrary 16-byte key omblepy uses by default — not a
    /// secret specific to any device, just a shared convention so a
    /// freshly-paired cuff and this app agree on a key. Equivalent to hex
    /// string "deadbeaf12341234deadbeaf12341234".
    static let defaultPairingKey: [UInt8] = [
        0xde, 0xad, 0xbe, 0xaf, 0x12, 0x34, 0x12, 0x34,
        0xde, 0xad, 0xbe, 0xaf, 0x12, 0x34, 0x12, 0x34,
    ]

    // MARK: - Commands (universal)

    /// "0800000000100018" — start of transmission / read device id.
    static let startDataReadout: [UInt8] = [0x08, 0x00, 0x00, 0x00, 0x00, 0x10, 0x00, 0x18]
    /// "080f000000000007" — end of transmission.
    static let stopDataReadout: [UInt8] = [0x08, 0x0f, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07]

    /// Response packet type headers (bytes 1-2 of a reassembled response).
    enum ResponseType {
        static let startTransmission = Data([0x80, 0x00])
        static let readData = Data([0x81, 0x00])
        static let endTransmission = Data([0x8f, 0x00])
        static let enterKeyProgrammingMode = Data([0x82, 0x00])
        static let keyProgrammed = Data([0x80, 0x00])
        static let unlockAccepted = Data([0x81, 0x00])
    }

    // MARK: - Record format: proven via a real BLE sniffer capture (PacketLogger) of the official OMRON connect app
    //
    // Every earlier version of this section was blind reverse-engineering
    // against a continuous EEPROM ring-buffer dump, and never reliably
    // matched more than a couple of fields at once. This was superseded
    // entirely once a real HCI capture of the official app talking to this
    // exact cuff (BP786N/HEM-7321T-Z) was obtained: the official app does
    // NOT scan a ring buffer for the newest record — it reads two small
    // fixed EEPROM locations that always hold the *latest* reading.
    //
    // Captured request/response pairs, decoded byte-for-byte against a
    // known-ground-truth reading (111/71 mmHg, pulse 67bpm, 18:48, 9/21):
    //   - Read 38 bytes @ 0x0260 ("metadata"): month/year/hour/day/minute/
    //     systolic all live in here (see OmronRecordParser.parseLatestReading
    //     for exact offsets) — all six matched the known reading exactly.
    //   - Read 14 bytes @ 0x0c5a ("values"): diastolic and pulse live here —
    //     both matched exactly.
    // 8 independently-matching fields across two unrelated reads is well
    // beyond coincidence, so this replaces the old ring-buffer-scan
    // approach outright. `transmissionBlockSize` is unrelated and
    // unaffected: it's the wire-protocol EEPROM-read chunk size, confirmed
    // correct since every 16-byte read has succeeded against this device
    // (readBlockEeprom's multi-channel reassembly is generic to any
    // requested size, including these larger 38/14-byte reads).

    static let latestReadingMetadataAddress = 0x0260
    static let latestReadingMetadataSize = 38
    static let latestReadingValuesAddress = 0x0c5a
    static let latestReadingValuesSize = 14
    static let transmissionBlockSize = 0x10 // 16 bytes — how large a single EEPROM read request can be
}
