import SwiftUI

struct MonoText: View {
    let value: String
    var font: Font = Theme.Font.mono
    var color: Color = Theme.Color.textSecondary

    var body: some View {
        Text(value)
            .font(font)
            .foregroundStyle(color)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        MonoText(value: "1234567890123456789")
        MonoText(value: "42ms", color: Theme.Color.statusOK)
        MonoText(value: "2026-06-11 09:41:00", font: Theme.Font.monoCap)
    }
    .padding()
}
