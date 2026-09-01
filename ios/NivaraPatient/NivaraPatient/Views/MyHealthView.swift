import SwiftUI
import Charts

/// Focused on the initial (Type 2 diabetes) patient population: HbA1c and
/// fasting blood glucose only. Blood pressure and medications have their own
/// homes (BP would live here too once the hypertension population launches;
/// medications are their own tab so patients aren't hunting for them at the
/// bottom of a long page).
struct MyHealthView: View {
    @EnvironmentObject private var viewModel: PatientViewModel

    private var profile: PatientProfile { viewModel.profile }

    private var fastingReadings: [GlucoseReading] {
        viewModel.vitals.glucoseReadings.filter { $0.sampleType == .fasting }
    }

    /// Status for the latest *fasting* reading specifically — not
    /// `viewModel.latestGlucoseStatus`, which tracks the latest glucose
    /// reading of any type and would mismatch the fasting value shown here
    /// whenever the most recent reading overall was post-meal.
    private var fastingStatus: VitalStatus? {
        guard let latest = fastingReadings.last, let tier = profile.hba1cTier else { return nil }
        let targets = ClinicalGuidelines.glucoseTargets(forTier: tier.tier)
        return ClinicalGuidelines.analyzeGlucose(glucose: latest.glucoseMgDl, sampleType: .fasting, targets: targets)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hba1cSection
                    fastingGlucoseSection
                }
                .padding()
            }
            .background(NivaraColor.cream)
            .navigationTitle("My Health")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        DeviceConnectionView()
                    } label: {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(NivaraColor.forestGreen)
                    }
                }
            }
        }
    }

    // MARK: - HbA1c

    private var hba1cSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("HbA1c", icon: "testtube.2")

            if let latest = viewModel.vitals.latestHbA1c {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(format: "%.1f", latest.value))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(NivaraColor.textPrimary)
                        Text("%")
                            .font(.subheadline)
                            .foregroundStyle(NivaraColor.textSecondary)
                    }
                    Text(NivaraDate.relative(latest.date))
                        .font(.caption)
                        .foregroundStyle(NivaraColor.textSecondary)
                    if let tier = profile.hba1cTier {
                        Text("Your target: \(tier.targetLabel)")
                            .font(.caption2)
                            .foregroundStyle(NivaraColor.textSecondary)
                    }
                }

                if viewModel.vitals.hba1cReadings.count > 1 {
                    hba1cChart
                }

                recentHbA1cReadings
            } else {
                noReadingYet
            }
        }
        .nivaraCard()
    }

    private var hba1cChart: some View {
        Chart {
            ForEach(viewModel.vitals.hba1cReadings) { reading in
                LineMark(x: .value("Date", reading.date), y: .value("HbA1c", reading.value))
                    .foregroundStyle(NivaraColor.forestGreen)
                PointMark(x: .value("Date", reading.date), y: .value("HbA1c", reading.value))
                    .foregroundStyle(NivaraColor.forestGreen)
            }
            if let tier = profile.hba1cTier {
                RuleMark(y: .value("Target", tier.targetValue))
                    .foregroundStyle(NivaraColor.warning.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .frame(height: 140)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month().year(.twoDigits))
            }
        }
        .padding(.top, 4)
    }

    private var recentHbA1cReadings: some View {
        let recent = Array(viewModel.vitals.hba1cReadings.suffix(5).reversed())
        return VStack(alignment: .leading, spacing: 10) {
            Text("RECENT A1C RESULTS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NivaraColor.textSecondary)
                .padding(.top, 6)

            ForEach(recent) { reading in
                HStack {
                    Text(NivaraDate.short.string(from: reading.date))
                        .font(.caption)
                        .foregroundStyle(NivaraColor.textSecondary)
                    Spacer()
                    Text(String(format: "%.1f%%", reading.value))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NivaraColor.textPrimary)
                }
                Divider()
            }

            if viewModel.vitals.hba1cReadings.count > 5 {
                NavigationLink {
                    HbA1cHistoryListView()
                } label: {
                    Text("See More")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NivaraColor.forestGreen)
                }
            }
        }
    }

    // MARK: - Fasting Glucose

    private var fastingGlucoseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Fasting Blood Glucose", icon: "drop.fill")

            if let latest = fastingReadings.last {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(latest.glucoseMgDl)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(NivaraColor.textPrimary)
                        Text("mg/dL")
                            .font(.subheadline)
                            .foregroundStyle(NivaraColor.textSecondary)
                    }
                    Text(NivaraDate.relative(latest.date))
                        .font(.caption)
                        .foregroundStyle(NivaraColor.textSecondary)
                    if let status = fastingStatus {
                        Text(status.message)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(status.level.color)
                    }
                }

                if fastingReadings.count > 1 {
                    fastingChart
                }

                recentFastingReadings

                if let latestOverall = viewModel.vitals.latestGlucose {
                    retagRow(for: latestOverall)
                }
            } else {
                noReadingYet
            }
        }
        .nivaraCard()
    }

    private var fastingChart: some View {
        Chart {
            ForEach(fastingReadings) { reading in
                LineMark(x: .value("Date", reading.date), y: .value("Glucose", reading.glucoseMgDl))
                    .foregroundStyle(NivaraColor.forestGreen.opacity(0.4))
                PointMark(x: .value("Date", reading.date), y: .value("Glucose", reading.glucoseMgDl))
                    .foregroundStyle(NivaraColor.forestGreen)
            }
        }
        .frame(height: 140)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month())
            }
        }
        .padding(.top, 4)
    }

    private var recentFastingReadings: some View {
        let recent = Array(fastingReadings.suffix(5).reversed())
        return VStack(alignment: .leading, spacing: 10) {
            Text("RECENT READINGS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NivaraColor.textSecondary)
                .padding(.top, 6)

            ForEach(recent) { reading in
                HStack {
                    Text(NivaraDate.shortWithTime.string(from: reading.date))
                        .font(.caption)
                        .foregroundStyle(NivaraColor.textSecondary)
                    Spacer()
                    Text("\(reading.glucoseMgDl) mg/dL")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NivaraColor.textPrimary)
                }
                Divider()
            }

            if fastingReadings.count > 5 {
                NavigationLink {
                    GlucoseHistoryListView()
                } label: {
                    Text("See More")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NivaraColor.forestGreen)
                }
            }
        }
    }

    /// Meters don't reliably signal fasting vs. post-meal, so the app guesses
    /// — this lets the patient fix the most recent reading if it's wrong
    /// (relevant here since a mis-tagged post-meal reading would otherwise
    /// silently disappear from — or wrongly appear in — the fasting trend).
    private func retagRow(for reading: GlucoseReading) -> some View {
        HStack(spacing: 8) {
            Text("Latest reading tagged as \(reading.sampleType.displayName.lowercased()). Wrong?")
                .font(.caption2)
                .foregroundStyle(NivaraColor.textSecondary)
            Spacer()
            Button {
                let corrected: GlucoseSampleType = reading.sampleType == .fasting ? .postMeal : .fasting
                viewModel.vitals.retagLatestGlucose(as: corrected)
            } label: {
                Text("Mark as \((reading.sampleType == .fasting ? GlucoseSampleType.postMeal : .fasting).displayName)")
                    .font(.caption2.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(NivaraColor.forestGreen)
        }
        .padding(.top, 4)
    }

    // MARK: - Shared bits

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(NivaraColor.forestGreen)
    }

    private var noReadingYet: some View {
        Text("No reading yet — connect a device to get started.")
            .font(.subheadline)
            .foregroundStyle(NivaraColor.textSecondary)
    }
}

#Preview {
    MyHealthView().environmentObject(PatientViewModel())
}
