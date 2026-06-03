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
            case .ban:     "hand.raised.slash.fill"
            case .timeout: "timer"
            case .warning: "exclamationmark.triangle.fill"
            case .automod: "shield.lefthalf.filled.badge.checkmark"
            }
        }
        var color: Color {
            switch self {
            case .ban:     .accentRed
            case .timeout: .accentPurple
            case .warning: .accentOrange
            case .automod: .accentIndigo
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            tabContent
                .padding(.top, 44) // タブバーの高さ分だけ下にずらす
            tabBar
        }
        .background(Color.bgPrimary)
        .navigationTitle("モデレーション")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Tab Bar（常に固定）

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
                            .foregroundStyle(tab == t ? t.color : Color.textTertiary)
                        Text(t.label)
                            .font(.captionSmall)
                            .fontWeight(tab == t ? .semibold : .regular)
                            .foregroundStyle(tab == t ? t.color : Color.textTertiary)
                        Rectangle()
                            .fill(tab == t ? t.color : Color.clear)
                            .frame(height: 2)
                            .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .spacing10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.bgSurface)
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        let guildId = appState.selectedGuildId
        switch tab {
        case .ban:     ModBanListView(guildId: guildId)
        case .timeout: ModTimeoutView(guildId: guildId)
        case .warning: ModWarningView(guildId: guildId)
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
        VStack(spacing: .spacing16) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(Color.textTertiary)
            Text(message)
                .font(.bodySmall)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, .spacing32)
            Button("再試行", action: retry)
                .font(.bodySmall).fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, .spacing24).frame(height: 40)
                .background(Color.accentIndigo)
                .clipShape(Capsule())
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shared: Success Toast

struct ModSuccessToast: View {
    let message: String

    var body: some View {
        HStack(spacing: .spacing8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
            Text(message)
                .font(.bodySmall).fontWeight(.semibold).foregroundStyle(.white)
        }
        .padding(.horizontal, .spacing20).frame(height: 48)
        .background(Color.accentGreen)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
}

// MARK: - Shared: Empty State

struct ModEmptyView: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: .spacing12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(Color.accentGreen.opacity(0.6))
            Text(title)
                .font(.titleMedium).foregroundStyle(Color.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.bodySmall).foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack { ModerationCenterView() }
        .environment(AppState())
}
