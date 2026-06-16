import SwiftUI

/// 汎用的なPro機能ペイウォール。各機能画面で利用する。
struct ProUpgradeView: View {

    // MARK: - Data types

    struct FlowStep {
        let emoji: String
        let label: String
        let detail: String?
        init(_ emoji: String, _ label: String, _ detail: String? = nil) {
            self.emoji = emoji; self.label = label; self.detail = detail
        }
    }

    struct UseCase {
        let emoji: String
        let title: String
        let description: String
        init(_ emoji: String, _ title: String, _ description: String) {
            self.emoji = emoji; self.title = title; self.description = description
        }
    }

    // MARK: - Props

    let featureIcon: String
    let featureTitle: String
    let description: String
    let flowSteps: [FlowStep]
    let useCases: [UseCase]
    let advancedTips: [String]

    private var proGradient: LinearGradient {
        LinearGradient(colors: [.accentOrange, .accentPink], startPoint: .leading, endPoint: .trailing)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing24) {
                heroSection
                flowSection
                useCasesSection
                if !advancedTips.isEmpty {
                    advancedSection
                }
                Spacer().frame(height: 96)
            }
            .padding(.horizontal, .spacing16)
            .padding(.top, .spacing16)
        }
        .background(Color.bgPrimary)
        .safeAreaInset(edge: .bottom) { ctaSection }
        .navigationTitle(featureTitle)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: .spacing12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.accentOrange.opacity(0.15), Color.accentPink.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                Image(systemName: featureIcon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(proGradient)
            }

            Text("Noxy Pro")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, .spacing8)
                .padding(.vertical, 3)
                .background(proGradient)
                .clipShape(Capsule())

            Text(description)
                .font(.bodySmall)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Flow

    private var flowSection: some View {
        VStack(alignment: .leading, spacing: .spacing10) {
            sectionHeader("こんな流れで動きます")

            VStack(spacing: 0) {
                ForEach(flowSteps.indices, id: \.self) { idx in
                    HStack(alignment: .top, spacing: .spacing12) {
                        ZStack {
                            Circle()
                                .fill(proGradient)
                                .frame(width: 24, height: 24)
                            Text("\(idx + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: .spacing6) {
                                Text(flowSteps[idx].emoji)
                                    .font(.system(size: 16))
                                Text(flowSteps[idx].label)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                            }
                            if let detail = flowSteps[idx].detail {
                                Text(detail)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(Color.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, .spacing12)
                    .padding(.vertical, .spacing12)

                    // Connector between steps
                    if idx < flowSteps.count - 1 {
                        HStack(spacing: 0) {
                            Spacer().frame(width: 23) // align connector with circle badge center
                            Rectangle()
                                .fill(Color.textTertiary.opacity(0.2))
                                .frame(width: 1.5, height: 14)
                            Spacer()
                        }
                    }
                }
            }
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        }
    }

    // MARK: - Use Cases

    private var useCasesSection: some View {
        VStack(alignment: .leading, spacing: .spacing10) {
            sectionHeader("こんな時に便利")

            VStack(spacing: 0) {
                ForEach(useCases.indices, id: \.self) { idx in
                    HStack(alignment: .top, spacing: .spacing12) {
                        Text(useCases[idx].emoji)
                            .font(.system(size: 20))
                            .frame(width: 28, alignment: .center)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(useCases[idx].title)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                            Text(useCases[idx].description)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, .spacing16)
                    .padding(.vertical, .spacing12)

                    if idx < useCases.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        }
    }

    // MARK: - Advanced

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: .spacing10) {
            sectionHeader("応用アイデア")

            VStack(spacing: .spacing8) {
                ForEach(advancedTips.indices, id: \.self) { idx in
                    HStack(alignment: .top, spacing: .spacing10) {
                        Text("💡")
                            .font(.system(size: 14))
                        Text(advancedTips[idx])
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(.spacing12)
                    .background(Color.accentOrange.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
                    .overlay {
                        RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                            .stroke(Color.accentOrange.opacity(0.2), lineWidth: 1)
                    }
                }
            }
        }
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: .spacing8) {
            NavigationLink(destination: SubscriptionView()) {
                HStack(spacing: .spacing8) {
                    Image(systemName: "crown.fill")
                    Text("プロを始める")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(proGradient)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            }
            .buttonStyle(ScalePressButtonStyle())

            Text("月額 ¥480〜 · いつでも解約可能")
                .font(.captionRegular)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, .spacing16)
        .padding(.top, .spacing12)
        .padding(.bottom, .spacing20)
        .background(.regularMaterial)
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.captionRegular)
            .foregroundStyle(Color.textTertiary)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProUpgradeView(
            featureIcon: "heart.fill",
            featureTitle: "リアクションロール",
            description: "パネルの絵文字にリアクションするだけでロールを自動付与・解除。メンバーが自分で役割や通知を管理できます。",
            flowSteps: [
                .init("💬", "パネルメッセージに絵文字でリアクション"),
                .init("⚡", "対応するロールが即座に付与"),
                .init("🔓", "ロールに対応したチャンネル・コンテンツが解禁"),
            ],
            useCases: [
                .init("🎯", "興味カテゴリを自分で選択",
                      "「マイクラ」「Apex」「料理」など、受け取りたいゲームや話題の通知チャンネルに、絵文字1つでアクセス・退場できます。"),
                .init("🔔", "通知を自分でコントロール",
                      "「お知らせだけ受け取る」「全通知受け取る」など、受け取る通知の種類をメンバー自身がコントロールできる仕組みを作れます。"),
                .init("🏷", "自己紹介ロールの設定",
                      "「デザイナー」「学生」「社会人」など、自分の属性をロールで表明できる自己紹介パネルをチャンネルに設置できます。"),
            ],
            advancedTips: [
                "「認証モード」を使うと、一度付与したロールはリアクションを外しても残るため、プレミアム会員資格の管理などに活用できます",
                "「ユニークモード」を使うと、複数の選択肢から1つだけ選ばせる排他的な役職設定パネルが作れます",
            ]
        )
    }
    .environment(AppState())
}
