import Foundation

/// One section of a consent document, for display as a heading + body block
/// rather than one long unstructured string.
struct ConsentSection: Identifiable {
    let id = UUID()
    let heading: String?
    let body: String
}

/// Full text of the two consent documents patients review and accept during
/// onboarding — content mirrors Nivara_Patient_Informed_Consent.docx and
/// Nivara_Data_Privacy_Consent.docx. The only departures from the source
/// documents are structural: paper signature-line blocks are replaced by
/// this flow's in-app "I agree" acceptance (see OnboardingConsentView), and
/// the two acknowledgement paragraphs are reworded to refer to accepting in
/// the app rather than signing on paper. Legal substance is unchanged — if
/// this pilot's actual process requires a physician countersignature or a
/// different acceptance record, that still needs to be handled outside this
/// demo app.
enum ConsentDocuments {
    static let informedConsentTitle = "Patient Informed Consent & Service Disclosure"

    static let informedConsentSummary = "Nivara pairs your Bluetooth glucometer with physician oversight — every treatment decision is still made by a licensed physician, alert response is typically 24–48 hours (this is not an emergency service), and participation is voluntary. Fees are described in full below."

    static let informedConsentSections: [ConsentSection] = [
        ConsentSection(
            heading: "1. What This Program Is",
            body: "Nivara Health, Inc. (\"Nivara\"), together with Bangalore Diabetes Centre, provides a remote monitoring service for patients with Type 2 diabetes. The service includes a home monitoring kit (Bluetooth-connected glucometer), a software platform that reviews your readings against established clinical guidelines, and your treating physician, who reviews the readings surfaced to them and makes any decisions about your care.\n\nNivara is a monitoring and care-coordination service. It is not a hospital, an emergency service, or a substitute for your ongoing relationship with your treating physician."
        ),
        ConsentSection(
            heading: "2. What Nivara Does — and Does Not — Do",
            body: "Nivara's software (including any AI-based analysis) reviews your daily readings and highlights patterns that may need a physician's attention. During this pilot, the Nivara team also reviews readings as a backup check and separately notifies your physician of anything significant that is not automatically flagged.\n\nNivara's software does not autonomously diagnose, prescribe or change any medication, or make any clinical decision without explicit physician approval.\n\nEvery decision about your treatment — including any change to your medication — is made by a licensed physician registered to practice in India, either your treating physician or an authorized backup physician.\n\nNivara does not replace your treating physician or your existing clinical relationship. You should continue to see your physician for regular in-person or scheduled care as you normally would."
        ),
        ConsentSection(
            heading: "3. Response Times — This Is Not an Emergency Service",
            body: "When your readings show a pattern that may need attention, the system generates an alert for physician review. Typical review and response time is within 24–48 hours, except for urgent-threshold readings (for example, very low blood sugar), which are flagged for faster review.\n\nNivara's alert system is not designed or intended to detect or respond to a medical emergency in real time. Do not wait for a Nivara alert or a call from the Nivara team if you are experiencing a possible emergency.\n\nIN AN EMERGENCY: If you or a family member experience chest pain, severe shortness of breath, fainting, confusion, signs of stroke, severe hypoglycemia, or any other symptom that feels like an emergency, call 112 or go to the nearest hospital immediately. Do not wait for a response from Nivara."
        ),
        ConsentSection(
            heading: "4. Voluntary Participation",
            body: "Your participation in this program is completely voluntary.\n\nYou may withdraw from the program at any time, for any reason, without giving a reason, and without any effect on your ongoing medical care from your physician.\n\nTo withdraw, contact the Nivara team via WhatsApp or tell your physician directly."
        ),
        ConsentSection(
            heading: "5. Fees",
            body: "All service fees for this program are payable to and collected by Nivara Health. This includes the cost of the monitoring device, test strips, software, and physician oversight. Enrollment works as follows:\n\nDevice deposit. At enrollment you provide a refundable security deposit of ₹1,500 for the monitoring kit (Bluetooth glucometer). This deposit is returned to you in full once you return the device in working condition — whether you cancel during the trial, cancel at a later date, or complete the full pilot. This fee can be waived if you already own the correct device.\n\nMonthly fee. Enrollment costs ₹1,000/month, billed on a recurring basis. This includes your test strips, so there is no separate per-strip charge. At enrollment, you will set up this recurring payment (an \"e-mandate\") with our payment provider. In line with RBI rules for recurring digital payments, you will always receive a notification at least 24 hours before each monthly charge, and you can cancel that charge or your enrollment at any time through that notification or by contacting the Nivara team.\n\nTwo-week full-refund window. For the first 2 weeks after enrollment, you may cancel for any reason and receive a full refund of any monthly fee already charged, in addition to your device deposit, once you return the device in working condition. After this 2-week window, you may still cancel at any time as described in Section 4 (Voluntary Participation), but the fee already charged for the current month is non-refundable."
        ),
        ConsentSection(
            heading: "6. Your Data",
            body: "Nivara collects and uses your health data as part of this program. This is described in the separate Data Use & Privacy Consent, which you review and accept next in this app."
        ),
        ConsentSection(
            heading: "7. Questions",
            body: "If you have any questions about this program before, during, or after enrollment, you can contact Nivara Health via WhatsApp or ask your treating physician directly."
        ),
        ConsentSection(
            heading: "Acknowledgement",
            body: "By accepting below, you confirm that you have read (or had read to you) and understood this document, that your questions have been answered, and that you are voluntarily choosing to enroll in the Nivara Health monitoring program on the terms described above."
        ),
    ]

    static let privacyConsentTitle = "Data Use & Privacy Consent"

    static let privacyConsentSummary = "We collect your readings, identity, medical history, usage, and payment data to run the monitoring service and let your physician and care team see it. We never sell your data, retain it 3 years past enrollment for medical record-keeping, and you can request or correct your data at any time."

    static let privacyConsentSections: [ConsentSection] = [
        ConsentSection(
            heading: "1. What Data We Collect",
            body: "To provide this service, Nivara Health (\"Nivara\", \"we\") collects the following categories of data about you:\n\n• Health readings (blood glucose, HbA1c, device sync timestamps) — for core clinical monitoring and AI triage.\n• Identity & contact (name, age, phone, email, address) — for enrollment, delivery of devices, and communication.\n• Medical history (diagnoses, current medications, allergies, as provided by you or your physician) — to enable safe, guideline-based triage recommendations.\n• Usage data (app/device sync frequency, login activity) — for service quality and engagement tracking.\n• Payment data (fee payment records) — for billing and service administration."
        ),
        ConsentSection(
            heading: "2. How We Use Your Data",
            body: "• To provide the monitoring and triage service — reviewing your readings against clinical guidelines and generating alerts for physician review.\n• To allow your treating physician (and, where authorized, a backup physician) to review your data and make treatment decisions.\n• To coordinate your care — for example, care coordination staff may contact you about scheduling, adherence, or device issues.\n• To operate and improve the Nivara platform, including using aggregated, de-identified data for service-quality analysis.\n• To share a summary of your health trends with a family member, only if you separately opt in."
        ),
        ConsentSection(
            heading: "3. Who Can See Your Data",
            body: "• Your treating physician and any authorized backup physician.\n• Nivara's care coordination and clinical operations staff, on a need-to-know basis.\n• Nivara's technology systems, including any AI/machine-learning components used for triage.\n• Cloud storage/hosting providers who process data on Nivara's behalf under a data processing agreement.\n\nWe do not sell your data to third parties."
        ),
        ConsentSection(
            heading: "4. Family Access",
            body: "You may separately choose to have a family member receive periodic health trend updates. This is optional and set below — you can turn it on or off at any time."
        ),
        ConsentSection(
            heading: "5. Data Security",
            body: "We apply reasonable security safeguards, including encryption and password authentication, to protect your data, consistent with the Information Technology (Reasonable Security Practices and Procedures and Sensitive Personal Data or Information) Rules, 2011 and, as it comes into force, the Digital Personal Data Protection Act, 2023."
        ),
        ConsentSection(
            heading: "6. How Long We Keep Your Data",
            body: "We retain your identified data for as long as you are enrolled in the program and for 3 years afterward for medical record-keeping and legal compliance purposes, unless you request earlier deletion where permitted by law. De-identified data will be retained indefinitely for service-quality analysis and model training."
        ),
        ConsentSection(
            heading: "7. Your Rights",
            body: "• You may ask to see the personal data we hold about you.\n• You may ask us to correct inaccurate data.\n• You may withdraw this consent at any time; this will not affect any care already provided, but will end your participation in the monitoring program."
        ),
        ConsentSection(
            heading: "8. Questions or Concerns",
            body: "For any question about how your data is used, or to exercise any of the rights above, contact the Nivara Health team via WhatsApp."
        ),
        ConsentSection(
            heading: "Acknowledgement",
            body: "By accepting below, you confirm that you have read (or had read to you) and understood this document, including how your data will be collected, used, and shared, and that you consent to the collection and use of your data as described above."
        ),
    ]
}
