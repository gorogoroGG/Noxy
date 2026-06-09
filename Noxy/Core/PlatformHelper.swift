import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - PlatformHelper
// macOS / iOS / Mac Catalyst 間の差異を吸収するユーティリティ

enum PlatformHelper {
    // MARK: - Open URL

    static func openURL(_ url: URL) {
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #elseif canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }

    // MARK: - Foreground Notification

    static var willEnterForegroundNotification: Notification.Name {
        #if canImport(UIKit)
        UIApplication.willEnterForegroundNotification
        #elseif canImport(AppKit)
        NSApplication.didBecomeActiveNotification
        #endif
    }
}
