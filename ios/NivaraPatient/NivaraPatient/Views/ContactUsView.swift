import SwiftUI

struct ContactUsView: View {
    @EnvironmentObject private var viewModel: PatientViewModel

    private var profile: PatientProfile { viewModel.profile }

    /// The physician has their own card above, so this is scoped to the
    /// dietician/coach roles to avoid showing the same person twice.
    private var mostRecentCoordinator: OutreachCall? {
        profile.outreachLog
            .filter { $0.coordinatorRole != .physician }
            .max(by: { $0.date < $1.date })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageTitle(text: "Contact Us")
                        .padding(.top, 8)

                    contactCard(
                        icon: "stethoscope",
                        title: "Your Physician",
                        name: profile.physicianName,
                        subtitle: "Primary care physician",
                        phone: profile.physicianPhone
                    )

                    if let coordinator = mostRecentCoordinator {
                        contactCard(
                            icon: "heart.text.square.fill",
                            title: "Your Care Coordinator",
                            name: coordinator.coordinatorName,
                            subtitle: coordinator.coordinatorRole.rawValue,
                            phone: nil
                        )
                    }

                    contactCard(
                        icon: "questionmark.circle.fill",
                        title: "Nivara Support",
                        name: "Nivara Health Support Team",
                        subtitle: "Mon–Sat, 9am–7pm IST",
                        phone: "+91-80000-00000",
                        email: "support@nivarahealth.com",
                        whatsapp: "+91-80000-00000"
                    )

                    emergencyNotice

                    deviceInfoCard
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(NivaraColor.cream)
            .navigationBarHidden(true)
        }
    }

    private func contactCard(icon: String, title: String, name: String, subtitle: String, phone: String?, email: String? = nil, whatsapp: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(NivaraColor.forestGreen)

            Text(name)
                .font(.headline)
                .foregroundStyle(NivaraColor.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(NivaraColor.textSecondary)

            HStack(spacing: 10) {
                if let phone, let url = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") {
                    Link(destination: url) {
                        contactButton(icon: "phone.fill", label: "Call")
                    }
                }
                if let email, let url = URL(string: "mailto:\(email)") {
                    Link(destination: url) {
                        contactButton(icon: "envelope.fill", label: "Email")
                    }
                }
                // wa.me deep links into the WhatsApp app if installed, or a
                // web fallback otherwise — this leaves the app for WhatsApp
                // (there's no way to embed WhatsApp's own chat UI inside a
                // third-party app), same as tel:/mailto: leave it for the
                // Phone/Mail apps above.
                if let whatsapp, let url = URL(string: "https://wa.me/\(whatsapp.filter { $0.isNumber })") {
                    Link(destination: url) {
                        contactButton(icon: "message.fill", label: "WhatsApp")
                    }
                }
            }
            .padding(.top, 2)
        }
        .nivaraCard()
    }

    private func contactButton(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(label)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(NivaraColor.forestGreen)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(NivaraColor.sageGreen)
        .clipShape(Capsule())
    }

    /// Surfaces `DeviceIdentity.current` for support/debugging purposes —
    /// this is the identifier a backend would use to recognize "this
    /// device" on re-launch without an SMS/OTP flow (see DeviceIdentity.swift
    /// for the full rationale). Nothing sends it anywhere in this
    /// self-contained demo build; it's shown here so it's inspectable.
    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("About This Device", systemImage: "iphone")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NivaraColor.forestGreen)
            Text("Device ID: \(String(DeviceIdentity.current.prefix(8)))…")
                .font(.caption)
                .foregroundStyle(NivaraColor.textSecondary)
            Text("If you contact support, they may ask for this ID to help locate your account.")
                .font(.caption2)
                .foregroundStyle(NivaraColor.textSecondary)
        }
        .nivaraCard()
    }

    private var emergencyNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(NivaraColor.critical)
            Text("If this is a medical emergency, call your local emergency number immediately — don't wait for a response here.")
                .font(.caption)
                .foregroundStyle(NivaraColor.textPrimary)
        }
        .padding(14)
        .background(NivaraColor.criticalBackground)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NivaraColor.critical.opacity(0.2)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    ContactUsView().environmentObject(PatientViewModel())
}
