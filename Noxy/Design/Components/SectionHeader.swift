import SwiftUI

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.captionSmall)
                .fontWeight(.semibold)
                .foregroundStyle(Color.textTertiary)
                .tracking(0.8)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.captionRegular)
                    .foregroundStyle(Color.accentIndigo)
            }
        }
        .padding(.horizontal, .spacing16)
        .padding(.vertical, .spacing4)
    }
}

#Preview {
    VStack(spacing: 0) {
        SectionHeader(title: "Recent Activity")
        SectionHeader(title: "Members", actionTitle: "See All") {}
    }
    .background(Color.bgPrimary)
}
