import SwiftUI

struct HbA1cHistoryListView: View {
    @EnvironmentObject private var viewModel: PatientViewModel

    var body: some View {
        List {
            ForEach(Array(viewModel.vitals.hba1cReadings.reversed())) { reading in
                HStack {
                    Text(NivaraDate.short.string(from: reading.date))
                        .font(.subheadline)
                        .foregroundStyle(NivaraColor.textSecondary)
                    Spacer()
                    Text(String(format: "%.1f%%", reading.value))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NivaraColor.textPrimary)
                }
                .listRowBackground(NivaraColor.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(NivaraColor.cream)
        .navigationTitle("HbA1c")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HbA1cHistoryListView().environmentObject(PatientViewModel())
    }
}
