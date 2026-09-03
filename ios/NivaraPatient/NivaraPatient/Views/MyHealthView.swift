import SwiftUI
import Charts

/// Focused on the initial (Type 2 diabetes) patient population: HbA1c and
/// blood glucose only. Blood pressure and medications have their own homes
/// (BP would live here too once the hypertension population launches;
/// medications are their own tab so patients aren't hunting for them at the
/// bottom of a long page).
struct MyHealthView: View {
    @EnvironmentObject private var viewModel: PatientViewModel

    private var profile: PatientProfile { viewModel.profile }

    @State private var selectedGlucoseDate: Date?

    /// Nearest reading to the finger's current x-position while scrubbing the
    /// chart — nil (hides the overlay) once the drag ends.
    private var selectedGlucoseReading: GlucoseReading? {
        guard let selectedGlucoseDate else { return nil }
        return viewModel.vitals.glucoseReadings.min {
            abs($0.date.timeIntervalSince(selectedGlucoseDate)) < abs($1.date.timeIntervalSince(selectedGlucoseDate))
        }
    }

    /// A short "since your last A1C" line — patients respond better to a
    /// direction of travel than to sitting and comparing two raw numbers.
    /// Lower is the improving direction for A1C, so a drop is shown in green
    /// and a rise in amber.
    private var hba1cTrend: (text: String, color: Color)? {
        let readings = viewModel.vitals.hba1cReadings
        guard readings.count > 1 else { return nil }
        let delta = readings[readings.count - 1].value - readings[readings.count - 2].value
        if abs(delta) < 0.05 { return ("Unchanged since your last A1C", NivaraColor.textSecondary) }
        let arrow = delta < 0 ? "↓" : "↑"
        let text = "\(arrow) \(String(format: "%.1f", abs(delta)))% since your last A1C"
        return (text, delta < 0 ? NivaraColor.forestGreen : NivaraColor.warning)
    }

    /// "X of last N readings in range" — a quick consistency read on the
    /// most recent handful of glucose readings, each judged against its own
    /// tagged sample type.
    private var glucoseInRangeSummary: (text: String, color: Color)? {
        guard let tier = profile.hba1cTier else { return nil }
        let recent = Array(viewModel.vitals.glucoseReadings.suffix(5))
        guard !recent.isEmpty else { return nil }
        let targets = ClinicalGuidelines.glucoseTargets(forTier: tier.tier)
        let inRange = recent.filter {
            ClinicalGuidelines.analyzeGlucose(glucose: $0.glucoseMgDl, sampleType: $0.sampleType, targets: targets).level == .normal
        }.count
        let text = "\(inRange) of last \(recent.count) readings in range"
        return (text, inRange == recent.count ? NivaraColor.forestGreen : NivaraColor.warning)
    }

    /// Diabetes medication changes that fall inside the currently plotted
    /// glucose date range — filtered (rather than showing all history) so a
    /// change from months ago doesn't stretch the chart's x-axis domain out
    /// and flatten the recent trend.
    private var visibleMedicationChanges: [MedicationChange] {
        guard let earliest = viewModel.vitals.glucoseReadings.first?.date else { return [] }
        return profile.medicationHistory.filter { $0.relatedCondition == .diabetes && $0.date >= earliest }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        PageTitle(text: "My Health")
                        Spacer()
                        NavigationLink {
                            DeviceConnectionView()
                        } label: {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 18))
                                .foregroundStyle(NivaraColor.forestGreen)
                        }
                    }
                    .padding(.top, 8)

                    hba1cSection
                    glucoseSection
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(NivaraColor.cream)
            .navigationBarHidden(true)
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
                    if let trend = hba1cTrend {
                        Text(trend.text)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(trend.color)
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

    // MARK: - Blood Glucose

    /// Shows every reading regardless of fasting/post-meal — meters can't
    /// reliably tell the two apart from the signal alone, so classification
    /// is a best guess the patient (or care team) can correct via
    /// `retagRow`, not something the app should silently filter on.
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
                        PillLabel(text: latest.sampleType.displayName)
                    }
                    Text(NivaraDate.relative(latest.date))
                        .font(.caption)
                        .foregroundStyle(NivaraColor.textSecondary)
                    if let status = viewModel.latestGlucoseStatus {
                        Text(status.message)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(status.level.color)
                    }
                    if let summary = glucoseInRangeSummary {
                        Text(summary.text)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(summary.color)
                    }
                }

                if viewModel.vitals.glucoseReadings.count > 1 {
                    glucoseChart
                    glucoseLegend
                }

                recentGlucoseReadings

                retagRow(for: latest)
            } else {
                noReadingYet
            }
        }
        .nivaraCard()
    }

    private var glucoseChart: some View {
        Chart {
            ForEach(viewModel.vitals.glucoseReadings) { reading in
                LineMark(x: .value("Date", reading.date), y: .value("Glucose", reading.glucoseMgDl))
                    .foregroundStyle(NivaraColor.forestGreen.opacity(0.35))
                PointMark(x: .value("Date", reading.date), y: .value("Glucose", reading.glucoseMgDl))
                    .foregroundStyle(reading.sampleType == .fasting ? NivaraColor.forestGreen : NivaraColor.warning)
            }

            ForEach(visibleMedicationChanges) { change in
                RuleMark(x: .value("Date", change.date))
                    .foregroundStyle(NivaraColor.textSecondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .annotation(position: .top) {
                        Image(systemName: "pill.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(NivaraColor.textSecondary)
                    }
            }

            if let selected = selectedGlucoseReading {
                RuleMark(x: .value("Date", selected.date))
                    .foregroundStyle(NivaraColor.textSecondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                PointMark(x: .value("Date", selected.date), y: .value("Glucose", selected.glucoseMgDl))
                    .foregroundStyle(NivaraColor.textPrimary)
                    .symbolSize(120)
                    .annotation(position: .top) {
                        VStack(spacing: 2) {
                            Text("\(selected.glucoseMgDl) mg/dL")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(NivaraColor.textPrimary)
                            Text("\(selected.sampleType.displayName) · \(NivaraDate.shortWithTime.string(from: selected.date))")
                                .font(.caption2)
                                .foregroundStyle(NivaraColor.textSecondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(NivaraColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                    }
            }
        }
        .frame(height: 160)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month())
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let plotFrame = proxy.plotAreaFrame
                                let origin = geometry[plotFrame].origin
                                let x = value.location.x - origin.x
                                if let date: Date = proxy.value(atX: x) {
                                    selectedGlucoseDate = date
                                }
                            }
                            .onEnded { _ in
                                selectedGlucoseDate = nil
                            }
                    )
            }
        }
        .padding(.top, 4)
    }

    private var glucoseLegend: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 16) {
                legendDot(color: NivaraColor.forestGreen, label: "Fasting")
                legendDot(color: NivaraColor.warning, label: "Post-meal")
                Spacer()
                Text("Drag the graph to see a reading")
                    .font(.caption2)
                    .foregroundStyle(NivaraColor.textSecondary)
            }
            if !visibleMedicationChanges.isEmpty {
                Label("Dashed line marks a medication change", systemImage: "pill.fill")
                    .font(.caption2)
                    .foregroundStyle(NivaraColor.textSecondary)
            }
        }
        .padding(.top, 2)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(NivaraColor.textSecondary)
        }
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
                    PillLabel(text: reading.sampleType == .fasting ? "F" : "PP")
                    Text("\(reading.glucoseMgDl) mg/dL")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NivaraColor.textPrimary)
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
        }
    }

    /// Meters don't reliably signal fasting vs. post-meal, so the app guesses
    /// — this lets the patient fix the most recent reading if the tag (and
    /// therefore which target range it's judged against) is wrong.
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
