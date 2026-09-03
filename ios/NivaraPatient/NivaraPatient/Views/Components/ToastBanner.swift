import SwiftUI

/// A brief, self-dismissing "Reading saved" style confirmation, overlaid at
/// the bottom of the content pane so it's visible regardless of which tab
/// the patient is on when a BLE reading lands.
struct ToastBanner: View {
    let message: ToastMessage

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
            Text(message.text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(NivaraColor.forestGreen)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
    }
}
