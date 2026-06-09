import SwiftUI

struct iPhoneMockFrame<Content: View>: View {
    let content: Content
    var scale: CGFloat

    init(scale: CGFloat = 0.8, @ViewBuilder content: () -> Content) {
        self.scale = scale
        self.content = content()
    }

    private var frameColor: Color { Color(nsColor: NSColor(hex: 0x1C1C1C)) }
    private var frameEdge: Color  { Color(nsColor: NSColor(hex: 0x3A3A3A)) }

    var body: some View {
        ZStack {
            // 外側フレーム
            RoundedRectangle(cornerRadius: 44)
                .fill(frameColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 44)
                        .strokeBorder(frameEdge, lineWidth: 1)
                }
                .frame(width: 375, height: 812)
                .shadow(color: .black.opacity(0.55), radius: 32, x: 0, y: 18)

            // 画面ベゼル
            RoundedRectangle(cornerRadius: 38)
                .fill(Color.bgPrimary)
                .frame(width: 363, height: 800)

            // コンテンツ（フルサイズで描画してからclip）
            content
                .frame(width: 363, height: 800)
                .clipShape(RoundedRectangle(cornerRadius: 38))

            // Dynamic Island
            VStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(frameColor)
                    .frame(width: 126, height: 36)
                    .padding(.top, 12)
                Spacer()
            }
            .frame(width: 375, height: 812)

            // ホームインジケーター
            VStack {
                Spacer()
                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 134, height: 5)
                    .padding(.bottom, 8)
            }
            .frame(width: 375, height: 812)

            // ボリュームボタン（左側）
            HStack {
                VStack(spacing: 10) {
                    Capsule().fill(frameColor).frame(width: 4, height: 30)
                    Capsule().fill(frameColor).frame(width: 4, height: 50)
                    Capsule().fill(frameColor).frame(width: 4, height: 50)
                }
                .offset(x: -3)
                Spacer()
            }
            .frame(width: 389, height: 812)
            .offset(x: -7, y: -80)

            // 電源ボタン（右側）
            HStack {
                Spacer()
                Capsule().fill(frameColor).frame(width: 4, height: 70)
                    .offset(x: 3)
            }
            .frame(width: 389, height: 812)
            .offset(x: 7, y: -100)
        }
        .frame(width: 375, height: 812)
        .scaleEffect(scale)
        .frame(width: 375 * scale, height: 812 * scale)
    }
}
