import SwiftUI

// #5: Discord OAuth 実装済みのためバナーは不要 → このファイルを残しつつ非表示化

struct MockBanner: ViewModifier {
    var isVisible: Bool = false // デフォルト非表示

    func body(content: Content) -> some View {
        content // バナーを表示しない
    }
}

extension View {
    func mockBanner(isVisible: Bool = false) -> some View {
        modifier(MockBanner(isVisible: isVisible))
    }
}
