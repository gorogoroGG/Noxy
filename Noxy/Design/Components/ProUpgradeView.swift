import SwiftUI

/// 汎用的なPro機能ペイウォール。各機能画面で利用する。
struct ProUpgradeView: View {
    let featureIcon: String
    let featureTitle: String
    let description: String
    let proFeatures: [(emoji: String, text: String)]

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing32) {
                Spacer().frame(height: .spacing16)

                // Crown + feature title
                VStack(spacing: .spacing16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.accentOrange.opacity(0.2), Color.accentPink.opacity(0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 96, height: 96)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(LinearGradient(
                                colors: [Color.accentOrange, Color.accentPink],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    VStack(spacing: .spacing8) {
                        Text("Noxy Proの機能です")
                            .font(.displayMedium)
                            .foregroundStyle(Color.textPrimary)
                        Text(description)
                            .font(.bodySmall)
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal)

                // Pro feature bullets
                VStack(alignment: .leading, spacing: .spacing8) {
                    Text("Proでできること")
                        .font(.captionRegular)
                        .foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, .spacing16)

                    VStack(spacing: 0) {
                        ForEach(proFeatures.indices, id: \.self) { idx in
                            let f = proFeatures[idx]
                            HStack(spacing: .spacing12) {
                                Text(f.emoji)
                                    .font(.titleMedium)
                                    .frame(width: 32)
                                Text(f.text)
                                    .font(.bodySmall)
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, .spacing16)
                            .padding(.vertical, .spacing12)

                            if idx < proFeatures.count - 1 {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                    .padding(.horizontal, .spacing16)
                }

                // CTA
                VStack(spacing: .spacing12) {
                    NavigationLink(destination: SubscriptionView()) {
                        HStack(spacing: .spacing8) {
                            Image(systemName: "crown.fill")
                            Text("Noxy Proを始める")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(LinearGradient(
                            colors: [Color.accentOrange, Color.accentPink],
                            startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                    }
                    .buttonStyle(ScalePressButtonStyle())
                    .padding(.horizontal)

                    Text("月額 ¥480〜 · いつでも解約可能")
                        .font(.captionRegular)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer().frame(height: .spacing16)
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle(featureTitle)
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        ProUpgradeView(
            featureIcon: "clock.fill",
            featureTitle: "予約投稿",
            description: "指定時刻に自動でメッセージを送信できます",
            proFeatures: [
                ("📅", "日時指定で自動送信"),
                ("🔁", "繰り返し投稿"),
                ("📝", "Embedテンプレート使用"),
            ]
        )
    }
    .environment(AppState())
}
