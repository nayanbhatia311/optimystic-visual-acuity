import SwiftUI

struct ResultsView: View {
    @ObservedObject var viewModel: VisualAcuityAppViewModel

    @State private var sharedDocument: SharedResultDocument?
    @State private var exportErrorMessage: String?
    @State private var isMedicalInformationPresented = false

    private var hasBothResults: Bool {
        viewModel.rightEyeResult != nil && viewModel.leftEyeResult != nil
    }

    private var primaryResult: TestResult? {
        viewModel.rightEyeResult ?? viewModel.leftEyeResult ?? viewModel.result
    }

    /// Build the `StoredSession` the PDF exporter (and history) expect.
    private var storedSession: StoredSession? {
        let right = viewModel.rightEyeResult
        let left = viewModel.leftEyeResult
        let single = viewModel.result

        if right == nil && left == nil {
            guard let single else { return nil }
            return StoredSession(
                id: UUID(),
                date: single.date,
                patientID: single.patientID,
                rightEye: single.eyeSelection == .left ? nil : single,
                leftEye: single.eyeSelection == .left ? single : nil
            )
        }

        let sessionDate = right?.date ?? left?.date ?? .now
        let patientID = right?.patientID ?? left?.patientID ?? ""

        return StoredSession(
            id: UUID(),
            date: sessionDate,
            patientID: patientID,
            rightEye: right,
            leftEye: left
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if hasBothResults,
                   let right = viewModel.rightEyeResult,
                   let left = viewModel.leftEyeResult {
                    bothEyesList(right: right, left: left)
                } else if let result = primaryResult {
                    singleEyeList(for: result)
                } else {
                    ContentUnavailableView("No Results", systemImage: "doc.text.magnifyingglass")
                }
            }
            .navigationTitle("Results")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { viewModel.resetToSetup() }
                }
            }
        }
        .sheet(item: $sharedDocument) { document in
            ShareSheet(activityItems: [document.url])
        }
        .sheet(isPresented: $isMedicalInformationPresented) {
            MedicalInformationView()
        }
        .alert("Export Failed", isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportErrorMessage ?? "Unable to create the PDF report.")
        }
    }

    @ViewBuilder
    private func bothEyesList(right: TestResult, left: TestResult) -> some View {
        List {
            Section {
                EyeResultRow(label: "Right", result: right)
                EyeResultRow(label: "Left", result: left)
            }

            Section {
                Button {
                    exportReport()
                } label: {
                    Label("Export PDF", systemImage: "square.and.arrow.up")
                }
            }

            scoringAndSourcesSection
        }
    }

    @ViewBuilder
    private func singleEyeList(for result: TestResult) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(result.snellenText)
                        .font(.title2.weight(.semibold))
                    Text(result.eyeSelection.rawValue + " eye")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                LabeledContent("Distance", value: String(format: "%.2f m", result.viewingDistanceMeters))
                LabeledContent("Optotype", value: result.optotypeFamily.rawValue)
                LabeledContent("Correct", value: "\(result.correctCount)")
                LabeledContent("Wrong", value: "\(result.wrongCount)")
            }

            Section {
                Button {
                    exportReport()
                } label: {
                    Label("Export PDF", systemImage: "square.and.arrow.up")
                }
            }

            scoringAndSourcesSection
        }
    }

    private var scoringAndSourcesSection: some View {
        Section("About this score") {
            Text("The score is the smallest line with at least 3 of 5 responses marked Correct.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                isMedicalInformationPresented = true
            } label: {
                Label("Scoring method & medical sources", systemImage: "book.closed")
            }
        }
    }

    private func exportReport() {
        guard let session = storedSession else {
            exportErrorMessage = "No results to export."
            return
        }

        do {
            let url = try ResultPDFExporter.makeTemporaryFile(session: session)
            sharedDocument = SharedResultDocument(url: url)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }
}

private struct EyeResultRow: View {
    let label: String
    let result: TestResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label + " eye")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(result.snellenText)
                .font(.title3.weight(.semibold))
        }
        .padding(.vertical, 2)
    }
}

private struct SharedResultDocument: Identifiable {
    let url: URL
    var id: String { url.path }
}

@MainActor
struct ResultsView_Previews: PreviewProvider {
    static var previews: some View {
        let engine = VisualAcuityTestEngine()
        let connectivityManager = WatchConnectivityManager(activateSession: false)
        let peerConnectivityManager = PeerConnectivityManager()
        let viewModel = VisualAcuityAppViewModel(
            engine: engine,
            connectivityManager: connectivityManager,
            peerConnectivityManager: peerConnectivityManager
        )
        engine.start(configuration: .mvp)
        engine.endTest()

        return ResultsView(viewModel: viewModel)
    }
}
