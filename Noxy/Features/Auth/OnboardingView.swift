import SwiftUI

private struct OnboardingPage {
    let title: String
    let subtitle: String
    let icon: String
    let gradientColors: [Color]
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        title: "どこからでも管理",
        subtitle: "スマホからDiscordボットをいつでも操作できます。",
        icon: "iphone.and.arrow.forward",
        gradientColors: [.accentIndigo, .accentPurple]
    ),
    OnboardingPage(
        title: "美しいEmbedビルダー",
        subtitle: "ライブプレビュー付きのエディターで魅力的なEmbedを作成。",
        icon: "rectangle.stack.fill",
        gradientColors: [.accentPink, .accentPurple]
    ),
    OnboardingPage(
        title: "コミュニティをリアルタイム管理",
        subtitle: "チケット・メンバー・モデレーションを一元管理。",
        icon: "person.3.fill",
        gradientColors: [.accentGreen, .accentIndigo]
    ),
]

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(), value: currentPage)

                VStack(spacing: .spacing24) {
                    // Page dots
                    HStack(spacing: .spacing8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? Color.accentIndigo : Color.border)
                                .frame(width: index == currentPage ? 20 : 8, height: 8)
                                .animation(.spring(), value: currentPage)
                        }
                    }

                    if currentPage == pages.count - 1 {
                        PrimaryButton("はじめる", style: .filled, size: .large) {
                            withAnimation {
                                hasSeenOnboarding = true
                            }
                        }
                        .padding(.horizontal, .spacing32)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        HStack {
                            Button("スキップ") {
                                hasSeenOnboarding = true
                            }
                            .foregroundStyle(Color.textTertiary)
                            .font(.bodySmall)

                            Spacer()

                            Button {
                                withAnimation {
                                    currentPage += 1
                                }
                            } label: {
                                HStack(spacing: .spacing4) {
                                    Text("次へ")
                                    Image(systemName: "arrow.right")
                                }
                                .font(.bodySmall)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentIndigo)
                            }
                        }
                        .padding(.horizontal, .spacing32)
                    }
                }
                .padding(.bottom, .spacing32)
            }
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: .spacing32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: page.gradientColors.map { $0.opacity(0.2) },
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 200, height: 200)

                Image(systemName: page.icon)
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(
                        LinearGradient(colors: page.gradientColors,
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }

            VStack(spacing: .spacing12) {
                Text(page.title)
                    .font(.displayMedium)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.bodyRegular)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, .spacing32)
            }

            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
        .preferredColorScheme(.dark)
}
