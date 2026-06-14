import SwiftUI

// MARK: - Card
// アプリ内すべてのカードUIを統一するコンテナ。
// bgSurface背景、continuous角丸、オプションのボーダーとシャドウ。

struct Card: View {
    let padding: CGFloat
    let background: Color
    let cornerRadius: CGFloat
    let showBorder: Bool
    let shadow: ShadowStyle?
    let content: AnyView

    enum ShadowStyle {
        case small   // radius: 4,  y: 2,  opacity: 0.05
        case medium  // radius: 8,  y: 4,  opacity: 0.08
        case large   // radius: 16, y: 8,  opacity: 0.12
    }

    init(
        padding: CGFloat = Theme.Spacing.sm,
        background: Color = Theme.Color.surface,
        cornerRadius: CGFloat = Theme.Radius.card,
        showBorder: Bool = false,
        shadow: ShadowStyle? = nil,
        @ViewBuilder content: () -> some View
    ) {
        self.padding = padding
        self.background = background
        self.cornerRadius = cornerRadius
        self.showBorder = showBorder
        self.shadow = shadow
        self.content = AnyView(content())
    }

    var body: some View {
        content
            .padding(padding)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                showBorder
                ? RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Color.line, lineWidth: 1)
                : nil
            )
            .shadow(
                color: shadowColor.opacity(shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
    }

    // MARK: - Shadow Values

    private var shadowColor: Color { .black }
    private var shadowRadius: CGFloat {
        switch shadow {
        case .small: 4
        case .medium: 8
        case .large: 16
        case .none: 0
        }
    }
    private var shadowOpacity: CGFloat {
        switch shadow {
        case .small: 0.05
        case .medium: 0.08
        case .large: 0.12
        case .none: 0
        }
    }
    private var shadowY: CGFloat {
        switch shadow {
        case .small: 2
        case .medium: 4
        case .large: 8
        case .none: 0
        }
    }
}

// MARK: - FormSection
// Card + セクションヘッダー（アイコン・タイトル）+ オプションのフッター。
// 最も頻出する「セクション化されたカード」を1行で書ける。

struct FormSection: View {
    let title: String
    let icon: String?
    let isRequired: Bool
    let footer: String?
    let shadow: Card.ShadowStyle?
    let content: AnyView

    init(
        _ title: String,
        icon: String? = nil,
        isRequired: Bool = false,
        footer: String? = nil,
        shadow: Card.ShadowStyle? = nil,
        @ViewBuilder content: () -> some View
    ) {
        self.title = title
        self.icon = icon
        self.isRequired = isRequired
        self.footer = footer
        self.shadow = shadow
        self.content = AnyView(content())
    }

    var body: some View {
        Card(shadow: shadow) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                // Header
                HStack(spacing: Theme.Spacing.xs) {
                    if let icon {
                        Image(systemName: icon)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                    Text(title)
                        .font(Theme.Font.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Color.textTertiary)
                        .textCase(.uppercase)
                    if isRequired {
                        Text("*")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.Color.statusBad)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Content
                content

                // Footer
                if let footer {
                    Text(footer)
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Theme.Spacing.md) {
            Card {
                Text("シンプルカード").font(Theme.Font.body)
            }
            Card(showBorder: true) {
                Text("ボーダー付き").font(Theme.Font.body)
            }
            Card(shadow: .medium) {
                Text("シャドウ付き").font(Theme.Font.body)
            }
            FormSection("基本設定", icon: "gear", footer: "変更は即座に反映されます") {
                Text("内容").font(Theme.Font.body)
            }
        }
        .padding(Theme.Spacing.md)
    }
    .background(Theme.Color.bg)
}
