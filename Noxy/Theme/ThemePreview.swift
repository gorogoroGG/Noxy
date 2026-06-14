import SwiftUI

// MARK: - Token catalog preview (dev-only)

private struct ColorRow: View {
    let name: String
    let color: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Theme.Color.lineStrong, lineWidth: 1)
                )
            Text(name)
                .font(Theme.Font.mono)
                .foregroundStyle(Theme.Color.textPrimary)
            Spacer()
        }
    }
}

private struct TokenSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            SectionLabel(title: title)
            content()
        }
    }
}

struct ThemePreview: View {
    private let colorTokens: [(String, Color)] = [
        ("bg",            Theme.Color.bg),
        ("surface",       Theme.Color.surface),
        ("surfaceRaised", Theme.Color.surfaceRaised),
        ("line",          Theme.Color.line),
        ("lineStrong",    Theme.Color.lineStrong),
        ("textPrimary",   Theme.Color.textPrimary),
        ("textSecondary", Theme.Color.textSecondary),
        ("textTertiary",  Theme.Color.textTertiary),
        ("accent",        Theme.Color.accent),
        ("accentInk",     Theme.Color.accentInk),
        ("accentDim",     Theme.Color.accentDim),
        ("statusOK",      Theme.Color.statusOK),
        ("statusWarn",    Theme.Color.statusWarn),
        ("statusBad",     Theme.Color.statusBad),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {

                TokenSection(title: "カラートークン") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        ForEach(colorTokens, id: \.0) { name, color in
                            ColorRow(name: name, color: color)
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .stroke(Theme.Color.lineStrong, lineWidth: 1)
                    )
                }

                TokenSection(title: "タイポグラフィ") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("title2 Bold").font(Theme.Font.title2).foregroundStyle(Theme.Color.textPrimary)
                        Text("title3 Bold").font(Theme.Font.title3).foregroundStyle(Theme.Color.textPrimary)
                        Text("bodyMedium").font(Theme.Font.bodyMedium).foregroundStyle(Theme.Color.textPrimary)
                        Text("body Regular").font(Theme.Font.body).foregroundStyle(Theme.Color.textPrimary)
                        Text("callout").font(Theme.Font.callout).foregroundStyle(Theme.Color.textSecondary)
                        Text("caption 12pt").font(Theme.Font.caption).foregroundStyle(Theme.Color.textTertiary)
                        Text("caption2 11pt").font(Theme.Font.caption2).foregroundStyle(Theme.Color.textTertiary)
                        SectionLabel(title: "sectionLabel 11pt semibold")
                        MonoText(value: "mono  1234567890")
                        MonoText(value: "monoCap  abc-123", font: Theme.Font.monoCap)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .stroke(Theme.Color.lineStrong, lineWidth: 1)
                    )
                }

                TokenSection(title: "コンポーネント") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        HStack(spacing: Theme.Spacing.sm) {
                            StatusDot(color: Theme.Color.statusOK)
                            Text("オンライン").font(Theme.Font.body).foregroundStyle(Theme.Color.textPrimary)
                            StatusDot(color: Theme.Color.statusWarn)
                            Text("警告").font(Theme.Font.body).foregroundStyle(Theme.Color.textPrimary)
                            StatusDot(color: Theme.Color.statusBad)
                            Text("エラー").font(Theme.Font.body).foregroundStyle(Theme.Color.textPrimary)
                        }

                        HStack(spacing: Theme.Spacing.sm) {
                            AccentButton(title: "実行する", action: {})
                            GhostButton(title: "キャンセル", action: {})
                        }

                        ConfirmModal(
                            icon: "arrow.clockwise.circle.fill",
                            iconColor: Theme.Color.accent,
                            title: "実行しますか？",
                            message: "Botを再起動する",
                            primaryLabel: "実行",
                            primaryRole: nil,
                            onPrimary: {},
                            onCancel: {}
                        )
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .stroke(Theme.Color.lineStrong, lineWidth: 1)
                    )
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Color.bg.ignoresSafeArea())
    }
}

#Preview("Light") {
    ThemePreview()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ThemePreview()
        .preferredColorScheme(.dark)
}
