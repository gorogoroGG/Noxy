import SwiftUI

struct StatCard: View {
    let label: String
    let value: String
    var trend: Double? = nil
    var icon: String = "chart.bar.fill"
    var accentColor: Color = .accentIndigo

    private var trendText: String? {
        guard let trend else { return nil }
        let sign = trend >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.0f", trend))%"
    }

    private var trendColor: Color {
        guard let trend else { return .textTertiary }
        return trend >= 0 ? .accentGreen : .accentPink
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            HStack {
                Image(systemName: icon)
                    .font(.captionRegular)
                    .foregroundStyle(accentColor)

                Spacer()

                if let trendText {
                    HStack(spacing: 2) {
                        Image(systemName: (trend ?? 0) >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.captionSmall)
                        Text(trendText)
                            .font(.captionSmall)
                    }
                    .foregroundStyle(trendColor)
                }
            }

            Text(value)
                .font(.displayMedium)
                .foregroundStyle(Color.textPrimary)

            Text(label)
                .font(.captionRegular)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.spacing16)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: .spacing12) {
        StatCard(label: "Total Members", value: "16,287", trend: 12, icon: "person.3.fill", accentColor: .accentIndigo)
        StatCard(label: "Messages Today", value: "4,521", trend: 5, icon: "bubble.left.fill", accentColor: .accentGreen)
        StatCard(label: "Commands Used", value: "892", trend: -3, icon: "bolt.fill", accentColor: .accentOrange)
        StatCard(label: "Active Tickets", value: "7", icon: "ticket.fill", accentColor: .accentPink)
    }
    .padding()
    .background(Color.bgPrimary)
}
