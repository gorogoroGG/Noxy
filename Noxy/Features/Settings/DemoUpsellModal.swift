import SwiftUI

struct DemoUpsellModal: View {
    let actionName: String
    let onDismiss: () -> Void

    @State private var showSubscription = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                successHeader
                    .padding(.top, 36)

                descriptionBlock
                    .padding(.top, 24)

                Spacer()

                actionButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.Color.textTertiary)
                            .font(.title3)
                    }
                }
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }

    private var successHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.green)
            }

            Text("\(actionName)（デモ）")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private var descriptionBlock: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.Color.surfaceRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.Color.line, lineWidth: 1)
                )
                .overlay {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("本番ではこう動きます", systemImage: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.Color.accent)

                        Text("有料版では「\(actionName)」が Discord 上で実際に実行されます。今あなたが操作した内容がそのままサーバーに反映されます。")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                }
                .frame(height: nil)
                .padding(.horizontal, 24)

            Label("デモモード中はデータはサーバーに送信されません", systemImage: "flask.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                onDismiss()
                showSubscription = true
            } label: {
                Label("有料版に登録する", systemImage: "crown.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }

            Button("閉じる", action: onDismiss)
                .font(.system(size: 14))
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }
}
