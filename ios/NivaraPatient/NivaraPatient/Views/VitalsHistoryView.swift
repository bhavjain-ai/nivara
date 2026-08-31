import SwiftUI
import Charts

struct VitalsHistoryView: View {
    @EnvironmentObject private var viewModel: PatientViewModel

    private var profile: PatientProfile { viewModel.profile }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if profile.conditions.contains(.hypertension) {
                        bpChartSection
                    }
                    if profile.conditions.contains(.diabetes) {
                        glucoseChartSection
                        if profile.hba1cTier != nil {
                            hba1cChartSection
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("History")
        }
    }

    private var bpChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BLOOD PRESSURE")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)

            if viewModel.vitals.bpReadings.isEmpty {
                emptyState
            } else {
                Chart {
                    ForEach(viewModel.vitals.bpReadings) { reading in
                        LineMark(x: .value("Date", reading.date), y: .value("Systolic", reading.systolic), series: .value("Series", "Systolic"))
                            .foregroundStyle(NivaraColor.navy)
                        LineMark(x: .value("Date", reading.date), y: .value("Diastolic", reading.diastolic), series: .value("Series", "Diastolic"))
                            .foregroundStyle(.blue.opacity(0.6))
                    }
                    if let target = profile.bpTarget {
                        RuleMark(y: .value("Target", target.systolic))
                            .foregroundStyle(NivaraColor.normal.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month())
                    }
                }

                legendRow([("Systolic", NivaraColor.navy), ("Diastolic", .blue.opacity(0.6))])

                if let target = profile.bpTarget {
                    Text("Your target: \(target.label)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var glucoseChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BLOOD GLUCOSE")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)

            if viewModel.vitals.glucoseReadings.isEmpty {
                emptyState
            } else {
                Chart {
                    ForEach(viewModel.vitals.glucoseReadings) { reading in
                        PointMark(x: .value("Date", reading.date), y: .value("Glucose", reading.glucoseMgDl))
                            .foregroundStyle(reading.sampleType == .fasting ? Color.orange : Color.pink)
                        LineMark(x: .value("Date", reading.date), y: .value("Glucose", reading.glucoseMgDl))
                            .foregroundStyle(.gray.opacity(0.3))
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month())
                    }
                }

                legendRow([("Fasting", .orange), ("Post-meal", .pink)])

                if let latest = viewModel.vitals.latestGlucose {
                    retagRow(for: latest)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var hba1cChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HbA1c")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)

            if viewModel.vitals.hba1cReadings.isEmpty {
                emptyState
            } else {
                Chart {
                    ForEach(viewModel.vitals.hba1cReadings) { reading in
                        LineMark(x: .value("Date", reading.date), y: .value("HbA1c", reading.value))
                            .foregroundStyle(.purple)
                        PointMark(x: .value("Date", reading.date), y: .value("HbA1c", reading.value))
                            .foregroundStyle(.purple)
                    }
                    if let tier = profile.hba1cTier {
                        RuleMark(y: .value("Target", tier.targetValue))
                            .foregroundStyle(NivaraColor.normal.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month())
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyState: some View {
        Text("No readings yet.")
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, minHeight: 80)
    }

    private func legendRow(_ items: [(String, Color)]) -> some View {
        HStack(spacing: 14) {
            ForEach(items, id: \.0) { item in
                HStack(spacing: 4) {
                    Circle().fill(item.1).frame(width: 8, height: 8)
                    Text(item.0).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Your meter can't reliably tell the app whether a reading was fasting or
    /// post-meal, so the app guesses — this lets you fix the most recent one.
    private func retagRow(for reading: GlucoseReading) -> some View {
        HStack(spacing: 8) {
            Text("Latest reading tagged as \(reading.sampleType.displayName.lowercased()). Wrong?")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                let corrected: GlucoseSampleType = reading.sampleType == .fasting ? .postMeal : .fasting
                viewModel.vitals.retagLatestGlucose(as: corrected)
            } label: {
                Text("Mark as \((reading.sampleType == .fasting ? GlucoseSampleType.postMeal : .fasting).displayName)")
                    .font(.caption2.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(NivaraColor.navy)
        }
        .padding(.top, 2)
    }
}

#Preview {
    VitalsHistoryView().environmentObject(PatientViewModel())
}
