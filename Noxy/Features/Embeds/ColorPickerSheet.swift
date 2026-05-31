import SwiftUI

struct ColorPickerSheet: View {
    @Binding var selectedHex: UInt32
    @Environment(\.dismiss) private var dismiss
    @State private var hexInput: String = ""
    @State private var hexError = false
    @State private var nativeColor: Color = .accentIndigo

    private let presets: [(String, UInt32)] = [
        ("Indigo",  0x5865F2), ("Pink",   0xEC4899), ("Purple", 0x7C3AED),
        ("Green",   0x23A55A), ("Orange", 0xF59E0B), ("Red",    0xEF4444),
        ("Teal",    0x14B8A6), ("Blue",   0x3B82F6), ("Yellow", 0xEAB308),
        ("Gray",    0x6B7280), ("White",  0xFFFFFF), ("Black",  0x111827),
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: .spacing24) {
                // Current color preview
                HStack(spacing: .spacing16) {
                    RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                        .fill(Color(uiColor: UIColor(hex: selectedHex)))
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                                .strokeBorder(Color.border, lineWidth: 1)
                        )
                    VStack(alignment: .leading) {
                        Text("選択中のカラー")
                            .font(.titleMedium)
                            .foregroundStyle(Color.textPrimary)
                        Text(String(format: "#%06X", selectedHex))
                            .font(.mono)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .padding(.horizontal)

                // Native ColorPicker
                VStack(alignment: .leading, spacing: .spacing8) {
                    Text("カラーピッカー".uppercased())
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
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
                VStack(alignment: .leading, spacing: .spacing12) {
                    Text("プリセット".uppercased())
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                        .tracking(0.8)
                        .padding(.horizontal)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: .spacing8), count: 6),
                        spacing: .spacing8
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
                                                .font(.captionSmall)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                // Custom HEX input
                VStack(alignment: .leading, spacing: .spacing8) {
                    Text("カスタムHEX".uppercased())
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                        .tracking(0.8)

                    HStack(spacing: .spacing8) {
                        Text("#")
                            .font(.mono)
                            .foregroundStyle(Color.textSecondary)

                        TextField("5865F2", text: $hexInput)
                            .font(.mono)
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
                                    .foregroundStyle(Color.textTertiary)
                            }
                        }
                    }
                    .padding(.spacing12)
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                            .strokeBorder(hexError ? Color.accentPink : Color.clear, lineWidth: 1)
                    )

                    if hexError {
                        Text("無効なHEXカラーです")
                            .font(.captionSmall)
                            .foregroundStyle(Color.accentPink)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, .spacing24)
            .background(Color.bgPrimary)
            .navigationTitle("カラーを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentIndigo)
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
        .preferredColorScheme(.dark)
}
