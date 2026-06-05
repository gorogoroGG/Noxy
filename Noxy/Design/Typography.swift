import SwiftUI

// MARK: - Typography
// Apple Dynamic Type に対応。システム設定の文字サイズに自動で追従する。

extension Font {
    static let displayLarge  = Font.largeTitle.weight(.bold)
    static let displayMedium = Font.title.weight(.bold)
    static let titleLarge    = Font.title2.weight(.semibold)
    static let titleMedium   = Font.headline.weight(.semibold)
    static let bodyRegular   = Font.body
    static let bodySmall     = Font.subheadline
    static let captionRegular = Font.footnote
    static let captionSmall  = Font.caption2.weight(.medium)
    static let mono          = Font.system(.caption, design: .monospaced)
}

// MARK: - Minimum Scale Factor Helpers

extension View {
    /// Dynamic Type で極端に大きくなった時に崩れないよう、最小 0.8 倍まで縮小を許可する
    func scalableLineLimit(_ count: Int) -> some View {
        self
            .lineLimit(count)
            .minimumScaleFactor(0.8)
    }
}
