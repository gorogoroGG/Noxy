import SwiftUI

struct SectionLabel: View {
    let title: String
    var isRequired: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            Text(title.uppercased())
                .font(Theme.Font.sectionLabel)
                .tracking(Theme.sectionLabelTracking)
                .foregroundStyle(Theme.Color.textTertiary)
            if isRequired {
                Text("*")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Color.statusBad)
            }
        }
    }
}

#Preview {
    SectionLabel(title: "サーバー情報")
        .padding()
}
