import SwiftUI

extension Font {
    static let displayLarge  = Font.system(size: 34, weight: .bold)
    static let displayMedium = Font.system(size: 28, weight: .bold)
    static let titleLarge    = Font.system(size: 22, weight: .semibold)
    static let titleMedium   = Font.system(size: 17, weight: .semibold)
    static let bodyRegular   = Font.system(size: 17, weight: .regular)
    static let bodySmall     = Font.system(size: 15, weight: .regular)
    static let captionRegular = Font.system(size: 13, weight: .regular)
    static let captionSmall  = Font.system(size: 11, weight: .medium)
    static let mono          = Font.system(size: 12, design: .monospaced)
}
