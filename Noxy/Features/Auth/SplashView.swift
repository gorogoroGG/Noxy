import SwiftUI

// MARK: - SplashView

struct SplashView: View {
    @State private var contentScale: CGFloat = 0.82
    @State private var contentOpacity: Double = 0
    @State private var contentBlur: CGFloat = 12

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()

            // 波紋リング（コンテンツの後ろ）
            RippleRing(delay: 0.35, baseOpacity: 0.55)
            RippleRing(delay: 0.65, baseOpacity: 0.40)
            RippleRing(delay: 0.95, baseOpacity: 0.28)

            // アンビエントグロー
            Circle()
                .fill(Theme.Color.accent.opacity(0.10))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .opacity(contentOpacity)

            // アプリアイコン + ワードマーク
            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.Color.accent)
                        .frame(width: 80, height: 80)
                        .shadow(color: Theme.Color.accent.opacity(0.45), radius: 28, x: 0, y: 12)

                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text("Noxy")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Color.textPrimary)
                    .tracking(4)
            }
            .scaleEffect(contentScale)
            .opacity(contentOpacity)
            .blur(radius: contentBlur)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.18)) {
                contentScale = 1.0
                contentOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.45)) {
                contentBlur = 0
            }
        }
    }
}

// MARK: - RippleRing（無限ループ版）

private struct RippleRing: View {
    let delay: Double
    let baseOpacity: Double

    private let expandDuration: Double = 1.8
    private let cyclePeriod: Double    = 2.4

    @State private var scale: CGFloat  = 0.01
    @State private var opacity: Double = 0
    @State private var started         = false

    var body: some View {
        Circle()
            .stroke(Theme.Color.accent.opacity(baseOpacity), lineWidth: 1.5)
            .frame(width: 150, height: 150)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                guard !started else { return }
                started = true
                loop(initialDelay: delay)
            }
    }

    private func loop(initialDelay: Double) {
        scale   = 0.01
        opacity = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) {
            withAnimation(.easeIn(duration: 0.12)) { opacity = 1 }
            withAnimation(.easeOut(duration: expandDuration)) { scale = 4.8 }
            withAnimation(.easeOut(duration: 1.0).delay(0.8)) { opacity = 0 }
            // 次サイクル（初回 delay なし）
            DispatchQueue.main.asyncAfter(deadline: .now() + cyclePeriod) {
                loop(initialDelay: 0)
            }
        }
    }
}

#Preview {
    SplashView()
}
