import SwiftUI

/// App root: a persistent left-side icon rail (mirroring the physician web
/// dashboard's Sidebar) plus a content area on the right showing whichever
/// tab is selected.
struct RootView: View {
    @EnvironmentObject private var viewModel: PatientViewModel
    @State private var selectedTab: AppTab = .home

    var body: some View {
        // Deliberately NOT ignoring safe area here at the container level —
        // that was confusing the nested NavigationStack's own top-safe-area
        // math, causing page titles to render behind the status bar (and,
        // seemingly, occasional black bars around content during
        // transitions). The rail opts itself into a full-height bleed
        // individually below; the content pane behaves like an ordinary,
        // safe-area-respecting NavigationStack.
        HStack(spacing: 0) {
            sideRail
            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    if let toast = viewModel.toast {
                        ToastBanner(message: toast)
                            .padding(.bottom, 24)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: viewModel.toast)
        }
        .background(NivaraColor.cream)
        // The whole palette (cream/forest green) is designed as a light
        // theme only. Without this, system-drawn chrome (nav bar titles,
        // default label colors) still follows the device's Dark Mode
        // setting and renders light-on-light against our fixed colors —
        // e.g. a white system title over a cream card.
        .preferredColorScheme(.light)
        .sheet(item: mealTimingConfirmationBinding) { reading in
            MealTimingConfirmationView(reading: reading)
        }
    }

    /// `pendingMealTimingConfirmation` is intentionally read-only outside
    /// PatientViewModel; `.sheet(item:)` needs a two-way Binding, so this
    /// adapts it — a manual dismissal (swipe-down) routes back through
    /// `dismissMealTimingConfirmation()` just like the sheet's own buttons.
    private var mealTimingConfirmationBinding: Binding<GlucoseReading?> {
        Binding(
            get: { viewModel.pendingMealTimingConfirmation },
            set: { newValue in
                if newValue == nil { viewModel.dismissMealTimingConfirmation() }
            }
        )
    }

    private var sideRail: some View {
        VStack(spacing: 22) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 22))
                .foregroundStyle(.white)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ForEach(AppTab.allCases) { tab in
                railButton(tab)
            }

            Spacer()
        }
        .padding(.top, 8)
        .frame(width: 84)
        .frame(maxHeight: .infinity)
        .background(NivaraColor.deepGreen.ignoresSafeArea())
    }

    private func railButton(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 19, weight: .medium))
                Text(tab.rawValue)
                    .font(.system(size: 9.5, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? NivaraColor.deepGreen : Color.white.opacity(0.75))
            .frame(width: 68, height: 58)
            .background(isSelected ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var contentArea: some View {
        switch selectedTab {
        case .home:
            HomeView(selectedTab: $selectedTab)
        case .myHealth:
            MyHealthView()
        case .medications:
            MedicationsView()
        case .careTeam:
            CareTeamView()
        case .contactUs:
            ContactUsView()
        }
    }
}

#Preview {
    RootView()
        .environmentObject(PatientViewModel())
        .environmentObject(OnboardingStore())
}
