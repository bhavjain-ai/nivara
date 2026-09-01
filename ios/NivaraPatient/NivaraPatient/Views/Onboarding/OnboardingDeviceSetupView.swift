import SwiftUI
import UIKit

/// A 5-step guided walkthrough that pairs the patient's real glucometer over
/// the same CoreBluetooth path the rest of the app uses (BLEManager) — this
/// is not a simulated/scripted setup, so whatever connects here is already
/// connected once the patient reaches the main app.
struct OnboardingDeviceSetupView: View {
    @EnvironmentObject private var viewModel: PatientViewModel
    let onBack: () -> Void
    let onFinished: () -> Void

    @State private var deviceStep = 1
    private let totalDeviceSteps = 5

    private var ble: BLEManager { viewModel.bleManager }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                stepContent
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
            footer
                .padding()
        }
        .background(NivaraColor.cream)
        .onChange(of: ble.connectedDeviceName) { newValue in
            if newValue != nil && deviceStep == 3 {
                deviceStep = 4
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NivaraColor.forestGreen)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("Device Setup · \(deviceStep) of \(totalDeviceSteps)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NivaraColor.textSecondary)
            }
            ProgressView(value: Double(deviceStep), total: Double(totalDeviceSteps))
                .tint(NivaraColor.forestGreen)
            Text(title(for: deviceStep))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(NivaraColor.textPrimary)
        }
        .padding()
        .padding(.top, 8)
    }

    private func back() {
        if deviceStep > 1 {
            deviceStep -= 1
        } else {
            onBack()
        }
    }

    private func title(for step: Int) -> String {
        switch step {
        case 1: return "Gather your supplies"
        case 2: return "Turn on Bluetooth"
        case 3: return "Connect your glucometer"
        case 4: return "Confirm the connection"
        default: return "Take your first measurement"
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch deviceStep {
        case 1: suppliesStep
        case 2: bluetoothStep
        case 3: connectStep
        case 4: confirmStep
        default: measurementStep
        }
    }

    // MARK: - Step 1

    private var suppliesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Before you start, get these ready:")
                .font(.subheadline)
                .foregroundStyle(NivaraColor.textSecondary)
            supplyRow(icon: "drop.fill", text: "Your Accu-Chek Instant glucometer")
            supplyRow(icon: "rectangle.on.rectangle", text: "A test strip")
            supplyRow(icon: "bandage.fill", text: "A lancet device")
        }
    }

    private func supplyRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(NivaraColor.sageGreen)
                Image(systemName: icon).foregroundStyle(NivaraColor.forestGreen)
            }
            .frame(width: 40, height: 40)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(NivaraColor.textPrimary)
            Spacer()
        }
        .padding(12)
        .background(NivaraColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Step 2

    private var bluetoothIsOn: Bool {
        switch ble.state {
        case .poweredOff, .unauthorized: return false
        default: return true
        }
    }

    private var bluetoothStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Open Settings, tap Bluetooth, and make sure the switch is turned on.")
                .font(.subheadline)
                .foregroundStyle(NivaraColor.textSecondary)

            HStack(spacing: 10) {
                Image(systemName: bluetoothIsOn ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(bluetoothIsOn ? NivaraColor.forestGreen : NivaraColor.warning)
                Text(bluetoothIsOn ? "Bluetooth is on" : "Bluetooth looks like it's off")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NivaraColor.textPrimary)
            }
            .padding(14)
            .background(NivaraColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if !bluetoothIsOn {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NivaraColor.forestGreen)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Step 3

    private var connectStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Turn on your Accu-Chek Instant meter.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NivaraColor.textPrimary)
                Text("Press and hold the meter's Bluetooth button until the Bluetooth symbol blinks — that means it's ready to pair. Then tap Scan below and select your meter when it appears.")
                    .font(.subheadline)
                    .foregroundStyle(NivaraColor.textSecondary)
            }
            .padding(14)
            .background(NivaraColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                ble.state == .scanning ? ble.stopScanning() : ble.startScanning()
            } label: {
                Text(ble.state == .scanning ? "Stop Scanning" : "Scan for My Meter")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(NivaraColor.forestGreen)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            if ble.discoveredDevices.isEmpty {
                Text(ble.state == .scanning ? "Searching nearby…" : "No devices found yet.")
                    .font(.caption)
                    .foregroundStyle(NivaraColor.textSecondary)
            }

            ForEach(ble.discoveredDevices) { device in
                Button {
                    ble.connect(to: device)
                } label: {
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(NivaraColor.forestGreen)
                        Text(device.name)
                            .foregroundStyle(NivaraColor.textPrimary)
                        Spacer()
                        Text("\(device.rssi) dBm")
                            .font(.caption2)
                            .foregroundStyle(NivaraColor.textSecondary)
                    }
                    .padding(12)
                    .background(NivaraColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            skipLink
        }
    }

    // MARK: - Step 4

    private var confirmStep: some View {
        VStack(spacing: 16) {
            if let name = ble.connectedDeviceName {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(NivaraColor.forestGreen)
                Text("Connected to \(name)")
                    .font(.headline)
                    .foregroundStyle(NivaraColor.textPrimary)
            } else {
                ProgressView()
                Text("Connecting…")
                    .font(.subheadline)
                    .foregroundStyle(NivaraColor.textSecondary)
                Button("Back to device list") { deviceStep = 3 }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NivaraColor.forestGreen)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    // MARK: - Step 5

    private var measurementStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insert a test strip and apply your blood sample as you normally would. We'll pick up the result automatically — no need to do anything else in the app.")
                .font(.subheadline)
                .foregroundStyle(NivaraColor.textSecondary)

            if let reading = viewModel.pendingMealTimingConfirmation {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(NivaraColor.forestGreen)
                    Text("Reading received — \(reading.glucoseMgDl) mg/dL")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NivaraColor.textPrimary)
                }
                .padding(14)
                .background(NivaraColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Waiting for your reading…")
                        .font(.subheadline)
                        .foregroundStyle(NivaraColor.textSecondary)
                }
                .padding(14)
                .background(NivaraColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            skipLink
        }
    }

    private var skipLink: some View {
        Button("Skip for now — I'll finish this later") {
            onFinished()
        }
        .font(.caption)
        .foregroundStyle(NivaraColor.textSecondary)
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        switch deviceStep {
        case 1:
            OnboardingPrimaryButton(title: "Next") { deviceStep = 2 }
        case 2:
            OnboardingPrimaryButton(title: "Next") { deviceStep = 3 }
        case 3:
            EmptyView()
        case 4:
            OnboardingPrimaryButton(title: "Next", enabled: ble.connectedDeviceName != nil) { deviceStep = 5 }
        default:
            OnboardingPrimaryButton(
                title: viewModel.pendingMealTimingConfirmation != nil ? "Continue" : "Continue Anyway",
                action: onFinished
            )
        }
    }
}

#Preview {
    OnboardingDeviceSetupView(onBack: {}, onFinished: {})
        .environmentObject(PatientViewModel())
}
