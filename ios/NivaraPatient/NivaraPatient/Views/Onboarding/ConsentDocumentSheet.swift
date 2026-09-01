import SwiftUI

/// The full text of one consent document, presented as a sheet so a patient
/// can read the whole thing (not just the on-screen summary) before agreeing.
struct ConsentDocumentSheet: View {
    let title: String
    let sections: [ConsentSection]

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
