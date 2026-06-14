import SwiftUI

struct ColorPickerSheet: View {
    @Binding var selectedHex: UInt32
    @Environment(\.dismiss) private var dismiss
    @State private var hexInput: String = ""
    @State private var hexError = false
    @State private var nativeColor: Color = Theme.Color.accent

    private let presets: [(String, UInt32)] = [
        ("Indigo",  0x5865F2), ("Pink",   0xEC4899), ("Purple", 0x7C3AED),
        ("Green",   0x23A55A), ("Orange", 0xF59E0B), ("Red",    0xEF4444),
        ("Teal",    0x14B8A6), ("Blue",   0x3B82F6), ("Yellow", 0xEAB308),
        ("Gray",    0x6B7280), ("White",  0xFFFFFF), ("Black",  0x111827),
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                // Current color preview
                HStack(spacing: Theme.Spacing.md) {
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .fill(Color(uiColor: UIColor(hex: selectedHex)))
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.card)
                                .strokeBorder(Theme.Color.line, lineWidth: 1)
                        )
                    VStack(alignment: .leading) {
                        Text("選択中のカラー")
                            .font(Theme.Font.title3)
                            .foregroundStyle(Theme.Color.textPrimary)
                        Text(String(format: "#%06X", selectedHex))
                            .font(Theme.Font.mono)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                }
                .padding(.horizontal)

                // Native ColorPicker
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("カラーピッカー".uppercased())
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                        .tracking(0.8)
                        .padding(.horizontal)

                    ColorPicker("色を選択", selection: $nativeColor)
                        .padding(.horizontal)
                        .onChange(of: nativeColor) { _, new in
                            if let hex = new.toHex() {
                                selectedHex = hex
                                hexInput = String(format: "%06X", hex)
                            }
                        }
                }

                // Presets grid
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("プリセット".uppercased())
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                        .tracking(0.8)
                        .padding(.horizontal)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.xs), count: 6),
                        spacing: Theme.Spacing.xs
                    ) {
                        ForEach(presets, id: \.1) { name, hex in
                            Button {
                                selectedHex = hex
                                hexInput = String(format: "%06X", hex)
                                nativeColor = Color(uiColor: UIColor(hex: hex))
                            } label: {
                                Circle()
                                    .fill(Color(uiColor: UIColor(hex: hex)))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        if selectedHex == hex {
                                            Image(systemName: "checkmark")
                                                .font(Theme.Font.caption2)
                                                .fontWeight(.bold)
                                                .foregroundStyle(Theme.Color.accentInk)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                // Custom HEX input
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("カスタムHEX".uppercased())
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                        .tracking(0.8)

                    HStack(spacing: Theme.Spacing.xs) {
                        Text("#")
                            .font(Theme.Font.mono)
                            .foregroundStyle(Theme.Color.textSecondary)

                        TextField("5865F2", text: $hexInput)
                            .font(Theme.Font.mono)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onChange(of: hexInput) { _, new in
                                applyHexInput(new)
                            }

                        if !hexInput.isEmpty {
                            Button {
                                hexInput = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Theme.Color.textTertiary)
                            }
                        }
                    }
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.button)
                            .strokeBorder(hexError ? Theme.Color.statusBad : Color.clear, lineWidth: 1)
                    )

                    if hexError {
                        Text("無効なHEXカラーです")
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.statusBad)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, Theme.Spacing.xl)
            .background(Theme.Color.bg)
            .navigationTitle("カラーを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Color.accent)
                }
            }
            .onAppear {
                hexInput = String(format: "%06X", selectedHex)
                nativeColor = Color(uiColor: UIColor(hex: selectedHex))
            }
        }
    }

    private func applyHexInput(_ input: String) {
        let clean = input.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .uppercased()
            .filter { $0.isHexDigit }
            .prefix(6)
            .description

        if clean.count == 6, let value = UInt32(clean, radix: 16) {
            selectedHex = value
            hexError = false
            nativeColor = Color(uiColor: UIColor(hex: value))
        } else if clean.count == 6 {
            hexError = true
        } else {
            hexError = false
        }
    }
}

// MARK: - Color Hex Conversion
private extension Color {
    func toHex() -> UInt32? {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb = (UInt32(r * 255) << 16) | (UInt32(g * 255) << 8) | UInt32(b * 255)
        return rgb
    }
}

#Preview {
    ColorPickerSheet(selectedHex: .constant(0x5865F2))
}
