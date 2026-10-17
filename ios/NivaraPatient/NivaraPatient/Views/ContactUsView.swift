import SwiftUI

struct ContactUsView: View {
    @EnvironmentObject private var viewModel: PatientViewModel
    @EnvironmentObject private var onboarding: OnboardingStore

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
                    PageTitle(text: onboarding.t("contact_page_title"))
                        .padding(.top, 8)

                    contactCard(
                        icon: "stethoscope",
                        title: onboarding.t("contact_your_physician"),
                        name: profile.physicianName,
                        subtitle: onboarding.t("contact_primary_care_physician")
                    )

                    if let coordinator = mostRecentCoordinator {
                        contactCard(
                            icon: "heart.text.square.fill",
                            title: onboarding.t("contact_your_care_coordinator"),
                            name: coordinator.coordinatorName,
                            subtitle: coordinator.coordinatorRole.displayName(for: onboarding.selectedLanguage)
                        )
                    }

                    contactCard(
                        icon: "questionmark.circle.fill",
                        title: onboarding.t("contact_nivara_support"),
                        name: onboarding.t("contact_support_team_name"),
                        subtitle: onboarding.t("contact_support_hours")
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

    /// Deliberately informational only — no call/email/WhatsApp actions.
    /// Reaching the care team happens through the in-app Care Team chat
    /// (CareTeamConversationView); a doctor who needs to call a patient
    /// does so outbound via WhatsApp on their own, not triggered from here.
    private func contactCard(icon: String, title: String, name: String, subtitle: String) -> some View {
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
        }
        .nivaraCard()
    }

    /// Surfaces `DeviceIdentity.current` for support/debugging purposes —
    /// this is the identifier a backend would use to recognize "this
    /// device" on re-launch without an SMS/OTP flow (see DeviceIdentity.swift
    /// for the full rationale). Nothing sends it anywhere in this
    /// self-contained demo build; it's shown here so it's inspectable.
    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(onboarding.t("contact_about_device"), systemImage: "iphone")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NivaraColor.forestGreen)
            Text(onboarding.t("contact_device_id", String(DeviceIdentity.current.prefix(8))))
                .font(.caption)
                .foregroundStyle(NivaraColor.textSecondary)
            Text(onboarding.t("contact_device_id_explanation"))
                .font(.caption2)
                .foregroundStyle(NivaraColor.textSecondary)
        }
        .nivaraCard()
    }

    private var emergencyNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(NivaraColor.critical)
            Text(onboarding.t("contact_emergency_notice"))
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
    ContactUsView()
        .environmentObject(PatientViewModel())
        .environmentObject(OnboardingStore())
}
