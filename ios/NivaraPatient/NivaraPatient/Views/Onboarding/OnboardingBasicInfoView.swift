import SwiftUI

/// Collects only what's needed to personalize the app and identify the
/// patient — deliberately short, per the guided-onboarding goal of minimal
/// friction before consent and device setup.
struct OnboardingBasicInfoView: View {
    @EnvironmentObject private var onboarding: OnboardingStore
    let onNext: () -> Void
    let onBack: () -> Void

    // The patient types their clinic's join code here; it's resolved to a
    // clinic id via SupabaseService.resolveClinic(byJoinCode:) rather than
    // picked from a browsable list — see
    // supabase/migrations/0005_clinic_join_codes.sql. This is the actual
    // access gate (an App Store download alone shouldn't be enough to
    // register as a patient), so unlike the old picker, this blocks
    // "Next" until a code resolves successfully — UNLESS Supabase isn't
    // configured at all, which still falls back to no gate so local/demo
    // builds without a backend keep working for development.
    @State private var joinCode: String = ""
    @State private var resolvedClinic: Clinic?
    @State private var isResolving = false
    @State private var codeWasInvalid = false
    @State private var resolveTask: Task<Void, Never>?

    private var canContinue: Bool {
        let namesValid = !onboarding.firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
            !onboarding.lastName.trimmingCharacters(in: .whitespaces).isEmpty
        let clinicValid = !SupabaseConfig.isConfigured || resolvedClinic != nil
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
                if SupabaseConfig.isConfigured {
                    VStack(alignment: .leading, spacing: 6) {
                        labeledField(onboarding.t("basicinfo_clinic_code")) {
                            TextField(onboarding.t("basicinfo_clinic_code_placeholder"), text: $joinCode)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .onChange(of: joinCode) { newValue in
                                    scheduleResolve(for: newValue)
                                }
                        }
                        clinicCodeStatus
                    }
                }
            }
        } footer: {
            OnboardingPrimaryButton(title: onboarding.t("common_next"), enabled: canContinue, action: onNext)
        }
    }

    @ViewBuilder
    private var clinicCodeStatus: some View {
        if isResolving {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(onboarding.t("basicinfo_clinic_checking"))
                    .font(.caption2)
                    .foregroundStyle(NivaraColor.textSecondary)
            }
        } else if let resolvedClinic {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(NivaraColor.forestGreen)
                Text(onboarding.t("basicinfo_clinic_confirmed", resolvedClinic.name))
                    .font(.caption2)
                    .foregroundStyle(NivaraColor.forestGreen)
            }
        } else if codeWasInvalid {
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(NivaraColor.critical)
                Text(onboarding.t("basicinfo_clinic_invalid"))
                    .font(.caption2)
                    .foregroundStyle(NivaraColor.critical)
            }
        }
    }

    /// Debounces resolution so every keystroke doesn't fire a network call
    /// — cancels any in-flight attempt and waits briefly for typing to
    /// pause first. A stale response can never land after a newer one
    /// starts: `resolveTask` is overwritten before the old task's
    /// `Task.isCancelled` check even runs.
    private func scheduleResolve(for newValue: String) {
        resolveTask?.cancel()
        resolvedClinic = nil
        codeWasInvalid = false
        onboarding.selectedClinicId = nil

        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isResolving = false
            return
        }

        isResolving = true
        resolveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            let clinic = await SupabaseService.resolveClinic(byJoinCode: trimmed)
            guard !Task.isCancelled else { return }
            isResolving = false
            if let clinic {
                resolvedClinic = clinic
                onboarding.selectedClinicId = clinic.id
            } else {
                codeWasInvalid = true
            }
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
