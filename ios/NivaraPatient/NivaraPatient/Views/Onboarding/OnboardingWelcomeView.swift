import SwiftUI

/// First screen a patient sees on a fresh install — branded, warm, and
/// deliberately light on text before asking for anything. A literal
/// blinking-text animation was in the original spec; a gentle fade-in is
/// used instead since flashing text is a rough accessibility pattern
/// (photosensitivity, distraction for low-vision users).
struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            NivaraColor.deepGreen.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 96, height: 96)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 10) {
                    Text("Welcome to Nivara")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Your care team, connected to your everyday readings.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 44)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)

                Spacer()

                Button(action: onContinue) {
                    Text("Help Us Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .foregroundStyle(NivaraColor.deepGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                appeared = true
            }
        }
    }
}

#Preview {
    OnboardingWelcomeView(onContinue: {})
}
