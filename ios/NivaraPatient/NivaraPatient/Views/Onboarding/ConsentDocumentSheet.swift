import SwiftUI

/// The full text of one consent document, presented as a sheet so a patient
/// can read the whole thing (not just the on-screen summary) before agreeing.
/// Calls `onReachedBottom` once an invisible marker after the last section
/// scrolls into view — the signal OnboardingConsentView uses to unlock that
/// document's "I agree" toggle, so agreement isn't possible without at least
/// scrolling all the way through.
struct ConsentDocumentSheet: View {
    let title: String
    let sections: [ConsentSection]
    var onReachedBottom: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            if let heading = section.heading {
                                Text(heading)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(NivaraColor.textPrimary)
                            }
                            Text(section.body)
                                .font(.footnote)
                                .foregroundStyle(NivaraColor.textSecondary)
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .onAppear { onReachedBottom?() }
                }
                .padding()
            }
            .background(NivaraColor.cream)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(NivaraColor.forestGreen)
                }
            }
        }
    }
}

#Preview {
    ConsentDocumentSheet(title: ConsentDocuments.informedConsentTitle, sections: ConsentDocuments.informedConsentSections)
}
