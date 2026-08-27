import Foundation
import CoreGraphics

#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct DisplayMetrics: Equatable {
    let pixelsPerInch: CGFloat
    let pointsPerMillimeter: CGFloat
    let minimumScreenDimensionMillimeters: Double
    let sourceDescription: String
    let displayScale: CGFloat
    let screenSizePoints: CGSize
    let nativeSizePixels: CGSize
    let displayIdentifier: String?

    init(
        pixelsPerInch: CGFloat,
        pointsPerMillimeter: CGFloat,
        minimumScreenDimensionMillimeters: Double,
        sourceDescription: String,
        displayScale: CGFloat = 1,
        screenSizePoints: CGSize = .zero,
        nativeSizePixels: CGSize = .zero,
        displayIdentifier: String? = nil
    ) {
        self.pixelsPerInch = pixelsPerInch
        self.pointsPerMillimeter = pointsPerMillimeter
        self.minimumScreenDimensionMillimeters = minimumScreenDimensionMillimeters
        self.sourceDescription = sourceDescription
        self.displayScale = displayScale
        self.screenSizePoints = screenSizePoints
        self.nativeSizePixels = nativeSizePixels
        self.displayIdentifier = displayIdentifier
    }

    var isUsingFallbackPixelsPerInch: Bool {
        sourceDescription.contains("fallback") || sourceDescription == "generic"
    }

    var pixelsPerInchSourceLabel: String {
        switch sourceDescription {
        case "exact":
            return "Exact PPI catalog match"
        case "fallback":
            return "Fallback PPI estimate"
        case "mac-window-screen", "mac-display", "mac-appkit":
            return "Measured display size"
        case "mac-window-screen-ambiguous":
            return "Measured display size (ambiguous match)"
        case "mac-fallback":
            return "Mac fallback estimate"
        default:
            return sourceDescription.capitalized
        }
    }

    var verificationReadout: String {
        let size = formattedSize(nativeSizePixels, suffix: "px") ?? formattedSize(screenSizePoints, suffix: "pt") ?? "size unavailable"
        let identifier = displayIdentifier.map { " \($0)" } ?? ""
        return "\(pixelsPerInchSourceLabel)\(identifier) - \(size) @ \(Self.formatted(displayScale, decimals: 1))x"
    }

    static func current() -> DisplayMetrics {
        #if os(iOS) || targetEnvironment(macCatalyst)
        return currentForUIKit(screen: .main, device: .current)
        #elseif os(macOS)
        return currentForAppKit()
        #else
        let fallbackPPI: CGFloat = 160
        let pointsPerMillimeter = fallbackPPI / 25.4
        return DisplayMetrics(
            pixelsPerInch: fallbackPPI,
            pointsPerMillimeter: pointsPerMillimeter,
            minimumScreenDimensionMillimeters: 100,
            sourceDescription: "generic"
        )
        #endif
    }

    #if os(iOS) || targetEnvironment(macCatalyst)
    static func current(for screen: UIScreen?) -> DisplayMetrics {
        currentForUIKit(screen: screen ?? .main, device: .current)
    }

    private static func currentForUIKit(screen: UIScreen, device: UIDevice) -> DisplayMetrics {
        #if targetEnvironment(macCatalyst)
        if let catalystMetrics = catalystDisplayMetrics(screen: screen) {
            return catalystMetrics
        }
        #endif

        let displayScale = max(screen.scale, 1)
        let resolutionKey = ResolutionKey(size: screen.nativeBounds.size)
        let pixelsPerInch: CGFloat
        let sourceDescription: String

        if let exactPixelsPerInch = exactPixelsPerInch(for: resolutionKey) {
            pixelsPerInch = exactPixelsPerInch
            sourceDescription = "exact"
        } else {
            pixelsPerInch = fallbackPixelsPerInch(for: device.userInterfaceIdiom)
            sourceDescription = "fallback"
        }

        let pointsPerMillimeter = (pixelsPerInch / 25.4) / displayScale
        let minimumScreenDimensionMillimeters = Double(min(screen.bounds.width, screen.bounds.height) / pointsPerMillimeter)

        return DisplayMetrics(
            pixelsPerInch: pixelsPerInch,
            pointsPerMillimeter: pointsPerMillimeter,
            minimumScreenDimensionMillimeters: minimumScreenDimensionMillimeters,
            sourceDescription: sourceDescription,
            displayScale: displayScale,
            screenSizePoints: screen.bounds.size,
            nativeSizePixels: screen.nativeBounds.size
        )
    }

    #if targetEnvironment(macCatalyst)
    private static func catalystDisplayMetrics(screen: UIScreen) -> DisplayMetrics? {
        guard let displayMatch = catalystDisplayMatch(matching: screen) else {
            return nil
        }

        let displayID = displayMatch.displayID
        let physicalSizeMillimeters = CGDisplayScreenSize(displayID)
        guard physicalSizeMillimeters.width > 0, physicalSizeMillimeters.height > 0 else {
            return nil
        }

        let minimumPoints = min(screen.bounds.width, screen.bounds.height)
        let minimumMillimeters = min(physicalSizeMillimeters.width, physicalSizeMillimeters.height)
        let pointsPerMillimeter = minimumPoints / minimumMillimeters
        let pixelsPerInch = pointsPerMillimeter * screen.scale * 25.4

        return DisplayMetrics(
            pixelsPerInch: pixelsPerInch,
            pointsPerMillimeter: pointsPerMillimeter,
            minimumScreenDimensionMillimeters: Double(minimumMillimeters),
            sourceDescription: displayMatch.isAmbiguous ? "mac-window-screen-ambiguous" : "mac-window-screen",
            displayScale: screen.scale,
            screenSizePoints: screen.bounds.size,
            nativeSizePixels: screen.nativeBounds.size,
            displayIdentifier: displayMatch.displayIdentifier
        )
    }

    private static func catalystDisplayMatch(matching screen: UIScreen) -> CatalystDisplayMatch? {
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else {
            return nil
        }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetOnlineDisplayList(displayCount, &displays, &displayCount) == .success else {
            return nil
        }

        let nativePixelSize = ResolutionKey(size: screen.nativeBounds.size)
        let scaledBoundsPixelSize = ResolutionKey(
            size: CGSize(
                width: screen.bounds.width * screen.scale,
                height: screen.bounds.height * screen.scale
            )
        )

        let candidates = displays.prefix(Int(displayCount)).filter { displayID in
            let displaySize = ResolutionKey(
                size: CGSize(
                    width: CGFloat(CGDisplayPixelsWide(displayID)),
                    height: CGFloat(CGDisplayPixelsHigh(displayID))
                )
            )
            return displaySize == nativePixelSize || displaySize == scaledBoundsPixelSize
        }

        if candidates.count == 1 {
            return CatalystDisplayMatch(displayID: candidates[0], matchingDisplayCount: candidates.count)
        }

        return candidates.first.map {
            CatalystDisplayMatch(displayID: $0, matchingDisplayCount: candidates.count)
        }
    }
    #endif

    private static func exactPixelsPerInch(for resolutionKey: ResolutionKey) -> CGFloat? {
        switch resolutionKey {
        case ResolutionKey(width: 640, height: 960),
             ResolutionKey(width: 640, height: 1136),
             ResolutionKey(width: 750, height: 1334),
             ResolutionKey(width: 828, height: 1792):
            return 326
        case ResolutionKey(width: 1125, height: 2436),
             ResolutionKey(width: 1242, height: 2688),
             ResolutionKey(width: 1284, height: 2778):
            return 458
        case ResolutionKey(width: 1170, height: 2532),
             ResolutionKey(width: 1179, height: 2556),
             ResolutionKey(width: 1206, height: 2622),
             ResolutionKey(width: 1260, height: 2736),
             ResolutionKey(width: 1290, height: 2796),
             ResolutionKey(width: 1320, height: 2868):
            return 460
        case ResolutionKey(width: 1080, height: 2340):
            return 476
        case ResolutionKey(width: 1242, height: 2208):
            return 401
        case ResolutionKey(width: 1488, height: 2266):
            return 326
        case ResolutionKey(width: 1536, height: 2048),
             ResolutionKey(width: 1640, height: 2360),
             ResolutionKey(width: 1668, height: 2388),
             ResolutionKey(width: 1668, height: 2420),
             ResolutionKey(width: 2048, height: 2732),
             ResolutionKey(width: 2064, height: 2752):
            return 264
        default:
            return nil
        }
    }

    private static func fallbackPixelsPerInch(for idiom: UIUserInterfaceIdiom) -> CGFloat {
        switch idiom {
        case .pad:
            return 264
        default:
            return 460
        }
    }
    #endif

    #if os(macOS) && !targetEnvironment(macCatalyst)
    private static func currentForAppKit() -> DisplayMetrics {
        guard
            let screen = NSScreen.main,
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else {
            let fallbackPPI: CGFloat = 220
            let pointsPerMillimeter = fallbackPPI / 25.4
            return DisplayMetrics(
                pixelsPerInch: fallbackPPI,
                pointsPerMillimeter: pointsPerMillimeter,
                minimumScreenDimensionMillimeters: 120,
                sourceDescription: "mac-fallback"
            )
        }

        let displayID = CGDirectDisplayID(screenNumber.uint32Value)
        let physicalSizeMillimeters = CGDisplayScreenSize(displayID)
        let minimumPoints = min(screen.frame.width, screen.frame.height)
        let minimumMillimeters = max(1, min(physicalSizeMillimeters.width, physicalSizeMillimeters.height))
        let pointsPerMillimeter = minimumPoints / minimumMillimeters
        let pixelsPerInch = pointsPerMillimeter * screen.backingScaleFactor * 25.4

        return DisplayMetrics(
            pixelsPerInch: pixelsPerInch,
            pointsPerMillimeter: pointsPerMillimeter,
            minimumScreenDimensionMillimeters: Double(minimumMillimeters),
            sourceDescription: "mac-appkit",
            displayScale: screen.backingScaleFactor,
            screenSizePoints: screen.frame.size,
            nativeSizePixels: CGSize(
                width: screen.frame.width * screen.backingScaleFactor,
                height: screen.frame.height * screen.backingScaleFactor
            )
        )
    }
    #endif
}

#if targetEnvironment(macCatalyst)
private struct CatalystDisplayMatch {
    let displayID: CGDirectDisplayID
    let matchingDisplayCount: Int

    var isAmbiguous: Bool {
        matchingDisplayCount > 1
    }

    var displayIdentifier: String {
        if isAmbiguous {
            return "display \(displayID), \(matchingDisplayCount) matching displays"
        }

        return "display \(displayID)"
    }
}
#endif

private extension DisplayMetrics {
    static func formatted(_ value: CGFloat, decimals: Int) -> String {
        String(format: "%.\(decimals)f", Double(value))
    }

    func formattedSize(_ size: CGSize, suffix: String) -> String? {
        guard size.width > 0, size.height > 0 else { return nil }
        return "\(Int(size.width.rounded())) x \(Int(size.height.rounded())) \(suffix)"
    }
}

private struct ResolutionKey: Hashable {
    let width: Int
    let height: Int

    init(size: CGSize) {
        let shortEdge = Int(min(size.width, size.height).rounded())
        let longEdge = Int(max(size.width, size.height).rounded())
        self.width = shortEdge
        self.height = longEdge
    }

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}
