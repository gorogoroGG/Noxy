import SwiftUI

// MARK: - OrderDetailView

struct OrderDetailView: View {
    @State var order: Order
    let guildId: String
    let onUpdate: (Order) -> Void

    @Environment(\.services) private var services
    @Environment(\.dismiss)  private var dismiss

    @State private var isActioning = false
    @State private var errorMessage: String? = nil
    @State private var showConfirmPayment = false
    @State private var showConfirmComplete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .spacing12) {
                    statusCard
                    infoCard
                    timelineCard
                    actionSection
                }
                .padding(.horizontal, .spacing16)
                .padding(.top, .spacing16)
                .padding(.bottom, .spacing24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("注文詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完了") { dismiss() }.foregroundStyle(Color.accentIndigo)
                }
            }
            .alert("支払いを確認しましたか？", isPresented: $showConfirmPayment) {
                Button("確認する", role: .none) { Task { await confirmPayment() } }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("支払いを確認すると、対価が自動的に送信されます。")
            }
            .alert("取引を完了しますか？", isPresented: $showConfirmComplete) {
                Button("完了にする", role: .none) { Task { await completeOrder() } }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("管理者側が取引完了を確認します。購入者も完了ボタンを押すとアーカイブされます。")
            }
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: .spacing8) {
                Image(systemName: order.status.icon)
                    .font(.system(size: 16)).foregroundStyle(order.status.chipColor)
                Text(order.status.label)
                    .font(.bodySmall).fontWeight(.semibold).foregroundStyle(order.status.chipColor)
                Spacer()
            }
            .padding(.horizontal, .spacing16).padding(.vertical, .spacing12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(spacing: 0) {
            cardHeader("注文情報", icon: "cart.fill", color: .accentIndigo)
            Divider()
            infoRow("商品", value: order.productName)
            Divider().padding(.leading, .spacing16)
            infoRow("価格", value: order.productPriceDisplay)
            Divider().padding(.leading, .spacing16)
            infoRow("購入者", value: "@\(order.buyerUsername)")
            Divider().padding(.leading, .spacing16)
            infoRow("注文日時", value: order.createdAt.formatted(date: .abbreviated, time: .shortened))
            if let paymentUrl = order.paymentUrl {
                Divider().padding(.leading, .spacing16)
                paymentUrlRow(paymentUrl)
            }
            if let paidAt = order.paidAt {
                Divider().padding(.leading, .spacing16)
                infoRow("支払確認", value: paidAt.formatted(date: .abbreviated, time: .shortened))
            }
            if let deliveredAt = order.deliveredAt {
                Divider().padding(.leading, .spacing16)
                infoRow("引渡完了", value: deliveredAt.formatted(date: .abbreviated, time: .shortened))
            }
            if let completedAt = order.completedAt {
                Divider().padding(.leading, .spacing16)
                infoRow("取引完了", value: completedAt.formatted(date: .abbreviated, time: .shortened))
            }
            if let cancelledAt = order.cancelledAt {
                Divider().padding(.leading, .spacing16)
                infoRow("キャンセル", value: cancelledAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func paymentUrlRow(_ url: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("支払いURL").font(.bodySmall).foregroundStyle(Color.textSecondary)
                Spacer()
                Text(url).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.accentIndigo)
                    .lineLimit(1)
            }
            Button("URLを開く") {
                if let nsUrl = URL(string: url) {
                    UIApplication.shared.open(nsUrl)
                }
            }
            .font(.captionSmall)
            .foregroundStyle(Color.accentIndigo)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, .spacing16).padding(.vertical, .spacing12)
    }

    // MARK: - Timeline Card

    private var timelineCard: some View {
        VStack(spacing: 0) {
            cardHeader("ステータス推移", icon: "clock.fill", color: .accentPurple)
            Divider()
            VStack(spacing: .spacing12) {
                timelineItem(icon: "cart.fill", label: "注文作成", date: order.createdAt, color: .accentOrange, active: true)
                timelineItem(icon: "creditcard.fill", label: "支払い確認", date: order.paidAt, color: .accentIndigo, active: order.paidAt != nil)
                timelineItem(icon: "shippingbox.fill", label: "商品引渡", date: order.deliveredAt, color: .accentPurple, active: order.deliveredAt != nil)
                timelineItem(icon: "checkmark.circle.fill", label: "取引完了", date: order.completedAt, color: .accentGreen, active: order.completedAt != nil)
            }
            .padding(.spacing16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func timelineItem(icon: String, label: String, date: Date?, color: Color, active: Bool) -> some View {
        HStack(spacing: .spacing12) {
            ZStack {
                Circle().fill(active ? color : Color(.tertiarySystemGroupedBackground)).frame(width: 28, height: 28)
                Image(systemName: icon).font(.system(size: 12)).foregroundStyle(active ? .white : Color.textTertiary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.captionRegular).fontWeight(.medium)
                    .foregroundStyle(active ? Color.textPrimary : Color.textTertiary)
                if let date {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10)).foregroundStyle(Color.textTertiary)
                }
            }
            Spacer()
            if active {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(color)
            } else {
                Circle().fill(Color(.tertiarySystemGroupedBackground)).frame(width: 16, height: 16)
            }
        }
    }

    // MARK: - Action Section

    private var actionSection: some View {
        VStack(spacing: .spacing8) {
            if order.status == .open {
                Button {
                    showConfirmPayment = true
                } label: {
                    HStack(spacing: .spacing8) {
                        if isActioning {
                            ProgressView().scaleEffect(0.85).tint(.white)
                        } else {
                            Image(systemName: "creditcard.fill")
                        }
                        Text(isActioning ? "処理中..." : "支払いを確認する")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.accentGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isActioning)
            }

            if order.status == .delivered || order.status == .paid {
                Button {
                    showConfirmComplete = true
                } label: {
                    HStack(spacing: .spacing8) {
                        if isActioning {
                            ProgressView().scaleEffect(0.85).tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(isActioning ? "処理中..." : "取引完了（管理者）")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.accentIndigo)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isActioning)
            }

            if let err = errorMessage {
                HStack(spacing: .spacing8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(err).font(.captionSmall).foregroundStyle(Color.textSecondary)
                }
                .padding(.spacing12)
                .background(Color.accentOrange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Helpers

    private func cardHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: .spacing8) {
            Image(systemName: icon).font(.captionRegular).foregroundStyle(color)
            Text(title).font(.captionSmall).fontWeight(.semibold)
                .foregroundStyle(Color.textTertiary).textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, .spacing16).padding(.vertical, .spacing10)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.bodySmall).foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value).font(.bodySmall).fontWeight(.medium).foregroundStyle(Color.textPrimary)
        }.padding(.horizontal, .spacing16).padding(.vertical, .spacing12)
    }

    // MARK: - Actions

    private func confirmPayment() async {
        isActioning = true; errorMessage = nil
        do {
            let updated = try await services.shops.confirmPayment(orderId: order.id)
            order = updated
            onUpdate(updated)
        } catch {
            errorMessage = "支払い確認に失敗しました"
        }
        isActioning = false
    }

    private func completeOrder() async {
        isActioning = true; errorMessage = nil
        do {
            let updated = try await services.shops.completeOrder(orderId: order.id, party: "seller")
            order = updated
            onUpdate(updated)
        } catch {
            errorMessage = "取引完了処理に失敗しました"
        }
        isActioning = false
    }
}
