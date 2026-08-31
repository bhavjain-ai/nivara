import SwiftUI

struct RootTabView: View {
    @StateObject private var viewModel = PatientViewModel()

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            VitalsHistoryView()
                .tabItem { Label("History", systemImage: "chart.xyaxis.line") }

            NavigationStack {
                DeviceConnectionView()
            }
            .tabItem { Label("Devices", systemImage: "antenna.radiowaves.left.and.right") }

            MedicationsView()
                .tabItem { Label("Medications", systemImage: "pills.fill") }

            CareTeamView()
                .tabItem { Label("Care Team", systemImage: "person.2.fill") }
        }
        .tint(NivaraColor.navy)
        .environmentObject(viewModel)
    }
}

#Preview {
    RootTabView()
}
