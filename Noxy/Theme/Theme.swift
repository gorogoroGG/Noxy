import SwiftUI

enum Theme {

    // MARK: - Color
    enum Color {
        static let bg             = SwiftUI.Color("thBg")
        static let surface        = SwiftUI.Color("thSurface")
        static let surfaceRaised  = SwiftUI.Color("thSurfaceRaised")
        static let line           = SwiftUI.Color("thLine")
        static let lineStrong     = SwiftUI.Color("thLineStrong")
        static let textPrimary    = SwiftUI.Color("thTextPrimary")
        static let textSecondary  = SwiftUI.Color("thTextSecondary")
        static let textTertiary   = SwiftUI.Color("thTextTertiary")
        static let accent         = SwiftUI.Color("thAccent")
        static let accentInk      = SwiftUI.Color("thAccentInk")
        static let accentDim      = SwiftUI.Color("thAccentDim")
        static let statusOK       = SwiftUI.Color("thStatusOK")
        static let statusWarn     = SwiftUI.Color("thStatusWarn")
        static let statusBad      = SwiftUI.Color("thStatusBad")
    }

    // MARK: - Typography
    enum Font {
        // Display
        static let title2: SwiftUI.Font   = .title2.bold()
        static let title3: SwiftUI.Font   = .title3.bold()
        // Body
        static let body: SwiftUI.Font     = .body
        static let bodyMedium: SwiftUI.Font = .system(size: 15, weight: .medium)
        static let bodySmall: SwiftUI.Font = .system(size: 13, weight: .regular)
        static let callout: SwiftUI.Font  = .callout
        // Supporting
        static let caption: SwiftUI.Font  = .caption        // 12pt
        static let caption2: SwiftUI.Font = .caption2       // 11pt
        // Section label
        static let sectionLabel: SwiftUI.Font = .system(size: 11, weight: .semibold)
        // Monospaced data values
        static let mono: SwiftUI.Font     = .system(size: 13, weight: .regular, design: .monospaced)
        static let monoCap: SwiftUI.Font  = .system(size: 11, weight: .regular, design: .monospaced)
    }

    // MARK: - Radius
    enum Radius {
        static let card: CGFloat   = 14
        static let button: CGFloat = 10
        static let chip: CGFloat   = 10
    }

    // MARK: - Spacing (8pt grid)
    enum Spacing {
        static let xs: CGFloat  = 8
        static let sm: CGFloat  = 12
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 20
        static let xl: CGFloat  = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Section label letter-spacing helper
    static let sectionLabelTracking: CGFloat = 0.14 * 11

    // MARK: - Noxy Design Language Typography
    // フォントファイル未インストール時はシステムフォントでフォールバック
    enum NoxyFont {
        static let heading: SwiftUI.Font = .custom("Manrope", size: 16).weight(.bold)
        static let headingLarge: SwiftUI.Font = .custom("Manrope", size: 20).weight(.bold)

        static let body: SwiftUI.Font = .custom("Noto Sans JP", size: 13)
        static let bodyMedium: SwiftUI.Font = .custom("Noto Sans JP", size: 13).weight(.medium)
        static let bodySemibold: SwiftUI.Font = .custom("Noto Sans JP", size: 13).weight(.semibold)
        static let bodyBold: SwiftUI.Font = .custom("Noto Sans JP", size: 13).weight(.bold)

        static let caption: SwiftUI.Font = .custom("Noto Sans JP", size: 11)
        static let captionMedium: SwiftUI.Font = .custom("Noto Sans JP", size: 11).weight(.medium)

        static let sectionLabel: SwiftUI.Font = .custom("Noto Sans JP", size: 10.5).weight(.semibold)

        static let monoData: SwiftUI.Font = .custom("IBM Plex Mono", size: 11)
        static let monoDataSmall: SwiftUI.Font = .custom("IBM Plex Mono", size: 9.5)
    }
}
