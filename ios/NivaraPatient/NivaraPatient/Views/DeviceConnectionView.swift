import SwiftUI

struct DeviceConnectionView: View {
    @EnvironmentObject private var viewModel: PatientViewModel
    @EnvironmentObject private var onboarding: OnboardingStore

    private var ble: BLEManager { viewModel.bleManager }

    var body: some View {
        List {
            Section {
                statusRow
            }

            switch ble.state {
            case .poweredOff:
                Section {
                    Label(onboarding.t("device_bluetooth_off"), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
            case .unauthorized:
                Section {
                    Label(onboarding.t("device_bluetooth_unauthorized"), systemImage: "lock")
                        .foregroundStyle(.secondary)
                }
            default:
                Section {
                    if ble.discoveredDevices.isEmpty {
                        Text(ble.state == .scanning ? onboarding.t("device_searching_nearby") : onboarding.t("device_no_devices_found"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(ble.discoveredDevices) { device in
                        deviceRow(device)
                    }
                } header: {
                    Text(onboarding.t("device_nearby_devices"))
                } footer: {
                    Text(onboarding.t("device_footer_explanation"))
                }

                Section {
                    Button {
                        ble.state == .scanning ? ble.stopScanning() : ble.startScanning()
                    } label: {
                        HStack {
                            Spacer()
                            Text(ble.state == .scanning ? onboarding.t("device_stop_scanning") : onboarding.t("device_scan_for_devices"))
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
                            Text(onboarding.t("device_disconnect"))
                            Spacer()
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(NivaraColor.cream)
        .navigationTitle(onboarding.t("device_nav_title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var statusRow: some View {
        switch ble.state {
        case .idle:
            Label(onboarding.t("device_ready_to_scan"), systemImage: "antenna.radiowaves.left.and.right")
        case .scanning:
            HStack {
                ProgressView().controlSize(.small)
                Text(onboarding.t("device_scanning"))
            }
        case .connecting(let name):
            HStack {
                ProgressView().controlSize(.small)
                Text(onboarding.t("device_connecting_to", name))
            }
        case .readingOmronHistory(let message):
            HStack(alignment: .top) {
                ProgressView().controlSize(.small)
                Text(message)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .connected(let name):
            Label(onboarding.t("device_connected_to", name), systemImage: "checkmark.circle.fill")
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
                Text(onboarding.t("device_rssi", device.rssi))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func iconName(for kind: BLEManager.DiscoveredDevice.Kind) -> String {
        switch kind {
        case .glucose: return "drop.fill"
        case .bloodPressure, .omronBloodPressure: return "heart.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    private func kindLabel(_ kind: BLEManager.DiscoveredDevice.Kind) -> String {
        switch kind {
        case .glucose: return onboarding.t("device_kind_glucose")
        case .bloodPressure: return onboarding.t("device_kind_bp")
        case .omronBloodPressure: return onboarding.t("device_kind_bp_omron")
        case .unknown: return onboarding.t("device_kind_unknown")
        }
    }
}

#Preview {
    NavigationStack {
        DeviceConnectionView()
            .environmentObject(PatientViewModel())
            .environmentObject(OnboardingStore())
    }
}
