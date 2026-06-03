import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: .spacing16) {
                RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentIndigo, Color.accentPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(Color.white)
                    }

                Text("BotForge")
                    .font(.displayMedium)
                    .foregroundStyle(Color.textPrimary)

                Text("Architecture initialized")
                    .font(.bodySmall)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }
}

#Preview("Dark") {
    ContentView()
}

#Preview("Light") {
    ContentView()
}
