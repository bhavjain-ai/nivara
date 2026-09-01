import SwiftUI

struct GlucoseHistoryListView: View {
    @EnvironmentObject private var viewModel: PatientViewModel

    var body: some View {
        List {
            ForEach(Array(viewModel.vitals.glucoseReadings.reversed())) { reading in
                HStack {
                    Text(NivaraDate.shortWithTime.string(from: reading.date))
                        .font(.subheadline)
                        .foregroundStyle(NivaraColor.textSecondary)
                    Spacer()
                    Text("\(reading.glucoseMgDl) mg/dL")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NivaraColor.textPrimary)
                    PillLabel(text: reading.sampleType.displayName)
                }
                .listRowBackground(NivaraColor.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(NivaraColor.cream)
        .navigationTitle("Blood Glucose")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        GlucoseHistoryListView().environmentObject(PatientViewModel())
    }
}
