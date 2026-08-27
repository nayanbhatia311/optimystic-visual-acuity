import SwiftUI
#if canImport(MultipeerConnectivity)
import MultipeerConnectivity
#endif

struct SetupView: View {
    @ObservedObject var viewModel: VisualAcuityAppViewModel
    @ObservedObject var connectivityManager: WatchConnectivityManager
    @ObservedObject var peerConnectivityManager: PeerConnectivityManager

    @FocusState private var isDistanceFieldFocused: Bool
    @State private var isHistoryPresented = false
    @State private var isSetupHelpPresented = false
    @State private var isCalibrationPresented = false
    @State private var isMedicalInformationPresented = false

    private var isController: Bool { viewModel.deviceRole == .controller }

    private var modeTitle: String {
        switch viewModel.deviceRole {
        case .standalone: return "One-device test"
        case .controller: return "Controller"
        case .display: return "Display"
        case nil: return "Test setup"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 5) {
                        Text(modeTitle)
                            .font(.title2.weight(.bold))
                        Text("Configure the screening before you begin")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)

                    testSetupCard

                    if isController {
                        patientDisplayCard
                    }

                    appleWatchCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 116)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Optimystic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { navigationToolbar }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomActionBar
            }
            .sheet(isPresented: $isHistoryPresented) {
                HistoryView()
            }
            .sheet(isPresented: $isSetupHelpPresented) {
                SetupHelpView()
            }
            .sheet(isPresented: $isCalibrationPresented) {
                CalibrationView(viewModel: viewModel)
            }
            .sheet(isPresented: $isMedicalInformationPresented) {
                MedicalInformationView()
            }
        }
    }

    private var testSetupCard: some View {
        SetupCard(title: "Test setup", systemImage: "slider.horizontal.3") {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("EYE TO TEST")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)

                    Picker("Eye", selection: $viewModel.selectedEye) {
                        ForEach(EyeSelection.allCases) { eye in
                            Text(eye.rawValue).tag(eye)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .padding(.bottom, 16)

                Divider()

                SetupFieldRow(title: "Patient ID", systemImage: "person.text.rectangle") {
                    TextField("Optional", text: $viewModel.patientID)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.characters)
                }

                Divider()

                SetupFieldRow(title: "Distance", systemImage: "ruler") {
                    HStack(spacing: 5) {
                        TextField("3.00", text: $viewModel.distanceMetersText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .focused($isDistanceFieldFocused)
                            .onSubmit { viewModel.normalizeDistanceInput() }
                            .onChange(of: isDistanceFieldFocused) { _, isFocused in
                                if isFocused {
                                    viewModel.beginEditingDistanceIfNeeded()
                                } else {
                                    viewModel.normalizeDistanceInput()
                                }
                            }
                            .frame(maxWidth: 74)
                        Text("m")
                            .foregroundStyle(.secondary)
                    }
                }

                if let message = viewModel.viewingDistanceValidationMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 10)
                }

                Divider()

                SetupFieldRow(title: "Optotype", systemImage: "eye") {
                    Picker("Optotype", selection: $viewModel.selectedOptotypeFamily) {
                        ForEach(viewModel.availableOptotypeFamilies) { family in
                            Text(family.rawValue).tag(family)
                        }
                    }
                    .labelsHidden()
                }
            }
        }
    }

    private var patientDisplayCard: some View {
        SetupCard(title: "Patient display", systemImage: "display") {
            VStack(spacing: 12) {
                ConnectionRow(
                    peerConnectivityManager: peerConnectivityManager,
                    status: viewModel.deviceStatusSummary
                )

                Button {
                    peerConnectivityManager.refreshConnection()
                } label: {
                    Label(viewModel.connectivityActionTitle, systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.bordered)

                discoveredDisplays
            }
        }
    }

    @ViewBuilder
    private var discoveredDisplays: some View {
        #if canImport(MultipeerConnectivity)
        if !peerConnectivityManager.isConnected,
           !peerConnectivityManager.discoveredPeers.isEmpty {
            ForEach(peerConnectivityManager.discoveredPeers, id: \.self) { peer in
                Button {
                    peerConnectivityManager.connect(to: peer)
                } label: {
                    HStack {
                        Image(systemName: "display")
                        Text(peer.displayName)
                        Spacer()
                        Text("Connect")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        }
        #endif
    }

    private var appleWatchCard: some View {
        SetupCard(title: "Apple Watch", systemImage: "applewatch") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $viewModel.useAppleWatchForScoring) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Score from your Watch")
                            .font(.body.weight(.semibold))
                        Text("Keep the patient-facing screen unobstructed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.blue)

                if viewModel.useAppleWatchForScoring {
                    Divider()

                    HStack(spacing: 9) {
                        Image(systemName: connectivityManager.isReachable ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(connectivityManager.isReachable ? .green : .orange)
                        Text(connectivityManager.connectionStatusText)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.useAppleWatchForScoring)
        }
    }

    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                isHistoryPresented = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .accessibilityLabel("History")
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                isCalibrationPresented = true
            } label: {
                Image(systemName: "ruler")
            }
            .accessibilityLabel("Calibration")

            Button {
                isSetupHelpPresented = true
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .accessibilityLabel("Setup help")

            Menu {
                Button("Scoring & medical sources", systemImage: "cross.case") {
                    isMedicalInformationPresented = true
                }

                Button("Change mode", systemImage: "arrow.triangle.2.circlepath") {
                    viewModel.clearRole()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("More options")
        }

        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") {
                isDistanceFieldFocused = false
            }
        }
    }

    private var bottomActionBar: some View {
        VStack(spacing: 8) {
            Button {
                viewModel.beginTestFlow()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text(viewModel.startButtonTitle)
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(viewModel.canStart ? Color.accentColor : Color.secondary.opacity(0.45))
                )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canStart)

            PrototypeDisclaimerFooter()
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .background(.ultraThinMaterial)
    }
}

private struct SetupCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct SetupFieldRow<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
                .frame(width: 22)

            Text(title)

            Spacer(minLength: 12)

            content
        }
        .frame(minHeight: 48)
    }
}

/// Small always-visible footer reminding the user this is a prototype.
private struct PrototypeDisclaimerFooter: View {
    var body: some View {
        Text("Prototype • Always consult a licensed eye-care professional.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
    }
}

private struct ConnectionRow: View {
    @ObservedObject var peerConnectivityManager: PeerConnectivityManager
    let status: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(peerConnectivityManager.isConnected ? Color.green : Color.orange)
                .frame(width: 9, height: 9)
            Text(status.isEmpty ? "Searching…" : status)
                .font(.subheadline.weight(.medium))
            Spacer()
        }
    }
}

@MainActor
struct SetupView_Previews: PreviewProvider {
    static var previews: some View {
        let connectivityManager = WatchConnectivityManager(activateSession: false)
        let peerConnectivityManager = PeerConnectivityManager()
        let viewModel = VisualAcuityAppViewModel(
            connectivityManager: connectivityManager,
            peerConnectivityManager: peerConnectivityManager
        )

        return SetupView(
            viewModel: viewModel,
            connectivityManager: connectivityManager,
            peerConnectivityManager: peerConnectivityManager
        )
    }
}
