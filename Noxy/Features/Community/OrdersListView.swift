import SwiftUI

// MARK: - OrdersListView

struct OrdersListView: View {
    let guildId: String

    @Environment(\.services) private var services
    @State private var orders: [Order] = []
    @State private var isLoading = true
    @State private var selectedStatus: OrderStatus? = nil
    @State private var selectedOrder: Order? = nil
    @State private var searchText = ""

    private var filtered: [Order] {
        var base = orders
        if let status = selectedStatus { base = base.filter { $0.status == status } }
        if !searchText.isEmpty {
            base = base.filter {
                $0.productName.localizedCaseInsensitiveContains(searchText) ||
                $0.buyerUsername.localizedCaseInsensitiveContains(searchText)
            }
        }
        return base.sorted { $0.createdAt > $1.createdAt }
    }

    private var openCount:    Int { orders.filter { $0.status == .open    }.count }
    private var paidCount:    Int { orders.filter { $0.status == .paid || $0.status == .delivered }.count }
    private var completedCount: Int { orders.filter { $0.status == .completed }.count }
    private var cancelledCount: Int { orders.filter { $0.status == .cancelled }.count }

    var body: some View {
        VStack(spacing: 0) {
            statsHeader
            statusTabBar

            List {
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .listRowBackground(Color(.systemGroupedBackground))
                        .listRowSeparator(.hidden).padding(.top, 40)
                } else if filtered.isEmpty {
                    emptyState
                        .listRowBackground(Color(.systemGroupedBackground))
                        .listRowSeparator(.hidden)
                } else {
                    Text("\(filtered.count)件")
                        .font(.captionSmall).foregroundStyle(Color.textTertiary)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
                        .listRowBackground(Color(.systemGroupedBackground))
                        .listRowSeparator(.hidden)

                    ForEach(filtered) { order in
                        OrderCard(order: order)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedOrder = order }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color(.systemGroupedBackground))
                            .listRowSeparator(.hidden)
                    }
                }

                Color.clear.frame(height: 60)
                    .listRowBackground(Color(.systemGroupedBackground))
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .background(Color(.systemGroupedBackground))
            .searchable(text: $searchText, prompt: "商品名・購入者で検索")
            .refreshable { await load() }
        }
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

    private var statsHeader: some View {
        HStack(spacing: 0) {
            statCell(value: "\(openCount)", label: "受付中", color: .accentOrange)
            Divider().frame(height: 32)
            statCell(value: "\(paidCount)", label: "処理中", color: .accentIndigo)
            Divider().frame(height: 32)
            statCell(value: "\(completedCount)", label: "完了", color: .accentGreen)
            Divider().frame(height: 32)
            statCell(value: "\(cancelledCount)", label: "取消", color: Color.textTertiary)
        }
        .padding(.vertical, .spacing12)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(Divider(), alignment: .bottom)
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(.captionSmall).foregroundStyle(Color.textTertiary)
        }.frame(maxWidth: .infinity)
    }

    private var statusTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .spacing8) {
                statusChip("すべて", icon: "list.bullet", status: nil, color: Color.textSecondary)
                ForEach(OrderStatus.allCases, id: \.self) { s in
                    statusChip(s.label, icon: s.icon, status: s, color: s.chipColor)
                }
            }
            .padding(.horizontal, .spacing12).padding(.vertical, .spacing8)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(Divider(), alignment: .bottom)
    }

    private func statusChip(_ label: String, icon: String, status: OrderStatus?, color: Color) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedStatus = status }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10))
                Text(label).font(.captionSmall).fontWeight(.medium)
            }
            .foregroundStyle(selectedStatus == status ? .white : color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(selectedStatus == status ? color : color.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: .spacing12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 36)).foregroundStyle(Color.textTertiary)
            Text("注文がありません")
                .font(.titleMedium).foregroundStyle(Color.textPrimary)
            Text(selectedStatus == nil
                 ? "条件に一致する注文はありません"
                 : "このステータスの注文はありません")
                .font(.captionRegular).foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    private func load() async {
        isLoading = true
        orders = (try? await services.shops.fetchOrders(guildId: guildId, status: nil)) ?? []
        isLoading = false
    }
}

// MARK: - OrderCard

private struct OrderCard: View {
    let order: Order

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: .spacing12) {
                ZStack {
                    Circle().fill(order.status.chipColor.opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: order.status.icon)
                        .font(.system(size: 14)).foregroundStyle(order.status.chipColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(order.productName)
                            .font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(order.status.label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(order.status.chipColor)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(order.status.chipColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    HStack(spacing: .spacing12) {
                        Label("@\(order.buyerUsername)", systemImage: "person.fill")
                            .font(.captionSmall).foregroundStyle(Color.textTertiary)
                        Label(order.productPriceDisplay, systemImage: "tag.fill")
                            .font(.captionSmall).foregroundStyle(Color.textTertiary)
                        Spacer()
                        Text(order.createdAt.formatted(.relative(presentation: .named)))
                            .font(.captionSmall).foregroundStyle(Color.textTertiary)
                    }
                }
            }
            .padding(.spacing12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
