import SwiftUI

struct BPHistoryListView: View {
    @EnvironmentObject private var viewModel: PatientViewModel

    var body: some View {
        List {
            ForEach(Array(viewModel.vitals.bpReadings.reversed())) { reading in
                HStack {
                    Text(NivaraDate.shortWithTime.string(from: reading.date))
                        .font(.subheadline)
                        .foregroundStyle(NivaraColor.textSecondary)
                    Spacer()
                    Text("\(reading.systolic)/\(reading.diastolic) mmHg")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NivaraColor.textPrimary)
                }
                .listRowBackground(NivaraColor.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(NivaraColor.cream)
        .navigationTitle("Blood Pressure")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        BPHistoryListView().environmentObject(PatientViewModel())
    }
}
