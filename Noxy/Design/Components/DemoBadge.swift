import SwiftUI

struct DemoBadge: View {
    var body: some View {
        Label("デモデータ", systemImage: "flask.fill")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.orange.opacity(0.12), in: Capsule())
    }
}
