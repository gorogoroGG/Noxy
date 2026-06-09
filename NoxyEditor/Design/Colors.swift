import SwiftUI

extension Color {
    static let bgPrimary  = Color(nsColor: NSColor(hex: 0x000000))
    static let bgSurface  = Color(nsColor: NSColor(hex: 0x1C1C1E))
    static let bgElevated = Color(nsColor: NSColor(hex: 0x2C2C2E))

    static let accentIndigo = Color(nsColor: NSColor(hex: 0x5856D6))
    static let accentPurple = Color(nsColor: NSColor(hex: 0xAF52DE))
    static let accentPink   = Color(nsColor: NSColor(hex: 0xFF2D55))
    static let accentRed    = Color(nsColor: NSColor(hex: 0xFF3B30))
    static let accentGreen  = Color(nsColor: NSColor(hex: 0x34C759))
    static let accentOrange = Color(nsColor: NSColor(hex: 0xFF9500))

    static let textPrimary   = Color(nsColor: NSColor(hex: 0xFFFFFF))
    static let textSecondary = Color(nsColor: NSColor(calibratedWhite: 0.922, alpha: 0.70))
    static let textTertiary  = Color(nsColor: NSColor(calibratedWhite: 0.922, alpha: 0.50))

    static let border       = Color(nsColor: NSColor(hex: 0x38383A))
    static let borderStrong = Color(nsColor: NSColor(hex: 0x48484A))
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >>  8) & 0xFF) / 255,
            blue:  CGFloat( hex        & 0xFF) / 255,
            alpha: 1
        )
    }
}
