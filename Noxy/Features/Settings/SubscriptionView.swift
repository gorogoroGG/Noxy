import SwiftUI

struct SubscriptionView: View {
    @State private var selectedPlan = "monthly"

    private let features: [(String, Bool, Bool)] = [
        ("最大3サーバー", true, false),
        ("サーバーあたり10 Embed", true, false),
        ("自動返信5件", true, false),
        ("無制限サーバー", false, true),
        ("無制限Embed", false, true),
        ("無制限自動返信", false, true),
        ("予約送信", false, true),
        ("高度な分析", false, true),
        ("優先サポート", false, true),
        ("APIアクセス", false, true),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing24) {
                // Header
                VStack(spacing: .spacing8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(colors: [Color.accentOrange, Color.accentPink],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    Text("BotForge Pro")
                        .font(.displayMedium)
                        .foregroundStyle(Color.textPrimary)
                    Text("Discord Botの無制限パワーを解放しましょう。")
                        .font(.bodyRegular)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                // Plan selector
                HStack(spacing: .spacing12) {
                    PlanCard(title: "月額", price: "¥980", period: "/ 月",
                             isSelected: selectedPlan == "monthly") {
                        selectedPlan = "monthly"
                    }
                    PlanCard(title: "年額", price: "¥9,800", period: "/ 年",
                             badge: "17%お得", isSelected: selectedPlan == "annual") {
                        selectedPlan = "annual"
                    }
                }
                .padding(.horizontal)

                // Feature comparison
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Text("Free").font(.captionRegular).fontWeight(.semibold)
                            .foregroundStyle(Color.textSecondary).frame(width: 50)
                        Text("Pro").font(.captionRegular).fontWeight(.semibold)
                            .foregroundStyle(Color.accentOrange).frame(width: 50)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, .spacing8)

                    ForEach(features, id: \.0) { feature, free, pro in
                        HStack {
                            Text(feature).font(.bodySmall).foregroundStyle(Color.textPrimary)
                            Spacer()
                            Image(systemName: free ? "checkmark" : "minus")
                                .foregroundStyle(free ? Color.accentGreen : Color.textTertiary)
                                .frame(width: 50)
                            Image(systemName: pro || free ? "checkmark" : "minus")
                                .foregroundStyle((pro || free) ? Color.accentOrange : Color.textTertiary)
                                .frame(width: 50)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, .spacing8)
                        Divider().background(Color.border).padding(.horizontal)
                    }
                }
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                .padding(.horizontal)

                // CTA
                VStack(spacing: .spacing12) {
                    PrimaryButton("無料トライアルを開始", style: .filled, size: .large) {}
                        .padding(.horizontal)
                    Button("購入を復元") {}
                        .font(.bodySmall)
                        .foregroundStyle(Color.textTertiary)
                    Text("利用規約 · プライバシー · サブスク管理")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(.bottom, .spacing32)
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle("BotForge Pro")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PlanCard: View {
    let title: String
    let price: String
    let period: String
    var badge: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: .spacing8) {
                if let badge {
                    Badge(text: badge, color: .accentOrange)
                }
                Text(title).font(.titleMedium).foregroundStyle(Color.textPrimary)
                Text(price).font(.displayMedium).foregroundStyle(isSelected ? Color.accentOrange : Color.textPrimary)
                Text(period).font(.captionRegular).foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.spacing16)
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                    .strokeBorder(isSelected ? Color.accentOrange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(ScalePressButtonStyle())
    }
}

#Preview {
    NavigationStack { SubscriptionView() }
        .preferredColorScheme(.dark)
}
