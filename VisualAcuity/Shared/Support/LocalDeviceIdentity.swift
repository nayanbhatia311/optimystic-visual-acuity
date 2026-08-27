import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

enum LocalDeviceIdentity {
    static var displayName: String {
        String(rawDisplayName.prefix(60))
    }

    static var rawDisplayName: String {
        #if targetEnvironment(macCatalyst)
        return sanitizedHostName
        #elseif canImport(UIKit)
        return UIDevice.current.name
        #elseif canImport(AppKit)
        return Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        #else
        return ProcessInfo.processInfo.hostName
        #endif
    }

    private static var sanitizedHostName: String {
        let hostName = ProcessInfo.processInfo.hostName
            .replacingOccurrences(of: ".local", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return hostName.isEmpty ? "This Mac" : hostName
    }
}
