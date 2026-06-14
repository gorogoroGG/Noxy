import SwiftUI

// MARK: - ModerationCenterView

struct ModerationCenterView: View {
    @Environment(AppState.self) private var appState
    @State private var tab: ModTab = .ban

    enum ModTab: CaseIterable {
        case ban, timeout, warning, automod

        var label: String {
            switch self {
            case .ban:     "BANリスト"
            case .timeout: "タイムアウト"
            case .warning: "警告管理"
            case .automod: "AutoMod"
            }
        }
        var icon: String {
            switch self {
            case .ban:     "hand.raised.slash"
            case .timeout: "timer"
            case .warning: "exclamationmark.triangle"
            case .automod: "shield.lefthalf.filled"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            tabContent
                .padding(.top, 44)
            tabBar
        }
        .background(Theme.Color.bg)
        .navigationTitle("モデレーション")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ModTab.allCases, id: \.label) { t in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { tab = t }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: t.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(tab == t ? Theme.Color.accent : Theme.Color.textTertiary)
                        Text(t.label)
                            .font(Theme.Font.caption2)
                            .fontWeight(tab == t ? .semibold : .regular)
                            .foregroundStyle(tab == t ? Theme.Color.accent : Theme.Color.textTertiary)
                        Rectangle()
                            .fill(tab == t ? Theme.Color.accent : Color.clear)
                            .frame(height: 2)
                            .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Theme.Color.surface)
        .overlay(Divider().background(Theme.Color.line), alignment: .bottom)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        let guildId = appState.selectedGuildId
        switch tab {
        case .ban:     ModBanListView(guildId: guildId).id(guildId)
        case .timeout: ModTimeoutView(guildId: guildId).id(guildId)
        case .warning: ModWarningView(guildId: guildId).id(guildId)
        case .automod: AutoModSettingsView()
        }
    }
}

// MARK: - Shared: LoadState

enum LoadState<T> {
    case loading
    case loaded(T)
    case error(String)
}

// MARK: - Shared: Error State

struct ModErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(Theme.Color.textTertiary)
            Text(message)
                .font(Theme.Font.bodySmall)
                .foregroundStyle(Theme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxl)
            AccentButton(title: "再試行", action: retry)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shared: Success Toast

struct ModSuccessToast: View {
    let message: String

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.Color.statusOK)
            Text(message)
                .font(Theme.Font.bodySmall)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Color.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .frame(height: 48)
        .background(Theme.Color.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.Color.lineStrong, lineWidth: 1))
    }
}

// MARK: - Shared: Empty State

struct ModEmptyView: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(Theme.Color.textTertiary)
            Text(title)
                .font(Theme.Font.title3)
                .foregroundStyle(Theme.Color.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(Theme.Font.bodySmall)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Dark") {
    NavigationStack { ModerationCenterView() }
        .environment(AppState())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    NavigationStack { ModerationCenterView() }
        .environment(AppState())
        .preferredColorScheme(.light)
}
