import SwiftUI

struct BotOfflineView: View {
    let onRefresh: () async -> Void

    @State private var isRefreshing = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: .spacing32) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 96, height: 96)
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Color.red)
                }

                VStack(spacing: .spacing12) {
                    Text("Botがオフラインです")
                        .font(.titleLarge)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.textPrimary)

                    Text("Botが応答していません。\nしばらく待ってから再度お試しください。")
                        .font(.bodySmall)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        isRefreshing = true
                        await onRefresh()
                        isRefreshing = false
                    }
                } label: {
                    HStack(spacing: .spacing8) {
                        if isRefreshing {
                            ProgressView().scaleEffect(0.8).tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(isRefreshing ? "確認中..." : "再確認する")
                            .font(.bodySmall).fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, .spacing24)
                    .padding(.vertical, 14)
                    .background(isRefreshing ? Color.textTertiary : Color.accentIndigo)
                    .clipShape(Capsule())
                }
                .disabled(isRefreshing)

                Link(destination: URL(string: "https://discord.gg/9kHVMRxZje")!) {
                    HStack(spacing: .spacing8) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("公式サーバーへ連絡する")
                            .font(.bodySmall).fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.accentIndigo)
                    .padding(.horizontal, .spacing24)
                    .padding(.vertical, 14)
                    .background(Color.accentIndigo.opacity(0.1))
                    .clipShape(Capsule())
                }

                Spacer()
            }
            .padding(.horizontal, .spacing32)
        }
    }
}
