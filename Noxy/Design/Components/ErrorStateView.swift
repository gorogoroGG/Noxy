import SwiftUI

struct ErrorStateView: View {
    let error: Error
    let retry: () -> Void

    var body: some View {
        VStack(spacing: .spacing16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.accentPink)

            VStack(spacing: .spacing8) {
                Text("Something went wrong")
                    .font(.titleMedium)
                    .foregroundStyle(Color.textPrimary)

                Text(error.localizedDescription)
                    .font(.bodySmall)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            PrimaryButton("Try Again", style: .outlined, size: .medium, icon: "arrow.clockwise") {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                retry()
            }
        }
        .padding(.spacing32)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ErrorStateView(error: ServiceError.networkError) {}
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
