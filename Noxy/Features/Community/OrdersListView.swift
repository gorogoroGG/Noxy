import SwiftUI

// MARK: - OrdersListView

struct OrdersListView: View {
    let guildId: String

    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState
    @State private var orders: [Order] = []
    @State private var isLoading = true
    @State private var selectedGroup: StatusGroup? = nil
    @State private var selectedOrder: Order? = nil
    @State private var searchText = ""

    // ステータスグループ（複数の OrderStatus をまとめてフィルタ）
    enum StatusGroup: Hashable, CaseIterable {
        case open, processing, completed, cancelled, disputed

        var label: String {
            switch self {
            case .open:       "受付中"
            case .processing: "処理中"
            case .completed:  "完了"
            case .cancelled:  "取消"
            case .disputed:   "異議"
            }
        }

        var statuses: [OrderStatus] {
            switch self {
            case .open:       [.open]
            case .processing: [.paid, .delivered]
            case .completed:  [.completed]
            case .cancelled:  [.cancelled]
            case .disputed:   [.disputed]
            }
        }

        var color: Color {
            switch self {
            case .open:       .accentOrange
            case .processing: .accentIndigo
            case .completed:  .accentGreen
            case .cancelled:  Color.textTertiary
            case .disputed:   .red
            }
        }
    }

    private func count(for group: StatusGroup) -> Int {
        orders.filter { group.statuses.contains($0.status) }.count
    }

    private var filtered: [Order] {
        var base = orders
        if let group = selectedGroup {
            base = base.filter { group.statuses.contains($0.status) }
        }
        if !searchText.isEmpty {
            base = base.filter {
                $0.productName.localizedCaseInsensitiveContains(searchText) ||
                $0.buyerUsername.localizedCaseInsensitiveContains(searchText)
            }
        }
        return base.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            statsHeader
            searchBar

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        if isLoading {
                            HStack { Spacer(); ProgressView(); Spacer() }
                                .padding(.top, 40)
                        } else if filtered.isEmpty {
                            emptyState
                        } else {
                            Text("\(filtered.count)件")
                                .font(.captionSmall)
                                .foregroundStyle(Color.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .padding(.bottom, 2)

                            ForEach(filtered) { order in
                                OrderCard(order: order)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedOrder = order }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                            }

                            Color.clear.frame(height: 60)
                        }
                    }
                    .frame(minHeight: geometry.size.height + 1)
                }
                .background(Color(.systemGroupedBackground))
                .refreshable { await load() }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .sheet(item: $selectedOrder) { order in
            OrderDetailView(order: order, guildId: guildId) { updated in
                if let idx = orders.firstIndex(where: { $0.id == updated.id }) {
                    orders[idx] = updated
                }
            }
        }
        .task { await load() }
    }

    // MARK: - Stats Header（タップでフィルタ）

    private var statsHeader: some View {
        HStack(spacing: 0) {
            ForEach(StatusGroup.allCases, id: \.self) { group in
                let isSelected = selectedGroup == group
                let cnt = count(for: group)

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedGroup = isSelected ? nil : group
                    }
                } label: {
                    VStack(spacing: 3) {
                        Text("\(cnt)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? .white : group.color)
                        Text(group.label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isSelected ? .white.opacity(0.85) : Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        isSelected
                            ? group.color
                            : group.color.opacity(cnt > 0 ? 0.08 : 0)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(4)
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.18), value: selectedGroup)
            }
        }
        .padding(.horizontal, .spacing8)
        .padding(.vertical, .spacing4)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Search Bar（固定ヘッダー内に置くインライン検索）
    // List への .searchable はネストした固定ヘッダーとスクロール時に競合し UI が崩れるため、
    // ナビバー検索ではなくインラインの検索フィールドを使う。

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textTertiary)

            TextField("商品名・購入者で検索", text: $searchText)
                .font(.bodySmall)
                .foregroundStyle(Color.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: .spacing12) {
            Image(systemName: "cart")
                .font(.system(size: 36)).foregroundStyle(Color.textTertiary)
            Text("注文がありません")
                .font(.titleMedium).foregroundStyle(Color.textPrimary)
            Text(selectedGroup == nil ? "まだ注文はありません" : "このステータスの注文はありません")
                .font(.captionRegular).foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    private func load() async {
        if let cached: [Order] = appState.guildData(.orders, guild: guildId) {
            orders = cached
            isLoading = false
        } else {
            isLoading = true
        }
        if let fetched = try? await services.shops.fetchOrders(guildId: guildId, status: nil) {
            orders = fetched
            appState.setGuildData(fetched, .orders, guild: guildId)
        }
        isLoading = false
    }
}

// MARK: - OrderCard

private struct OrderCard: View {
    let order: Order

    var body: some View {
        HStack(spacing: 0) {
            // ステータスカラーのアクセントバー
            RoundedRectangle(cornerRadius: 2)
                .fill(order.status.chipColor)
                .frame(width: 3)
                .padding(.vertical, 8)
                .padding(.leading, 12)

            VStack(alignment: .leading, spacing: 6) {
                // 1行目: 商品名 ＋ ステータスバッジ
                HStack(alignment: .center, spacing: .spacing6) {
                    Text(order.productName)
                        .font(.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(order.status.label)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(order.status.chipColor)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(order.status.chipColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                // 2行目: 購入者 · 価格 · 日時
                HStack(spacing: 0) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textTertiary)
                        .padding(.trailing, 4)
                    Text(order.buyerUsername)
                        .font(.captionSmall)
                        .foregroundStyle(Color.textSecondary)

                    Text(" · ")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)

                    Text(order.productPriceDisplay)
                        .font(.captionSmall)
                        .foregroundStyle(Color.textSecondary)

                    if order.paymentUrl != nil {
                        Text(" · ")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                        Image(systemName: "link")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.accentIndigo)
                        Text("URL済")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.accentIndigo)
                    }

                    Spacer(minLength: 4)
                    Text(order.createdAt.formatted(.relative(presentation: .named)))
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 14)
            .padding(.vertical, 14)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
