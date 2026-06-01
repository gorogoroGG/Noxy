import SwiftUI

// MARK: - SalesAnalyticsView

struct SalesAnalyticsView: View {
    let guildId: String

    @Environment(\.services) private var services
    @State private var orders: [Order] = []
    @State private var isLoading = true

    private var totalOrders: Int { orders.count }
    private var completedOrders: Int { orders.filter { $0.status == .completed }.count }
    private var cancelledOrders: Int { orders.filter { $0.status == .cancelled }.count }
    private var openOrders: Int { orders.filter { $0.status == .open }.count }
    private var completionRate: Double {
        guard totalOrders > 0 else { return 0 }
        return Double(completedOrders) / Double(totalOrders) * 100
    }
    private var cancellationRate: Double {
        guard totalOrders > 0 else { return 0 }
        return Double(cancelledOrders) / Double(totalOrders) * 100
    }

    private var productStats: [(name: String, count: Int)] {
        var dict: [String: Int] = [:]
        for order in orders where order.status == .completed {
            dict[order.productName, default: 0] += 1
        }
        return dict.map { (name: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .spacing12) {
                    if isLoading {
                        ProgressView().padding(.top, 60)
                    } else if orders.isEmpty {
                        emptyState
                    } else {
                        overviewSection
                        rateSection
                        productRankingSection
                    }
                }
                .padding(.horizontal, .spacing16)
                .padding(.top, .spacing16)
                .padding(.bottom, .spacing24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("売上分析")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private var overviewSection: some View {
        VStack(spacing: 0) {
            cardHeader("概要", icon: "chart.bar.fill", color: .accentIndigo)
            Divider()
            HStack(spacing: 0) {
                overviewCell(value: "\(totalOrders)", label: "総注文数", color: .accentIndigo)
                Divider().frame(height: 40)
                overviewCell(value: "\(completedOrders)", label: "完了", color: .accentGreen)
                Divider().frame(height: 40)
                overviewCell(value: "\(openOrders)", label: "処理中", color: .accentOrange)
            }
            .padding(.spacing16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func overviewCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(.captionSmall).foregroundStyle(Color.textTertiary)
        }.frame(maxWidth: .infinity)
    }

    private var rateSection: some View {
        VStack(spacing: 0) {
            cardHeader("レート", icon: "percent", color: .accentGreen)
            Divider()
            VStack(spacing: .spacing16) {
                rateBar(label: "完了率", value: completionRate, color: .accentGreen)
                rateBar(label: "キャンセル率", value: cancellationRate, color: .red)
            }
            .padding(.spacing16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func rateBar(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.captionRegular).fontWeight(.medium).foregroundStyle(Color.textPrimary)
                Spacer()
                Text(String(format: "%.1f%%", value)).font(.captionSmall).fontWeight(.semibold).foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(.tertiarySystemGroupedBackground))
                    RoundedRectangle(cornerRadius: 4).fill(color)
                        .frame(width: geo.size.width * CGFloat(value / 100))
                }
            }
            .frame(height: 8)
        }
    }

    private var productRankingSection: some View {
        VStack(spacing: 0) {
            cardHeader("商品別売上ランキング", icon: "trophy.fill", color: .accentOrange)
            Divider()
            if productStats.isEmpty {
                Text("完了した注文がありません")
                    .font(.captionSmall).foregroundStyle(Color.textTertiary)
                    .padding(.spacing16)
            } else {
                VStack(spacing: .spacing8) {
                    ForEach(Array(productStats.enumerated()), id: \.offset) { index, stat in
                        HStack(spacing: .spacing12) {
                            ZStack {
                                Circle().fill(rankingColor(for: index)).frame(width: 28, height: 28)
                                Text("\(index + 1)").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                            }
                            Text(stat.name)
                                .font(.bodySmall).fontWeight(.medium).foregroundStyle(Color.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(stat.count)件")
                                .font(.captionSmall).fontWeight(.semibold).foregroundStyle(Color.accentOrange)
                        }
                        .padding(.horizontal, .spacing12).padding(.vertical, .spacing8)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.spacing12)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func rankingColor(for index: Int) -> Color {
        switch index {
        case 0: return .accentOrange
        case 1: return Color(uiColor: UIColor(hex: 0x94A3B8))
        case 2: return Color(uiColor: UIColor(hex: 0xCD7F32))
        default: return Color.textTertiary
        }
    }

    private var emptyState: some View {
        VStack(spacing: .spacing12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40)).foregroundStyle(Color.textTertiary)
            Text("データがありません")
                .font(.titleMedium).foregroundStyle(Color.textPrimary)
            Text("注文が発生すると分析データが表示されます")
                .font(.captionRegular).foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    private func cardHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: .spacing8) {
            Image(systemName: icon).font(.captionRegular).foregroundStyle(color)
            Text(title).font(.captionSmall).fontWeight(.semibold)
                .foregroundStyle(Color.textTertiary).textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, .spacing16).padding(.vertical, .spacing10)
    }

    private func load() async {
        isLoading = true
        orders = (try? await services.shops.fetchOrders(guildId: guildId, status: nil)) ?? []
        isLoading = false
    }
}
