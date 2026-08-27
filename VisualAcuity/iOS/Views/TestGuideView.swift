import SwiftUI

struct TestGuideView: View {
    var body: some View {
        List {
            Section {
                Text("Use this helper before each session so the patient understands what will happen and the examiner can set the distance correctly.")
                    .font(.subheadline)

                Link(destination: PrototypeContent.videoURL) {
                    Label("Open Reference Video", systemImage: "play.rectangle")
                }
            }

            ForEach(PrototypeContent.guideSections) { section in
                Section(section.title) {
                    ForEach(Array(section.items.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1).")
                                .foregroundStyle(.secondary)
                            Text(item)
                        }
                        .font(.subheadline)
                    }
                }
            }

            Section("Prototype Notice") {
                Text(PrototypeContent.prototypeDisclaimer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(PrototypeContent.professionalFollowUp)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Test Guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TestGuideView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            TestGuideView()
        }
    }
}
