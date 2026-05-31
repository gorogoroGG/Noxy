import SwiftUI

struct MockBanner: ViewModifier {
    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            VStack {
                Spacer()
                HStack(spacing: .spacing8) {
                    Image(systemName: "info.circle.fill")
                        .font(.captionRegular)
                    Text("Discord連携は近日対応 · Mock data")
                        .font(.captionSmall)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, .spacing12)
                .padding(.vertical, .spacing6)
                .background(Color.accentIndigo.opacity(0.9))
                .clipShape(Capsule())
                .padding(.bottom, 90) // above tab bar
            }
            .allowsHitTesting(false)
        }
    }
}

extension View {
    func mockBanner() -> some View {
        modifier(MockBanner())
    }
}
