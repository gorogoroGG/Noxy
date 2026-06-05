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

    private init(light lightUIColor: UIColor, dark darkUIColor: UIColor) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkUIColor : lightUIColor
        })
    }

    private init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    // Backgrounds
    static let bgPrimary  = Color(light: 0xF2F2F7, dark: 0x000000)
    static let bgSurface  = Color(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let bgElevated = Color(light: 0xF2F2F7, dark: 0x2C2C2E)

    // Accents – メインはインディゴで統一、その他はステータス・補助用に限定使用
    static let accentIndigo = Color(hex: 0x5856D6)
    static let accentPurple = Color(hex: 0xAF52DE)
    static let accentPink   = Color(hex: 0xFF2D55)
    static let accentRed    = Color(hex: 0xFF3B30)
    static let accentGreen  = Color(hex: 0x34C759)
    static let accentOrange = Color(hex: 0xFF9500)

    // Text
    static let textPrimary   = Color(light: 0x000000, dark: 0xFFFFFF)
    static let textSecondary = Color(
        light: UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.60),
        dark:  UIColor(red: 0.922, green: 0.922, blue: 0.961, alpha: 0.70)
    )
    static let textTertiary  = Color(
        light: UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.35),
        dark:  UIColor(red: 0.922, green: 0.922, blue: 0.961, alpha: 0.50)
    )

    // Borders
    static let border       = Color(light: 0xE5E5EA, dark: 0x38383A)
    static let borderStrong = Color(light: 0xC7C7CC, dark: 0x48484A)
}
