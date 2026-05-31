import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: .spacing16) {
                RoundedRectangle(cornerRadius: .cornerRadiusLarge)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentIndigo, Color.accentPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .shadow(color: Color.accentIndigo.opacity(0.5), radius: 20, x: 0, y: 10)
                    .scaleEffect(scale)

                Text("BotForge")
                    .font(.titleLarge)
                    .foregroundStyle(Color.textSecondary)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5)) {
                scale = 1.0
                opacity = 1
            }
        }
    }
}

#Preview {
    SplashView()
        .preferredColorScheme(.dark)
}
