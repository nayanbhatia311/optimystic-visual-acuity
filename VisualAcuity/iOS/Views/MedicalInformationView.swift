import SwiftUI

struct MedicalInformationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("How the score is calculated") {
                    Text(PrototypeContent.scoreExplanation)
                    Text(PrototypeContent.snellenExplanation)
                }

                Section("Medical sources") {
                    ForEach(PrototypeContent.medicalSources) { source in
                        Link(destination: source.url) {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(source.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Spacer(minLength: 8)
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundStyle(.blue)
                                }

                                Text(source.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }

                Section("Safety notice") {
                    Text(PrototypeContent.prototypeDisclaimer)
                    Text(PrototypeContent.professionalFollowUp)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .navigationTitle("Scoring & Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct MedicalInformationView_Previews: PreviewProvider {
    static var previews: some View {
        MedicalInformationView()
    }
}
