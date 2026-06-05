import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("colorScheme") private var colorScheme = "System"
    @AppStorage("accentColorIndex") private var accentColorIndex = 0
    @AppStorage("fontSizeOffset") private var fontSizeOffset: Double = 0
    @AppStorage("reduceMotion") private var reduceMotion = false
    @AppStorage("highContrast") private var highContrast = false

    private let schemes = ["ライト", "ダーク", "システム"]
    private let accentColors: [(String, Color)] = [
        ("Indigo", .accentIndigo), ("Pink", .accentPink), ("Purple", .accentPurple),
        ("Green", .accentGreen), ("Orange", .accentOrange),
        ("Red", .accentRed),
        ("Teal", Color(uiColor: UIColor(hex: 0x14B8A6))),
        ("Yellow", Color(uiColor: UIColor(hex: 0xEAB308))),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing16) {
                FormSection("テーマ", icon: "paintbrush") {
                    Picker("外観", selection: $colorScheme) {
                        ForEach(schemes, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .inputStyle(height: 44)
                }

                FormSection("アクセントカラー", icon: "paintpalette") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: .spacing12) {
                        ForEach(Array(accentColors.enumerated()), id: \.offset) { index, item in
                            Circle()
                                .fill(item.1)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if accentColorIndex == index {
                                        Image(systemName: "checkmark")
                                            .font(.captionSmall)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { accentColorIndex = index }
                        }
                    }
                    .padding(.vertical, .spacing8)
                }

                FormSection("フォントサイズ", icon: "textformat.size") {
                    VStack(alignment: .leading, spacing: .spacing8) {
                        HStack {
                            Text("A").font(.captionRegular)
                            Slider(value: $fontSizeOffset, in: -2...4, step: 1)
                                .tint(Color.accentIndigo)
                            Text("A").font(.titleLarge)
                        }
                        Text("プレビュー: 素早い茶色の狐が怠惰な犬を飛び越えた。")
                            .font(.system(size: 17 + fontSizeOffset))
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                FormSection("アクセシビリティ", icon: "accessibility") {
                    VStack(spacing: .spacing8) {
                        FormField.toggle(label: "モーションを減らす", isOn: $reduceMotion)
                        FormField.toggle(label: "高コントラスト", isOn: $highContrast)
                    }
                }

                FormSection("プレビュー", icon: "eye.fill") {
                    VStack(alignment: .leading, spacing: .spacing8) {
                        HStack(spacing: .spacing8) {
                            ServerIconView(name: "Valorant JP", size: 40)
                            VStack(alignment: .leading) {
                                Text("Valorant JP").font(.titleMedium).foregroundStyle(Color.textPrimary)
                                Text("1,234 メンバー").font(.captionRegular).foregroundStyle(Color.textSecondary)
                            }
                        }
                        PrimaryButton("Embedを作成", style: .filled, size: .medium) {}
                    }
                }
            }
            .padding(.spacing16)
            .padding(.bottom, 24)
        }
        .background(Color.bgPrimary)
        .navigationTitle("外観")
    }
}

#Preview {
    NavigationStack { AppearanceSettingsView() }
}
