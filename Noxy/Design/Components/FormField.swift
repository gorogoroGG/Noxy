import SwiftUI

// MARK: - FormField
// ラベル + 入力要素を統一したフォーム行。ScrollView+VStack+Card 内で使用する。
// label は uppercase + textTertiary で常に同じ見た目。

struct FormField: View {
    let label: String
    let isRequired: Bool
    let helper: String?
    let content: AnyView

    init(
        label: String,
        isRequired: Bool = false,
        helper: String? = nil,
        @ViewBuilder content: () -> some View
    ) {
        self.label = label
        self.isRequired = isRequired
        self.helper = helper
        self.content = AnyView(content())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Label row
            HStack(spacing: Theme.Spacing.xs) {
                Text(label)
                    .font(Theme.Font.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Color.textTertiary)
                    .textCase(.uppercase)

                if isRequired {
                    Text("*")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Color.statusBad)
                }
            }

            // Input
            content

            // Helper
            if let helper {
                Text(helper)
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
            }
        }
    }
}

// MARK: - Input Style

extension View {
    /// 統一テキスト入力スタイル。bgElevated + cornerRadiusSmall + 内側余白。
    func inputStyle(height: CGFloat? = nil) -> some View {
        self
            .font(Theme.Font.bodySmall)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .frame(height: height, alignment: .leading)
            .background(Theme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
    }

    /// Embed エディタ専用：薄い点線で入力エリアを囲う。テキストに合わせて動的にサイズ変化。
    func embedDashedBorder(radius: CGFloat = 5, focused: Bool = false) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: radius)
                .stroke(
                    style: StrokeStyle(lineWidth: focused ? 1.2 : 0.8,
                                       dash: focused ? [1, 0] : [4, 3])
                )
                .foregroundStyle(
                    focused
                        ? Theme.Color.accent.opacity(0.55)
                        : Theme.Color.accent.opacity(0.28)
                )
        )
        .padding(2)
    }
}

// MARK: - Presets

extension FormField {
    // MARK: Text

    static func text(
        label: String,
        text: Binding<String>,
        placeholder: String = "",
        isRequired: Bool = false,
        axis: Axis? = nil,
        helper: String? = nil
    ) -> FormField {
        FormField(label: label, isRequired: isRequired, helper: helper) {
            if let axis {
                TextField(placeholder, text: text, axis: axis)
                    .inputStyle()
            } else {
                TextField(placeholder, text: text)
                    .inputStyle()
            }
        }
    }

    // MARK: Editor

    static func editor(
        label: String,
        text: Binding<String>,
        placeholder: String = "",
        isRequired: Bool = false,
        helper: String? = nil
    ) -> FormField {
        FormField(label: label, isRequired: isRequired, helper: helper) {
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(Theme.Font.bodySmall)
                        .foregroundStyle(Theme.Color.textTertiary)
                        .padding(.top, 10).padding(.leading, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: text)
                    .font(Theme.Font.bodySmall)
                    .scrollContentBackground(.hidden)
                    .inputStyle(height: 100)
            }
        }
    }

    // MARK: Toggle

    static func toggle(
        label: String,
        isOn: Binding<Bool>,
        helper: String? = nil
    ) -> FormField {
        FormField(label: label, helper: helper) {
            HStack {
                Spacer()
                Toggle("", isOn: isOn)
                    .tint(Theme.Color.accent)
                    .labelsHidden()
            }
            .inputStyle(height: 44)
        }
    }

    // MARK: Picker

    static func picker<
        SelectionValue: Hashable
    >(
        label: String,
        selection: Binding<SelectionValue>,
        helper: String? = nil,
        @ViewBuilder content: () -> some View
    ) -> FormField {
        FormField(label: label, helper: helper) {
            Picker("", selection: selection) {
                content()
            }
            .pickerStyle(.menu)
            .inputStyle(height: 44)
        }
    }

    // MARK: Stepper

    static func stepper(
        label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        helper: String? = nil
    ) -> FormField {
        FormField(label: label, helper: helper) {
            HStack {
                Spacer()
                Stepper(value: value, in: range) {
                    Text("\(value.wrappedValue)")
                        .font(Theme.Font.bodySmall)
                        .foregroundStyle(Color.textPrimary)
                }
            }
            .inputStyle(height: 44)
        }
    }

    // MARK: Menu Button

    static func menu(
        label: String,
        helper: String? = nil,
        @ViewBuilder labelView: () -> some View,
        @ViewBuilder content: () -> some View
    ) -> FormField {
        FormField(label: label, helper: helper) {
            Menu {
                content()
            } label: {
                labelView()
            }
            .inputStyle(height: 44)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Theme.Spacing.md) {
            FormSection("基本設定", icon: "gear") {
                VStack(spacing: Theme.Spacing.sm) {
                    FormField.text(label: "タイトル", text: .constant(""), placeholder: "タイトルを入力", isRequired: true)
                    FormField.editor(label: "説明", text: .constant(""), placeholder: "説明を入力...")
                    FormField.toggle(label: "有効化", isOn: .constant(true))
                    FormField.stepper(label: "最大数", value: .constant(3), range: 1...10)
                }
            }
        }
        .padding(Theme.Spacing.md)
    }
    .background(Color.bgPrimary)
}
