import Foundation
import SwiftUI
import AppKit

@MainActor
final class ScreenshotManager {
    static let shared = ScreenshotManager()

    private init() {}

    func captureView(_ view: NSView) -> String? {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)

        guard let cgImage = rep.cgImage else { return nil }
        let image = NSImage(cgImage: cgImage, size: view.bounds.size)

        let exportsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Dev/Noxy/NoxyEditor/exports/screenshots")
        try? FileManager.default.createDirectory(at: exportsDir, withIntermediateDirectories: true)

        let filename = "screenshot_\(Date().timeIntervalSince1970).png"
        let fileURL = exportsDir.appendingPathComponent(filename)

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return nil }

        try? pngData.write(to: fileURL)
        return fileURL.path
    }
}
