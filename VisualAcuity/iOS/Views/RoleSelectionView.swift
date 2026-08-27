import SwiftUI

struct RoleSelectionView: View {
    @ObservedObject var viewModel: VisualAcuityAppViewModel
    @State private var isSetupHelpPresented = false
    @State private var isMedicalInformationPresented = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                BrandLogo(size: 128)

                Text("Optimystic")
                    .font(.largeTitle.weight(.semibold))

                Text("EYE CARE FOR YOU")
                    .font(.footnote.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 14) {
                RoleCard(
                    icon: "iphone",
                    title: "One Device",
                    subtitle: "Show and score on this device",
                    action: { viewModel.chooseRole(.standalone) }
                )

                RoleCard(
                    icon: "dot.radiowaves.left.and.right",
                    title: "Controller",
                    subtitle: "Score here, show on another",
                    action: { viewModel.chooseRole(.controller) }
                )

                RoleCard(
                    icon: "display",
                    title: "Display",
                    subtitle: "Show optotypes from a controller",
                    action: { viewModel.chooseRole(.display) }
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                isSetupHelpPresented = true
            } label: {
                Label("Help me set this up", systemImage: "questionmark.circle")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)

            Button("Scoring & medical sources") {
                isMedicalInformationPresented = true
            }
            .font(.footnote.weight(.semibold))
            .padding(.top, 6)
            .padding(.bottom, 14)

            // Non-intrusive prototype disclaimer. Kept intentionally small so
            // it doesn't dominate the UI but is always visible on first-launch.
            Text("Prototype for research only. Always consult a licensed eye-care professional for a real exam.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .sheet(isPresented: $isSetupHelpPresented) {
            SetupHelpView()
        }
        .sheet(isPresented: $isMedicalInformationPresented) {
            MedicalInformationView()
        }
    }
}

/// Draws the Optimystic logo from the asset catalog. Falls back to an SF
/// Symbol if the asset hasn't been dropped in yet so the UI doesn't go blank.
private struct BrandLogo: View {
    let size: CGFloat

    var body: some View {
        if let uiImage = UIImage(named: "LogoMark") {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .accessibilityLabel("Optimystic")
        } else {
            Image(systemName: "eye")
                .font(.system(size: size * 0.7, weight: .light))
                .frame(width: size, height: size)
                .foregroundStyle(.primary)
                .accessibilityLabel("Optimystic")
        }
    }
}

private struct RoleCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 36)
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

struct SetupHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Choose the right mode") {
                    SetupHelpStep(
                        icon: "iphone",
                        title: "One Device",
                        detail: "Use this when the examiner and patient will share the same iPhone or iPad."
                    )
                    SetupHelpStep(
                        icon: "dot.radiowaves.left.and.right",
                        title: "Controller",
                        detail: "Use this on the examiner device. It scores responses and sends optotypes to one selected display."
                    )
                    SetupHelpStep(
                        icon: "display",
                        title: "Display",
                        detail: "Use this on the patient-facing device. Leave it open on the Ready screen."
                    )
                }

                Section("Connect two devices") {
                    SetupHelpStep(
                        icon: "wifi",
                        title: "Put both devices nearby",
                        detail: "Use the same Wi-Fi network when possible, keep Bluetooth on, and allow Local Network access when iOS asks."
                    )
                    SetupHelpStep(
                        icon: "1.circle",
                        title: "Open Display first",
                        detail: "On the patient-facing device, choose Display and wait on the black Ready screen."
                    )
                    SetupHelpStep(
                        icon: "2.circle",
                        title: "Open Controller second",
                        detail: "On the examiner device, choose Controller. If more than one display appears, tap only the intended display."
                    )
                }

                Section("Run the test") {
                    SetupHelpStep(
                        icon: "ruler",
                        title: "Enter the viewing distance",
                        detail: "Measure from the patient to the display. The app limits the distance if the selected display cannot render the smallest line safely."
                    )
                    SetupHelpStep(
                        icon: "applewatch",
                        title: "Use Apple Watch only if needed",
                        detail: "Turn on Watch scoring from the controller setup screen after the iPhone and Watch are paired."
                    )
                    SetupHelpStep(
                        icon: "play.fill",
                        title: "Start from the controller",
                        detail: "The display should only show the patient prompt and optotypes. Scoring stays on the controller or Watch."
                    )
                }

                Section("If connection fails") {
                    SetupHelpStep(
                        icon: "arrow.clockwise",
                        title: "Scan again",
                        detail: "Use Scan Again or Reconnect on the controller. If that does not work, change roles on both devices and repeat the setup."
                    )
                    SetupHelpStep(
                        icon: "lock.shield",
                        title: "Check permissions",
                        detail: "In Settings, make sure Optimystic has Local Network permission on both devices."
                    )
                }
            }
            .navigationTitle("Setup Help")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct SetupHelpStep: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
struct RoleSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        RoleSelectionView(
            viewModel: VisualAcuityAppViewModel(
                connectivityManager: WatchConnectivityManager(activateSession: false),
                peerConnectivityManager: PeerConnectivityManager()
            )
        )
    }
}
