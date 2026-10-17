import SwiftUI

/// Collects only what's needed to personalize the app and identify the
/// patient — deliberately short, per the guided-onboarding goal of minimal
/// friction before consent and device setup.
struct OnboardingBasicInfoView: View {
    @EnvironmentObject private var onboarding: OnboardingStore
    let onNext: () -> Void
    let onBack: () -> Void

    // Fetched once when this screen appears (see SupabaseService.fetchClinics).
    // Empty if Supabase isn't configured, there's no network, or there are
    // simply no clinics yet — the picker then just doesn't show, matching
    // this app's "never block onboarding on a backend issue" philosophy.
    // When the list DOES load, picking one is required: silently leaving a
    // real patient unassigned to any clinic is the thing clinic isolation
    // (see supabase/migrations/0003_clinics_and_staff.sql) exists to avoid.
    @State private var clinics: [Clinic] = []

    private var canContinue: Bool {
        let namesValid = !onboarding.firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
            !onboarding.lastName.trimmingCharacters(in: .whitespaces).isEmpty
        let clinicValid = clinics.isEmpty || onboarding.selectedClinicId != nil
        return namesValid && clinicValid
    }

    private var defaultDateOfBirth: Date {
        Calendar.current.date(byAdding: .year, value: -45, to: Date()) ?? Date()
    }

    var body: some View {
        OnboardingScaffold(
            title: onboarding.t("basicinfo_title"),
            subtitle: onboarding.t("basicinfo_subtitle"),
            step: 1,
            totalSteps: 3,
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 20) {
                labeledField(onboarding.t("basicinfo_first_name")) {
                    TextField(onboarding.t("basicinfo_first_name"), text: $onboarding.firstName)
                        .textInputAutocapitalization(.words)
                }
                labeledField(onboarding.t("basicinfo_last_name")) {
                    TextField(onboarding.t("basicinfo_last_name"), text: $onboarding.lastName)
                        .textInputAutocapitalization(.words)
                }
                labeledField(onboarding.t("basicinfo_date_of_birth")) {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { onboarding.dateOfBirth ?? defaultDateOfBirth },
                            set: { onboarding.dateOfBirth = $0 }
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }
                if !clinics.isEmpty {
                    labeledField(onboarding.t("basicinfo_clinic")) {
                        Picker(
                            onboarding.t("basicinfo_clinic"),
                            selection: Binding(
                                get: { onboarding.selectedClinicId },
                                set: { onboarding.selectedClinicId = $0 }
                            )
                        ) {
                            Text(onboarding.t("basicinfo_select_clinic")).tag(UUID?.none)
                            ForEach(clinics) { clinic in
                                Text(clinic.name).tag(Optional(clinic.id))
                            }
                        }
                        .labelsHidden()
                    }
                }
            }
        } footer: {
            OnboardingPrimaryButton(title: onboarding.t("common_next"), enabled: canContinue, action: onNext)
        }
        .task {
            clinics = await SupabaseService.fetchClinics()
        }
    }

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NivaraColor.textPrimary)
            content()
                .padding(14)
                .background(NivaraColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NivaraColor.border))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    OnboardingBasicInfoView(onNext: {}, onBack: {})
        .environmentObject(OnboardingStore())
}
