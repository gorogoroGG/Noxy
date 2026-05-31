import SwiftUI

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red:   CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >>  8) & 0xFF) / 255,
            blue:  CGFloat( hex        & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    private init(light lightHex: UInt32, dark darkHex: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: darkHex)
                : UIColor(hex: lightHex)
        })
    }

    private init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    // Backgrounds
    static let bgPrimary  = Color(light: 0xF2F3F5, dark: 0x0A0B14)
    static let bgSurface  = Color(light: 0xFFFFFF, dark: 0x1C1D2E)
    static let bgElevated = Color(light: 0xF5F6F8, dark: 0x25263A)

    // Accents
    static let accentIndigo = Color(hex: 0x5865F2)
    static let accentPink   = Color(hex: 0xEC4899)
    static let accentPurple = Color(hex: 0x7C3AED)
    static let accentGreen  = Color(hex: 0x23A55A)
    static let accentOrange = Color(hex: 0xF59E0B)

    // Text
    static let textPrimary   = Color(light: 0x060607, dark: 0xF2F3F5)
    static let textSecondary = Color(light: 0x4E5058, dark: 0xB5BAC1)
    static let textTertiary  = Color(light: 0x80848E, dark: 0x80848E)

    // Borders
    static let border       = Color(light: 0xE3E5E8, dark: 0x3F4147)
    static let borderStrong = Color(light: 0xC4C9D0, dark: 0x6D6F78)
}
