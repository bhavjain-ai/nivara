import SwiftUI
import Charts

struct MyHealthView: View {
    @EnvironmentObject private var viewModel: PatientViewModel

    private var profile: PatientProfile { viewModel.profile }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if profile.conditions.contains(.hypertension) {
                        bloodPressureSection
                    }
                    if profile.conditions.contains(.diabetes) {
                        glucoseSection
                        if profile.hba1cTier != nil {
                            hba1cSection
                        }
                    }
                    medicationsSection
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

    // MARK: - Blood Pressure

    private var bloodPressureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Blood Pressure", icon: "heart.fill")

            if let latest = viewModel.vitals.latestBP {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(latest.systolic)/\(latest.diastolic)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(NivaraColor.textPrimary)
                        Text("mmHg")
                            .font(.subheadline)
                            .foregroundStyle(NivaraColor.textSecondary)
                    }
                    Text(NivaraDate.relative(latest.date))
                        .font(.caption)
                        .foregroundStyle(NivaraColor.textSecondary)
                    if let status = viewModel.latestBPStatus {
                        Text(status.message)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(status.level.color)
                    }
                    if let target = profile.bpTarget {
                        Text("Your target: \(target.label)")
                            .font(.caption2)
                            .foregroundStyle(NivaraColor.textSecondary)
                            .padding(.top, 2)
                    }
                }

                if viewModel.vitals.bpReadings.count > 1 {
                    bpChart
                }

                recentBPReadings
            } else {
                noReadingYet
            }
        }
        .nivaraCard()
    }

    private var bpChart: some View {
        Chart {
            ForEach(viewModel.vitals.bpReadings) { reading in
                LineMark(x: .value("Date", reading.date), y: .value("Systolic", reading.systolic), series: .value("Series", "Systolic"))
                    .foregroundStyle(NivaraColor.forestGreen)
                LineMark(x: .value("Date", reading.date), y: .value("Diastolic", reading.diastolic), series: .value("Series", "Diastolic"))
                    .foregroundStyle(NivaraColor.forestGreen.opacity(0.45))
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

    private var recentBPReadings: some View {
        let recent = Array(viewModel.vitals.bpReadings.suffix(5).reversed())
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
                    Text("\(reading.systolic)/\(reading.diastolic) mmHg")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NivaraColor.textPrimary)
                }
                Divider()
            }

            if viewModel.vitals.bpReadings.count > 5 {
                NavigationLink {
                    BPHistoryListView()
                } label: {
                    Text("See More")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NivaraColor.forestGreen)
                }
            }
        }
    }

    // MARK: - Glucose

    private var glucoseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Blood Glucose", icon: "drop.fill")

            if let latest = viewModel.vitals.latestGlucose {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(latest.glucoseMgDl)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(NivaraColor.textPrimary)
                        Text("mg/dL")
                            .font(.subheadline)
                            .foregroundStyle(NivaraColor.textSecondary)
                    }
                    Text("\(latest.sampleType.displayName) · \(NivaraDate.relative(latest.date))")
                        .font(.caption)
                        .foregroundStyle(NivaraColor.textSecondary)
                    if let status = viewModel.latestGlucoseStatus {
                        Text(status.message)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(status.level.color)
                    }
                }

                if viewModel.vitals.glucoseReadings.count > 1 {
                    glucoseChart
                }

                recentGlucoseReadings
            } else {
                noReadingYet
            }
        }
        .nivaraCard()
    }

    private var glucoseChart: some View {
        Chart {
            ForEach(viewModel.vitals.glucoseReadings) { reading in
                PointMark(x: .value("Date", reading.date), y: .value("Glucose", reading.glucoseMgDl))
                    .foregroundStyle(reading.sampleType == .fasting ? NivaraColor.forestGreen : Color.orange)
                LineMark(x: .value("Date", reading.date), y: .value("Glucose", reading.glucoseMgDl))
                    .foregroundStyle(NivaraColor.textSecondary.opacity(0.25))
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

    private var recentGlucoseReadings: some View {
        let recent = Array(viewModel.vitals.glucoseReadings.suffix(5).reversed())
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
                    PillLabel(text: reading.sampleType == .fasting ? "F" : "PP")
                }
                Divider()
            }

            if viewModel.vitals.glucoseReadings.count > 5 {
                NavigationLink {
                    GlucoseHistoryListView()
                } label: {
                    Text("See More")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NivaraColor.forestGreen)
                }
            }

            if let latest = viewModel.vitals.latestGlucose {
                retagRow(for: latest)
            }
        }
    }

    /// Meters don't reliably signal fasting vs. post-meal, so the app guesses
    /// — this lets the patient fix the most recent reading if it's wrong.
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

    // MARK: - HbA1c

    private var hba1cSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("HbA1c", icon: "testtube.2")

            if let latest = viewModel.vitals.latestHbA1c {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.1f", latest.value))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(NivaraColor.textPrimary)
                    Text("%")
                        .font(.subheadline)
                        .foregroundStyle(NivaraColor.textSecondary)
                }
                if let tier = profile.hba1cTier {
                    Text("Your target: \(tier.targetLabel)")
                        .font(.caption)
                        .foregroundStyle(NivaraColor.textSecondary)
                }
            } else {
                noReadingYet
            }
        }
        .nivaraCard()
    }

    // MARK: - Medications

    private var medicationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Medications", icon: "pills.fill")

            ForEach(profile.medications) { med in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(med.name).font(.subheadline.weight(.semibold)).foregroundStyle(NivaraColor.textPrimary)
                        Spacer()
                        PillLabel(text: med.drugClass)
                    }
                    Text("\(med.dose) · \(med.frequency)")
                        .font(.caption)
                        .foregroundStyle(NivaraColor.textSecondary)
                }
                .padding(.vertical, 4)
                Divider()
            }

            Text("Prescribed by \(profile.physicianName)")
                .font(.caption2)
                .foregroundStyle(NivaraColor.textSecondary)
                .padding(.top, 2)
        }
        .nivaraCard()
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
