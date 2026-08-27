# Optimystic Visual Acuity

Optimystic is a privacy-friendly visual acuity testing app for iPhone, with optional Apple Watch controls and support for pairing two nearby Apple devices over the local network.

The app stores test history locally on the device. It does not require an account, API key, analytics service, or cloud backend.

> **Important:** Optimystic is an educational and screening aid, not a medical device. It does not diagnose eye conditions or replace an examination by a qualified eye-care professional.

## Fastest way to try it

For the easiest zero-install experience, open the [Optimystic MVA web app](https://optimystic-mva.netlify.app/).

To run the native iPhone and Apple Watch app, follow the steps below.

You need a Mac with Xcode 16 or newer.

1. Click **Code → Download ZIP** on GitHub and unzip it, or clone the repository.
2. Open `VisualAcuity.xcodeproj` in Xcode.
3. Select the **VisualAcuity** scheme and an iPhone simulator.
4. Press **Run** (`⌘R`).

No account or configuration is needed for the simulator.

To install on a physical iPhone, choose your Apple ID team under **Signing & Capabilities**. Xcode may ask you to use a unique bundle identifier. A free Apple developer account can run the app on your own device; broader iPhone distribution requires TestFlight or the App Store.

## Using the app

- **Single device:** choose the patient/display role and follow the on-screen setup and calibration guidance.
- **Two devices:** place both devices on the same local network, choose controller on one and patient display on the other, then pair them in the app.
- **Apple Watch:** build and install the included watch app from Xcode to use the watch as a remote.
- **Results:** review locally saved sessions and export a PDF when needed.

For meaningful sizing, follow the in-app calibration guidance and keep the stated viewing distance. Display size, zoom settings, lighting, and viewing distance all affect results.

## Privacy

- Test data and history stay on the device unless the user explicitly exports or shares a result.
- Nearby-device pairing uses the local network; no remote server is configured.
- This repository contains no credentials, provisioning profiles, developer signing identity, personal Xcode workspace data, patient records, or private working documents.

Run `./scripts/audit_public_release.sh` before publishing. The same isolation check runs automatically in GitHub Actions and rejects common credentials, signing files, Xcode user data, build output, local user paths, private documents, and unexpectedly large files.

See [PRIVACY.md](PRIVACY.md) for details.

## Requirements

- Xcode 16+
- iOS 18+
- watchOS 9+ for the optional watch app

## Development

Build from the command line without code signing:

```bash
xcodebuild \
  -project VisualAcuity.xcodeproj \
  -scheme VisualAcuity \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Contributions and bug reports are welcome through GitHub issues and pull requests.

## License

Released under the [MIT License](LICENSE).
