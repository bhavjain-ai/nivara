import SwiftUI

/// Shared chrome for each top-level onboarding step: a back button + step
/// progress bar, a title, scrollable content, and a pinned footer (typically
/// a primary action button) — keeps every step visually consistent without
/// each view re-deriving the same layout.
struct OnboardingScaffold<Content: View, Footer: View>: View {
    let title: String
    let subtitle: String?
    let step: Int
    let totalSteps: Int
    let onBack: (() -> Void)?
    let content: Content
    let footer: Footer

    init(
        title: String,
        subtitle: String? = nil,
        step: Int,
        totalSteps: Int,
        onBack: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.subtitle = subtitle
        self.step = step
        self.totalSteps = totalSteps
        self.onBack = onBack
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    if let onBack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(NivaraColor.forestGreen)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    Text("\(step) of \(totalSteps)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NivaraColor.textSecondary)
                }

                ProgressView(value: Double(step), total: Double(totalSteps))
                    .tint(NivaraColor.forestGreen)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(NivaraColor.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(NivaraColor.textSecondary)
                    }
                }
            }
            .padding()
            .padding(.top, 8)

            ScrollView {
                content
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }

            footer
                .padding()
        }
        .background(NivaraColor.cream)
    }
}

/// The single primary CTA button style used throughout onboarding.
struct OnboardingPrimaryButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(enabled ? NivaraColor.forestGreen : NivaraColor.border)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
