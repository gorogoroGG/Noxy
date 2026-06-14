import SwiftUI

// MARK: - TicketsCoordinatorView
// チケット機能のエントリーポイント。設置（パネル管理）と対応（チケット一覧）の2タブを管理。
// 初心者向けに、パネル0件時は設置タブを強制表示し、ガイドを表示する。

struct TicketsCoordinatorView: View {
    let guildId: String
    var initialTab: Tab = .setup

    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState
    @State private var panels: [TicketPanel] = []
    @State private var tickets: [Ticket] = []
    @State private var isLoadingPanels = true
    @State private var isLoadingTickets = true

    enum Tab: String, CaseIterable {
        case setup = "設置"
        case respond = "対応"
    }
    @State private var selectedTab: Tab = .setup

    init(guildId: String, initialTab: Tab = .setup) {
        self.guildId = guildId
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
    }

    /// パネルが0件かどうか（ロード完了後に判定）
    private var hasNoPanels: Bool {
        !isLoadingPanels && panels.isEmpty
    }

    /// 未対応チケットがあるかどうか
    private var hasOpenTickets: Bool {
        !isLoadingTickets && tickets.contains { $0.status == .open || $0.status == .pending }
    }

    var body: some View {
        VStack(spacing: 0) {
            // タブセグメント
            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, .spacing8)
            .background(Theme.Color.surface)
            .overlay(Theme.Color.line.frame(height: 1), alignment: .bottom)

            switch selectedTab {
            case .setup:
                TicketPanelListView(guildId: guildId, panels: $panels, isLoading: $isLoadingPanels)
            case .respond:
                if hasNoPanels {
                    // パネル0件時：対応タブは無効化してガイド表示
                    PanelRequiredGuideView {
                        withAnimation { selectedTab = .setup }
                    }
                } else {
                    TicketListView(guildId: guildId, tickets: $tickets)
                }
            }
        }
        .background(Theme.Color.bg)
        .navigationTitle("チケット")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: guildId) { _, _ in
            isLoadingPanels = true
            isLoadingTickets = true
        }
    }


}

// MARK: - PanelRequiredGuideView

private struct PanelRequiredGuideView: View {
    let onGoToSetup: () -> Void

    var body: some View {
        VStack(spacing: .spacing20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.Color.accent.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "ticket.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.Color.accent)
            }

            VStack(spacing: .spacing8) {
                Text("お問い合わせパネルを設置しましょう")
                    .font(.titleMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text("メンバーからの問い合わせを受け付けるには、\nDiscordサーバーにパネルを設置する必要があります。")
                    .font(.bodyRegular)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, .spacing32)

            Button(action: onGoToSetup) {
                HStack(spacing: .spacing8) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("設置タブへ移動")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: 280)
                .frame(height: 52)
                .background(Theme.Color.accent)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            }
            .buttonStyle(ScalePressButtonStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Color.bg)
    }
}

#Preview {
    NavigationStack {
        TicketsCoordinatorView(guildId: "g003")
            .navigationTitle("チケット")
    }
    .environment(\.services, ServiceContainer.mock())
    .environment(AppState())
}
