import SwiftUI

/// The large page title used at the top of every root tab page, in place of
/// the system NavigationStack title — gives every page byte-for-byte
/// identical spacing/styling (the system large title's leading inset didn't
/// line up with our own content padding, which is what made some pages look
/// squeezed against the rail while Home looked fine).
struct PageTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 26, weight: .bold, design: .rounded))
            .foregroundStyle(NivaraColor.textPrimary)
    }
}
