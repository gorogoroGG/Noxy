import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("colorScheme") private var colorScheme = "システム"

    private let schemes = ["ライト", "ダーク", "システム"]

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                FormSection("テーマ", icon: "paintbrush") {
                    Picker("外観", selection: $colorScheme) {
                        ForEach(schemes, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .inputStyle(height: 44)
                }

                FormSection("プレビュー", icon: "eye") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack(spacing: Theme.Spacing.sm) {
                            ServerIconView(name: "Valorant JP", size: 40)
                            VStack(alignment: .leading) {
                                Text("Valorant JP")
                                    .font(Theme.Font.bodyMedium)
                                    .foregroundStyle(Theme.Color.textPrimary)
                                Text("1,234 メンバー")
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Color.textSecondary)
                                    .monospaced()
                            }
                        }
                        Button {} label: {
                            Text("Embedを作成")
                                .font(Theme.Font.bodyMedium)
                                .foregroundStyle(Theme.Color.accentInk)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.xs)
                                .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .padding(.bottom, 24)
        }
        .background(Theme.Color.bg)
        .navigationTitle("外観")
    }
}

#Preview {
    NavigationStack { AppearanceSettingsView() }
}

#Preview("Dark") {
    NavigationStack { AppearanceSettingsView() }
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    NavigationStack { AppearanceSettingsView() }
        .preferredColorScheme(.light)
}
