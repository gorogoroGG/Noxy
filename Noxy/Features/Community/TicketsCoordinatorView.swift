import SwiftUI

// MARK: - TicketsCoordinatorView
// チケット機能のエントリーポイント。設置（パネル管理）と対応（チケット一覧）の2タブを管理。
// 初心者向けに、パネル0件時は設置タブを強制表示し、ガイドを表示する。

struct TicketsCoordinatorView: View {
    let guildId: String

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
            .background(Color(.secondarySystemGroupedBackground))
            .overlay(Divider(), alignment: .bottom)

            switch selectedTab {
            case .setup:
                TicketPanelListView(guildId: guildId, panels: $panels)
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
        .background(Color(.systemGroupedBackground))
        .task { await loadInitialData() }
        .onChange(of: guildId) { _, _ in
            isLoadingPanels = true
            isLoadingTickets = true
            Task { await loadInitialData() }
        }
    }

    private func loadInitialData() async {
        async let p = services.tickets.fetchPanels(guildId: guildId)
        async let t = services.tickets.fetchAll(guildId: guildId)
        do {
            let fetchedPanels = try await p
            panels = fetchedPanels
            appState.cacheTicketPanels(fetchedPanels, for: guildId)
            isLoadingPanels = false
            // パネルが0件の場合のみ設置タブに誘導（現在のタブを上書きしない）
            if fetchedPanels.isEmpty {
                selectedTab = .setup
            }
        } catch {
            isLoadingPanels = false
            panels = []
        }
        do {
            let fetchedTickets = try await t
            tickets = fetchedTickets
            appState.cacheTickets(fetchedTickets, for: guildId)
            isLoadingTickets = false
        } catch {
            isLoadingTickets = false
            tickets = []
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
                    .fill(Color.accentIndigo.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "ticket.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentIndigo)
            }

            VStack(spacing: .spacing8) {
                Text("お問い合わせパネルを設置しましょう")
                    .font(.titleMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text("メンバーからの問い合わせを受け付けるには、\nDiscordサーバーにパネルを設置する必要があります。")
                    .font(.bodyRegular)
                    .foregroundStyle(Color.textSecondary)
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
                .background(Color.accentIndigo)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            }
            .buttonStyle(ScalePressButtonStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
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
