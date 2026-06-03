import SwiftUI

enum ButtonStyle_: Equatable {
    case filled, outlined, ghost
}

enum ButtonSize: Equatable {
    case large, medium, small

    var height: CGFloat {
        switch self {
        case .large:  56
        case .medium: 44
        case .small:  32
        }
    }

    var font: Font {
        switch self {
        case .large:  .titleMedium
        case .medium: .bodyRegular
        case .small:  .captionRegular
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .large:  .spacing24
        case .medium: .spacing16
        case .small:  .spacing12
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var style: ButtonStyle_ = .filled
    var size: ButtonSize = .medium
    var icon: String? = nil
    var iconPosition: IconPosition = .leading
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    enum IconPosition { case leading, trailing }

    init(_ title: String, style: ButtonStyle_ = .filled, size: ButtonSize = .medium,
         icon: String? = nil, iconPosition: IconPosition = .leading,
         isLoading: Bool = false, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.size = size
        self.icon = icon
        self.iconPosition = iconPosition
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    private var foregroundColor: Color {
        switch style {
        case .filled:   .white
        case .outlined: .accentIndigo
        case .ghost:    .accentIndigo
        }
    }

    private var backgroundView: some View {
        Group {
            switch style {
            case .filled:
                RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                    .fill(Color.accentIndigo)
            case .outlined:
                RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                    .strokeBorder(Color.accentIndigo, lineWidth: 1.5)
            case .ghost:
                RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                    .fill(Color.clear)
            }
        }
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            ZStack {
                backgroundView

                HStack(spacing: .spacing8) {
                    if isLoading {
                        ProgressView()
                            .tint(foregroundColor)
                            .scaleEffect(0.8)
                    } else {
                        if let icon, iconPosition == .leading {
                            Image(systemName: icon)
                                .font(size.font)
                        }

                        Text(title)
                            .font(size.font)
                            .fontWeight(.semibold)

                        if let icon, iconPosition == .trailing {
                            Image(systemName: icon)
                                .font(size.font)
                        }
                    }
                }
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, size.horizontalPadding)
            }
            .frame(height: size.height)
        }
        .buttonStyle(ScalePressButtonStyle())
        .disabled(isDisabled || isLoading)
        .opacity((isDisabled || isLoading) ? 0.5 : 1)
    }
}

struct ScalePressButtonStyle: SwiftUI.ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: .spacing16) {
        PrimaryButton("Send", style: .filled, icon: "paperplane.fill") {}
        PrimaryButton("Outlined", style: .outlined, icon: "plus") {}
        PrimaryButton("Ghost", style: .ghost) {}
        PrimaryButton("Large", style: .filled, size: .large, icon: "bolt.fill") {}
        PrimaryButton("Small", style: .filled, size: .small) {}
        PrimaryButton("Loading", style: .filled, isLoading: true) {}
        PrimaryButton("Disabled", style: .filled, isDisabled: true) {}
    }
    .padding()
    .background(Color.bgPrimary)
}
