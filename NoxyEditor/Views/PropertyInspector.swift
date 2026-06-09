import SwiftUI

struct EditableProperty: Identifiable {
    let id = UUID()
    let name: String
    let key: String
    var value: String
    let type: PropertyType

    enum PropertyType {
        case text
        case number
        case color
        case boolean
        case `enum`(cases: [String])
    }
}

struct PropertyInspector: View {
    @State private var editorState = EditorState.shared
    @State private var properties: [EditableProperty] = []

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Label("プロパティ", systemImage: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textSecondary)
                Spacer()
                if !editorState.changes.isEmpty {
                    Text("\(editorState.changes.count)件の変更")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.accentIndigo)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if let selectedPath = editorState.selectedComponentPath {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // コンポーネント名
                        HStack(spacing: 6) {
                            Image(systemName: "square.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.accentIndigo)
                            Text(selectedPath.components(separatedBy: "/").last ?? selectedPath)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.textPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)

                        Text(selectedPath)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.textTertiary)
                            .lineLimit(2)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)

                        Divider()

                        if properties.isEmpty {
                            emptyPropertiesView
                        } else {
                            VStack(spacing: 1) {
                                ForEach($properties) { $prop in
                                    PropertyRow(property: $prop, componentPath: selectedPath)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.bottom, 16)
                }
            } else {
                emptySelectionView
            }
        }
        .frame(minWidth: 260)
        .onChange(of: editorState.selectedComponentPath) { _, newPath in
            updateProperties(for: newPath)
        }
    }

    private var emptySelectionView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "cursorarrow.click")
                .font(.system(size: 28))
                .foregroundColor(.textTertiary)
            Text("コンポーネントを選択")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
            Text("左パネルからコンポーネントを\nクリックしてください")
                .font(.system(size: 11))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyPropertiesView: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.dashed")
                .font(.system(size: 22))
                .foregroundColor(.textTertiary)
            Text("プロパティなし")
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func updateProperties(for path: String?) {
        guard let path else { properties = []; return }
        switch path {
        case "RootView/MainTabView/Dashboard/Header/WelcomeCard":
            properties = [
                EditableProperty(name: "タイトル",     key: "welcome_title",    value: "Welcome back!", type: .text),
                EditableProperty(name: "サブタイトル",  key: "welcome_subtitle", value: "My Server",     type: .text),
                EditableProperty(name: "背景カラー",    key: "welcome_bg_color", value: "#5856D6",       type: .color),
            ]
        case "RootView/MainTabView/Dashboard/Header/ServerSelector":
            properties = [
                EditableProperty(name: "サーバー名",   key: "server_name",    value: "My Server", type: .text),
                EditableProperty(name: "ドロップダウン", key: "show_dropdown", value: "true",      type: .boolean),
            ]
        case "RootView/MainTabView/Dashboard/QuickActions":
            properties = [
                EditableProperty(name: "タイトル",     key: "quick_actions_title",  value: "クイックアクション",                           type: .text),
                EditableProperty(name: "最大表示数",   key: "quick_actions_max",    value: "8",                                             type: .number),
                EditableProperty(name: "レイアウト",   key: "quick_actions_layout", value: "Grid", type: .enum(cases: ["Grid", "List", "Carousel"])),
            ]
        case "RootView/MainTabView/Dashboard/StatsGrid":
            properties = [
                EditableProperty(name: "カラム数",      key: "stats_columns",      value: "2",    type: .number),
                EditableProperty(name: "ラベル表示",    key: "stats_show_labels",  value: "true", type: .boolean),
            ]
        case "RootView/MainTabView/Dashboard/Notifications":
            properties = [
                EditableProperty(name: "タイトル",     key: "notifications_title", value: "お知らせ", type: .text),
                EditableProperty(name: "最大表示数",   key: "notifications_max",   value: "5",        type: .number),
            ]
        default:
            properties = [
                EditableProperty(name: "コンポーネント名", key: "component_name",
                                 value: path.components(separatedBy: "/").last ?? "", type: .text),
            ]
        }
    }
}

// MARK: - PropertyRow

struct PropertyRow: View {
    @Binding var property: EditableProperty
    let componentPath: String
    @State private var editorState = EditorState.shared
    @State private var localValue: String
    @State private var originalValue: String   // 最初のスナップショット値

    init(property: Binding<EditableProperty>, componentPath: String) {
        self._property    = property
        self.componentPath = componentPath
        let initial = property.wrappedValue.value
        self._localValue    = State(initialValue: initial)
        self._originalValue = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(property.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textSecondary)
                Spacer()
                if localValue != originalValue {
                    Circle()
                        .fill(Color.accentIndigo)
                        .frame(width: 6, height: 6)
                }
            }

            propertyControl
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            localValue != originalValue
                ? Color.accentIndigo.opacity(0.06)
                : Color.bgSurface
        )
        .overlay(alignment: .leading) {
            if localValue != originalValue {
                Rectangle()
                    .fill(Color.accentIndigo)
                    .frame(width: 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 10)
    }

    @ViewBuilder
    private var propertyControl: some View {
        switch property.type {
        case .text, .number:
            TextField("", text: $localValue)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .onChange(of: localValue) { _, newValue in
                    recordChange(newValue)
                }

        case .color:
            HStack(spacing: 8) {
                TextField("", text: $localValue)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .onChange(of: localValue) { _, newValue in
                        recordChange(newValue)
                    }
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(hex: localValue) ?? Color.accentIndigo)
                    .frame(width: 28, height: 28)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.border, lineWidth: 1))
            }

        case .boolean:
            Toggle("", isOn: Binding(
                get: { localValue == "true" },
                set: { newBool in
                    let newStr = newBool ? "true" : "false"
                    localValue = newStr
                    recordChange(newStr)
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)

        case .enum(let cases):
            Picker("", selection: $localValue) {
                ForEach(cases, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: localValue) { _, newValue in
                recordChange(newValue)
            }
        }
    }

    private func recordChange(_ newValue: String) {
        // oldValueはoriginalValue（最初にロードされた値）を使う
        let oldValue = originalValue
        property.value = newValue
        editorState.recordChange(
            componentPath: componentPath,
            propertyName: property.key,
            oldValue: oldValue,
            newValue: newValue
        )
    }
}

// MARK: - Color Hex Extension

extension Color {
    init?(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard sanitized.count == 6 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: sanitized).scanHexInt64(&rgb) else { return nil }
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}
