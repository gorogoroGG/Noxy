import SwiftUI

enum ChannelType {
    case text, voice, announcement
}

struct ChannelRow: View {
    let name: String
    var type: ChannelType = .text
    var isSelected: Bool = false
    var isLocked: Bool = false

    private var iconName: String {
        switch type {
        case .text:         "number"
        case .voice:        "speaker.wave.2.fill"
        case .announcement: "megaphone.fill"
        }
    }

    var body: some View {
        HStack(spacing: .spacing8) {
            Image(systemName: iconName)
                .font(.captionRegular)
                .foregroundStyle(isSelected ? Color.accentIndigo : Color.textTertiary)
                .frame(width: 16)

            Text(name)
                .font(.bodySmall)
                .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)

            Spacer()

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
            }

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.captionSmall)
                    .foregroundStyle(Color.accentIndigo)
            }
        }
        .padding(.horizontal, .spacing12)
        .padding(.vertical, .spacing8)
        .background(
            RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                .fill(isSelected ? Color.accentIndigo.opacity(0.15) : Color.clear)
        )
    }
}

#Preview {
    VStack(spacing: 2) {
        ChannelRow(name: "general", isSelected: true)
        ChannelRow(name: "announcements", type: .announcement)
        ChannelRow(name: "voice-chat", type: .voice)
        ChannelRow(name: "staff-only", isLocked: true)
    }
    .padding()
    .background(Color.bgSurface)
}
