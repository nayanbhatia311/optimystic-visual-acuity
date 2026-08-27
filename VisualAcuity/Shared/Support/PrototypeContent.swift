import Foundation

struct GuidanceSection: Identifiable, Equatable {
    let title: String
    let items: [String]

    var id: String { title }
}

struct MedicalSource: Identifiable, Equatable {
    let title: String
    let detail: String
    let url: URL

    var id: String { url.absoluteString }
}

enum PrototypeContent {
    static let videoURL = URL(string: "https://youtu.be/3pCCZJbQK30")!

    static let prototypeDisclaimer =
        "This app is a prototype visual acuity screening aid. It does not replace a full eye examination or professional clinical judgment."

    static let professionalFollowUp =
        "Always take professional advice from an optician, ophthalmologist, optometrist, or other qualified eye specialist, especially for reduced vision, worsening vision, pain, or sudden changes."

    static let resultsFooter =
        "Prototype only. Share these results as a conversation starter, not as a diagnosis."

    static let scoreExplanation =
        "The app presents five optotypes on each line, starting at 20/200 (6/60) and progressing toward 20/20 (6/6). A line passes when the examiner records at least 3 of 5 responses as Correct. Wrong and Next responses do not count as correct. The reported screening score is the smallest line passed; testing stops at the first failed line or when the examiner taps End."

    static let snellenExplanation =
        "A result such as 20/40 (6/12) is Snellen notation, not a percentage or diagnosis. It means the tested eye identified at 20 feet (6 metres) an optotype size conventionally identifiable by standard vision at 40 feet (12 metres). Optimystic scales the optotype for the measured on-screen viewing distance and includes that distance with every result."

    static let sourceCitationText =
        "Sources: Bennett et al., The Assessment of Visual Function and Functional Vision, PMCID: PMC6761988; Ambadekar et al., Measuring Visual Acuity using Periscope and Android Application, DOI: 10.2139/ssrn.3867093."

    static let medicalSources: [MedicalSource] = [
        MedicalSource(
            title: "The Assessment of Visual Function and Functional Vision",
            detail: "Peer-reviewed overview of Snellen notation and the 5-arc-minute optotype standard (PMCID: PMC6761988).",
            url: URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC6761988/")!
        ),
        MedicalSource(
            title: "Measuring Visual Acuity using Periscope and Android Application",
            detail: "The paper underlying Optimystic's distance-based optotype sizing method (DOI: 10.2139/ssrn.3867093).",
            url: URL(string: "https://doi.org/10.2139/ssrn.3867093")!
        ),
        MedicalSource(
            title: "How to measure distance visual acuity",
            detail: "Practical visual-acuity testing guidance from Community Eye Health (PMCID: PMC4069781).",
            url: URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC4069781/")!
        )
    ]

    static let guideSections: [GuidanceSection] = [
        GuidanceSection(
            title: "Before You Start",
            items: [
                "Measure the patient-to-screen distance first and enter that value before starting the test.",
                "Use good room lighting, keep the screen bright, and reduce glare or reflections on the display.",
                "If the patient normally uses distance glasses or contact lenses, note whether this test is with or without that correction."
            ]
        ),
        GuidanceSection(
            title: "Test One Eye At A Time",
            items: [
                "To test the right eye, gently cover the left eye. To test the left eye, gently cover the right eye.",
                "Do not press on the covered eye.",
                "Ask the patient to keep looking at the optotype on the display instead of the examiner."
            ]
        ),
        GuidanceSection(
            title: "During The Test",
            items: [
                "Ask the patient to say the letter or point in the direction they see.",
                "Use Correct, Wrong, Repeat, or Next to score each response.",
                "Stop the test and seek professional care if the patient reports pain, sudden blur, or a major difference between eyes."
            ]
        ),
        GuidanceSection(
            title: "Device Pairing",
            items: [
                "For two-device mode, open Optimystic on both devices and keep them nearby and unlocked while pairing.",
                "When a Mac is involved, Apple Watch control relies on an iPhone or iPad relay because the watch does not pair directly with the Mac build.",
                "If pairing stalls, restart pairing from the setup screen on the controller and reopen the patient display."
            ]
        )
    ]
}
