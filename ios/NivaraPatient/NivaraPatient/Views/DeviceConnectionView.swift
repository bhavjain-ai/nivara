import SwiftUI

struct DeviceConnectionView: View {
    @EnvironmentObject private var viewModel: PatientViewModel

    private var ble: BLEManager { viewModel.bleManager }

    var body: some View {
        List {
            Section {
                statusRow
            }

            switch ble.state {
            case .poweredOff:
                Section {
                    Label("Turn on Bluetooth in Settings to connect a device.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
            case .unauthorized:
                Section {
                    Label("Nivara needs Bluetooth permission — enable it in Settings > Nivara.", systemImage: "lock")
                        .foregroundStyle(.secondary)
                }
            default:
                Section {
                    if ble.discoveredDevices.isEmpty {
                        Text(ble.state == .scanning ? "Searching nearby…" : "No devices found yet. Make sure your meter or cuff is powered on and nearby, then tap Scan.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(ble.discoveredDevices) { device in
                        deviceRow(device)
                    }
                } header: {
                    Text("Nearby Devices")
                } footer: {
                    Text("Works with any BLE device that supports the standard Bluetooth Glucose Profile or Blood Pressure Profile — including Accu-Chek Instant meters and most BLE home BP cuffs. No manufacturer app required.")
                }

                Section {
                    Button {
                        ble.state == .scanning ? ble.stopScanning() : ble.startScanning()
                    } label: {
                        HStack {
                            Spacer()
                            Text(ble.state == .scanning ? "Stop Scanning" : "Scan for Devices")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }

            if ble.connectedDeviceName != nil {
                Section {
                    Button(role: .destructive) {
                        ble.disconnect()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Disconnect")
                            Spacer()
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(NivaraColor.cream)
        .navigationTitle("Devices")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var statusRow: some View {
        switch ble.state {
        case .idle:
            Label("Ready to scan", systemImage: "antenna.radiowaves.left.and.right")
        case .scanning:
            HStack {
                ProgressView().controlSize(.small)
                Text("Scanning…")
            }
        case .connecting(let name):
            HStack {
                ProgressView().controlSize(.small)
                Text("Connecting to \(name)…")
            }
        case .connected(let name):
            Label("Connected to \(name)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(NivaraColor.normal)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(NivaraColor.critical)
        case .poweredOff, .unauthorized:
            EmptyView()
        }
    }

    private func deviceRow(_ device: BLEManager.DiscoveredDevice) -> some View {
        Button {
            ble.connect(to: device)
        } label: {
            HStack {
                Image(systemName: iconName(for: device.kind))
                    .foregroundStyle(NivaraColor.forestGreen)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .foregroundStyle(.primary)
                    Text(kindLabel(device.kind))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(device.rssi) dBm")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func iconName(for kind: BLEManager.DiscoveredDevice.Kind) -> String {
        switch kind {
        case .glucose: return "drop.fill"
        case .bloodPressure: return "heart.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    private func kindLabel(_ kind: BLEManager.DiscoveredDevice.Kind) -> String {
        switch kind {
        case .glucose: return "Glucose meter"
        case .bloodPressure: return "Blood pressure cuff"
        case .unknown: return "Unknown device type"
        }
    }
}

#Preview {
    NavigationStack {
        DeviceConnectionView().environmentObject(PatientViewModel())
    }
}
