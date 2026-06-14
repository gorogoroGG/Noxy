import SwiftUI

struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
    }
}

#Preview {
    HStack(spacing: 12) {
        StatusDot(color: Theme.Color.statusOK)
        StatusDot(color: Theme.Color.statusWarn)
        StatusDot(color: Theme.Color.statusBad)
    }
    .padding()
}
