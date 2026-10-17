import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: PatientViewModel
    @EnvironmentObject private var onboarding: OnboardingStore
    @Binding var selectedTab: AppTab

    private var profile: PatientProfile { viewModel.profile }

    /// Prefers the name the patient typed during onboarding — the most
    /// personalized thing we have — falling back to the bundled clinical
    /// profile's name if onboarding was skipped.
    private var firstName: String {
        if !onboarding.firstName.isEmpty { return onboarding.firstName }
        return profile.name.components(separatedBy: " ").first ?? profile.name
    }

    /// Which device(s) to suggest connecting, based on the patient's
    /// actual condition(s) rather than assuming every patient tracks
    /// glucose.
    private var takeMeasurementSubtitle: String {
        switch (profile.conditions.contains(.hypertension), profile.conditions.contains(.diabetes)) {
        case (true, true): return onboarding.t("home_take_measurement_subtitle_both")
        case (true, false): return onboarding.t("home_take_measurement_subtitle_bp")
        case (false, true): return onboarding.t("home_take_measurement_subtitle_glucose")
        case (false, false): return onboarding.t("home_take_measurement_subtitle_generic")
        }
    }

    /// A short "in progress" label while `autoReconnectIfKnownDevice()` is
    /// actively working — nil (and so hidden) for every other BLE state,
    /// deliberately including `.failed`: this is a background convenience
    /// triggered just by opening the app, not something the patient asked
    /// for on this screen, so a failure (device out of range, Bluetooth
    /// off, nothing paired yet) should stay invisible here rather than
    /// read as an error. The Devices screen remains where a patient-
    /// initiated attempt shows its real outcome.
    private var autoSyncStatusText: String? {
        switch viewModel.bleManager.state {
        case .connecting: return onboarding.t("home_connecting_to_device")
        case .readingOmronHistory(let message): return message
        default: return nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(NivaraDate.greeting(language: onboarding.selectedLanguage)), \(firstName)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(NivaraColor.textPrimary)
                        Text(Date(), style: .date)
                            .font(.subheadline)
                            .foregroundStyle(NivaraColor.textSecondary)
                    }
                    .padding(.top, 8)

                    if let autoSyncStatusText {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(autoSyncStatusText)
                                .font(.caption)
                                .foregroundStyle(NivaraColor.textSecondary)
                        }
                    }

                    if let reassurance = viewModel.postMeasurementMessage {
                        reassuranceCard(reassurance)
                    }

                    if let lapseDays = viewModel.daysSinceLastRelevantReading, lapseDays > 2 {
                        lapseNudgeCard(days: lapseDays)
                    }

                    measurementStatusCard

                    consistencyCard

                    reviewTrendsCard

                    if let goal = profile.smartGoals.first {
                        goalPreview(goal)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(NivaraColor.cream)
            .navigationBarHidden(true)
            .onAppear {
                // The friction patients (and testers) specifically flagged:
                // having to manually open Devices and tap "Scan" every time
                // just to pull in a reading already sitting on a
                // previously-paired meter/cuff. Reconnecting here means
                // that, for the common case of the same device, a reading
                // is already syncing in the background before the patient
                // finishes reading their greeting.
                viewModel.bleManager.autoReconnectIfKnownDevice()
            }
        }
    }

    private func reassuranceCard(_ reassurance: PostMeasurementMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: reassurance.level == .normal ? "checkmark.circle.fill" : "info.circle.fill")
                .foregroundStyle(reassurance.level.color)
            Text(reassurance.text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(NivaraColor.textPrimary)
        }
        .padding(14)
        .background(reassurance.level.backgroundColor)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(reassurance.level.color.opacity(0.3)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .transition(.opacity)
    }

    /// Shown when it's been more than 2 days since the last reading relevant
    /// to the patient's condition(s) — a stronger, more specific signal than
    /// the daily "take a measurement" prompt below, for a gap long enough it
    /// might warrant a check-in.
    private func lapseNudgeCard(days: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bell.badge.fill")
                .foregroundStyle(NivaraColor.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text(onboarding.t("home_lapse_nudge_title", days))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NivaraColor.textPrimary)
                Text(onboarding.t("home_lapse_nudge_subtitle"))
                    .font(.caption)
                    .foregroundStyle(NivaraColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(NivaraColor.warningBackground)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NivaraColor.warning.opacity(0.3)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// Consistency framing tends to land better with patients than another
    /// raw mg/dL number — "on track with your routine" over a data point.
    private var consistencyCard: some View {
        let count = viewModel.readingsThisWeek
        return HStack(spacing: 12) {
            Image(systemName: count >= 3 ? "flame.fill" : "flag.checkered")
                .font(.title3)
                .foregroundStyle(NivaraColor.forestGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text(onboarding.t(count == 1 ? "home_readings_this_week_one" : "home_readings_this_week_other", count))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NivaraColor.textPrimary)
                Text(consistencyMessage(for: count))
                    .font(.caption)
                    .foregroundStyle(NivaraColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .nivaraCard()
    }

    private func consistencyMessage(for count: Int) -> String {
        switch count {
        case 0: return onboarding.t("home_consistency_zero")
        case 1...2: return onboarding.t("home_consistency_some")
        default: return onboarding.t("home_consistency_good")
        }
    }

    @ViewBuilder
    private var measurementStatusCard: some View {
        if viewModel.tookReadingToday {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title)
                    .foregroundStyle(NivaraColor.forestGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text(onboarding.t("home_measurement_done_title"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NivaraColor.textPrimary)
                    Text(onboarding.t("home_measurement_done_subtitle"))
                        .font(.caption)
                        .foregroundStyle(NivaraColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .nivaraCard()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(NivaraColor.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(onboarding.t("home_measurement_pending_title"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NivaraColor.textPrimary)
                        Text(takeMeasurementSubtitle)
                            .font(.caption)
                            .foregroundStyle(NivaraColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                }

                NavigationLink {
                    DeviceConnectionView()
                } label: {
                    Text(onboarding.t("home_take_measurement_button"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(NivaraColor.forestGreen)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .nivaraCard()
        }
    }

    private var reviewTrendsCard: some View {
        Button {
            selectedTab = .myHealth
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title3)
                    .foregroundStyle(NivaraColor.forestGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text(onboarding.t("home_review_trends_title"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NivaraColor.textPrimary)
                    Text(onboarding.t("home_review_trends_subtitle"))
                        .font(.caption)
                        .foregroundStyle(NivaraColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NivaraColor.textSecondary)
            }
            .nivaraCard()
        }
        .buttonStyle(.plain)
    }

    private func goalPreview(_ goal: SmartGoal) -> some View {
        Button {
            selectedTab = .careTeam
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(onboarding.t("home_your_goal"), systemImage: "target")
                        .font(.caption)
                        .foregroundStyle(NivaraColor.textSecondary)
                    Spacer()
                    PillLabel(text: goal.status.rawValue, color: goal.status.color, background: goal.status.color.opacity(0.15))
                }
                Text(goal.description)
                    .font(.subheadline)
                    .foregroundStyle(NivaraColor.textPrimary)
                    .multilineTextAlignment(.leading)
            }
            .nivaraCard()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView(selectedTab: .constant(.home))
        .environmentObject(PatientViewModel())
        .environmentObject(OnboardingStore())
}
