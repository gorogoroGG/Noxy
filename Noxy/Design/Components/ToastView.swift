import SwiftUI

enum ToastType {
    case success, warning, error, info

    var icon: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error:   "xmark.circle.fill"
        case .info:    "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: .accentGreen
        case .warning: .accentOrange
        case .error:   .accentPink
        case .info:    .accentIndigo
        }
    }
}

struct ToastMessage: Equatable, Identifiable {
    let id = UUID()
    let type: ToastType
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.type == rhs.type &&
        lhs.message == rhs.message &&
        lhs.actionTitle == rhs.actionTitle
    }
}

struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: .spacing12) {
            Image(systemName: toast.type.icon)
                .foregroundStyle(toast.type.color)
                .font(.titleMedium)

            Text(toast.message)
                .font(.bodySmall)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            if let actionTitle = toast.actionTitle, let action = toast.action {
                Button(actionTitle) {
                    action()
                }
                .font(.bodySmall)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentIndigo)
            }
        }
        .padding(.horizontal, .spacing16)
        .padding(.vertical, .spacing12)
        .background(Color.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
        .padding(.horizontal, .spacing16)
    }
}

struct ToastContainerModifier: ViewModifier {
    @Binding var toast: ToastMessage?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let toast {
                ToastView(toast: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, .spacing24)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(.spring()) {
                                self.toast = nil
                            }
                        }
                    }
            }
        }
        .animation(.spring(), value: toast)
    }
}

extension View {
    func toast(_ toast: Binding<ToastMessage?>) -> some View {
        modifier(ToastContainerModifier(toast: toast))
    }
}

#Preview {
    VStack(spacing: .spacing12) {
        ToastView(toast: ToastMessage(type: .success, message: "Embed sent successfully!"))
        ToastView(toast: ToastMessage(type: .warning, message: "Rate limit approaching"))
        ToastView(toast: ToastMessage(type: .error,   message: "Failed to connect to bot"))
        ToastView(toast: ToastMessage(type: .info,    message: "3 new notifications"))
    }
    .padding()
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
