import SwiftUI

// MARK: - ModerationCenterView

struct ModerationCenterView: View {
    @State private var tab: ModTab = .overview

    enum ModTab: String, CaseIterable {
        case overview  = "概要"
        case ban       = "BAN"
        case timeout   = "タイムアウト"
        case warning   = "警告"

        var icon: String {
            switch self {
            case .overview: "shield.lefthalf.filled"
            case .ban:      "hand.raised.slash.fill"
            case .timeout:  "timer"
            case .warning:  "exclamationmark.triangle.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            tabContent
        }
        .background(Color.bgPrimary)
        .navigationTitle("モデレーション")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(ModTab.allCases, id: \.self) { t in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { tab = t }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 4) {
                            HStack(spacing: 5) {
                                Image(systemName: t.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(t.rawValue)
                                    .font(.bodySmall)
                                    .fontWeight(tab == t ? .semibold : .regular)
                            }
                            .foregroundStyle(tab == t ? Color.accentIndigo : Color.textSecondary)

                            Rectangle()
                                .fill(tab == t ? Color.accentIndigo : Color.clear)
                                .frame(height: 2)
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, .spacing16)
                        .padding(.top, .spacing8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color.bgSurface)
    }

    // MARK: - Content

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .overview: ModOverviewView()
        case .ban:      ModBanListView()
        case .timeout:  ModTimeoutView()
        case .warning:  ModWarningView()
        }
    }
}

// MARK: - Stat Card (shared)

struct ModStatCard: View {
    let icon: String
    let color: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: .spacing8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(value)
                .font(.displayMedium)
                .foregroundStyle(Color.textPrimary)

            Text(label)
                .font(.captionSmall)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.spacing16)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .overlay(RoundedRectangle(cornerRadius: .cornerRadiusMedium).stroke(Color.border, lineWidth: 1))
    }
}

#Preview {
    NavigationStack { ModerationCenterView() }
        .preferredColorScheme(.dark)
}
