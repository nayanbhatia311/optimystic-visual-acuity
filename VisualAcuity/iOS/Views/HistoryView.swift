import SwiftUI

/// Lists previous completed test sessions from local storage, lets the user
/// re-export any of them as a PDF, or delete entries. Prototype-scoped: no
/// cloud sync, just UserDefaults under the hood.
struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var sessions: [StoredSession] = []
    @State private var sharedDocument: SharedHistoryDocument?
    @State private var exportErrorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Completed tests will appear here.")
                    )
                } else {
                    List {
                        ForEach(sessions) { session in
                            HistoryRow(session: session) {
                                export(session)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                if !sessions.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
            }
        }
        .onAppear(perform: reload)
        .sheet(item: $sharedDocument) { document in
            ShareSheet(activityItems: [document.url])
        }
        .alert(
            "Export Failed",
            isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportErrorMessage ?? "Unable to create the PDF.")
        }
    }

    private func reload() {
        sessions = SessionHistoryStore.shared.load()
    }

    private func delete(at offsets: IndexSet) {
        let targets = offsets.map { sessions[$0] }
        for session in targets {
            SessionHistoryStore.shared.delete(id: session.id)
        }
        reload()
    }

    private func export(_ session: StoredSession) {
        do {
            let url = try ResultPDFExporter.makeTemporaryFile(session: session)
            sharedDocument = SharedHistoryDocument(url: url)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }
}

private struct HistoryRow: View {
    let session: StoredSession
    let onExport: () -> Void

    private var dateString: String {
        DateFormatter.localizedString(from: session.date, dateStyle: .medium, timeStyle: .short)
    }

    private var patientLabel: String {
        session.patientID.isEmpty ? "Anonymous" : session.patientID
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(patientLabel)
                    .font(.headline)
                Text(session.summary)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Text(dateString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onExport) {
                Image(systemName: "square.and.arrow.up")
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Export PDF")
        }
        .padding(.vertical, 4)
    }
}

private struct SharedHistoryDocument: Identifiable {
    let url: URL
    var id: String { url.path }
}

@MainActor
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
