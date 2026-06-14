import SwiftUI

// MARK: - List

struct AutoResponsesListView: View {
    let guildId: String
    @Environment(\.services) private var services
    @State private var responses: [AutoResponse] = []
    @State private var isLoading = true
    @State private var showEditor = false
    @State private var editingResponse: AutoResponse? = nil
    @State private var toast: ToastMessage? = nil

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if responses.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle("自動返信")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingResponse = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showEditor, onDismiss: { editingResponse = nil }) {
            AutoResponseEditorView(guildId: guildId, existing: editingResponse) { saved in
                withAnimation {
                    if let idx = responses.firstIndex(where: { $0.id == saved.id }) {
                        responses[idx] = saved
                    } else {
                        responses.insert(saved, at: 0)
                    }
                }
                toast = ToastMessage(type: .success, message: "保存しました")
            }
            .id(editingResponse?.id ?? "new-auto-response")
        }
        .toast($toast)
        .task { await loadResponses() }
    }

    // MARK: List

    private var list: some View {
        List {
            ForEach($responses) { $response in
                AutoResponseRow(response: $response) { enabled in
                    Task { try? await services.autoResponses.toggle(id: response.id, enabled: enabled) }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editingResponse = response
                    showEditor = true
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation { deleteResponse(response) }
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: .spacing24) {
            Spacer()
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.textTertiary)
            VStack(spacing: .spacing8) {
                Text("自動返信がありません")
                    .font(.titleLarge)
                    .foregroundStyle(Color.textPrimary)
                Text("キーワードへの返信を自動化できます。")
                    .font(.bodySmall)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                editingResponse = nil
                showEditor = true
            } label: {
                Text("最初の返信を追加")
                    .font(.bodyRegular)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.accentIndigo)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: Data

    private func loadResponses() async {
        responses = (try? await services.autoResponses.fetchAll(guildId: guildId)) ?? []
        isLoading = false
    }

    private func deleteResponse(_ r: AutoResponse) {
        Task {
            try? await services.autoResponses.delete(id: r.id)
            responses.removeAll { $0.id == r.id }
        }
    }
}

// MARK: - Row

private struct AutoResponseRow: View {
    @Binding var response: AutoResponse
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: .spacing12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(response.trigger)
                    .font(.bodyRegular)
                    .fontWeight(.semibold)
                    .foregroundStyle(response.enabled ? Color.textPrimary : Color.textTertiary)

                Text(response.response)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { response.enabled },
                set: { response.enabled = $0; onToggle($0) }
            ))
            .labelsHidden()
            .tint(Color.accentIndigo)
        }
        .padding(.vertical, .spacing4)
    }
}

// MARK: - Editor

struct AutoResponseEditorView: View {
    let guildId: String
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    // 基本
    @State private var trigger: String
    @State private var response: String

    // 権限
    @State private var allUsersAllowed: Bool
    @State private var selectedRoles: Set<String>

    // 詳細設定
    @State private var showAdvanced = false
    @State private var cooldownIndex: Int
    @State private var enabled: Bool

    private let existingId: String?
    let onSave: (AutoResponse) -> Void

    // クールダウン選択肢
    private let cooldownOptions: [(Int, String)] = [
        (0, "なし"), (5, "5秒"), (30, "30秒"), (60, "1分"), (300, "5分")
    ]

    // モックロール（実際はサーバーから取得）
    private let mockRoles: [(id: String, name: String, color: Color)] = [
        ("admin", "Admin",     .accentPink),
        ("mod",   "Moderator", .accentOrange),
        ("staff", "Staff",     .accentIndigo),
        ("vip",   "VIP",       .accentPurple),
        ("member","Member",    .accentGreen),
    ]

    init(guildId: String, existing: AutoResponse? = nil, onSave: @escaping (AutoResponse) -> Void) {
        self.guildId    = guildId
        self.existingId = existing?.id
        self.onSave     = onSave

        _trigger          = State(initialValue: existing?.trigger ?? "")
        _response         = State(initialValue: existing?.response ?? "")
        _allUsersAllowed  = State(initialValue: true)
        _selectedRoles    = State(initialValue: [])
        _enabled          = State(initialValue: existing?.enabled ?? true)

        // cooldown を index に変換
        let sec = existing?.cooldownSeconds ?? 0
        let idx = [(0, ""), (5, ""), (30, ""), (60, ""), (300, "")]
            .firstIndex(where: { $0.0 == sec }) ?? 0
        _cooldownIndex = State(initialValue: idx)
    }

    private var isValid: Bool {
        !trigger.trimmingCharacters(in: .whitespaces).isEmpty &&
        !response.trimmingCharacters(in: .whitespaces).isEmpty &&
        (allUsersAllowed || !selectedRoles.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── キーワード ──
                Section {
                    TextField("例: ルール", text: $trigger)
                        .font(.bodyRegular)
                } header: {
                    HStack(spacing: 3) {
                        Text("キーワード")
                        Text("*").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.Color.statusBad)
                    }
                } footer: {
                    Text("メッセージがこのキーワードと完全一致したとき返信します。")
                }

                // ── 返信テキスト ──
                Section {
                    TextField("返信内容を入力...", text: $response, axis: .vertical)
                        .font(.bodyRegular)
                        .lineLimit(3...8)
                    variableHints
                } header: {
                    HStack(spacing: 3) {
                        Text("返信")
                        Text("*").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.Color.statusBad)
                    }
                }

                // ── 権限 ──
                Section {
                    Toggle("全員が実行可能", isOn: $allUsersAllowed.animation())
                        .tint(Color.accentIndigo)

                    if !allUsersAllowed {
                        roleSelector
                    }
                } header: {
                    Text("権限")
                } footer: {
                    if !allUsersAllowed && selectedRoles.isEmpty {
                        Text("ロールを1つ以上選択してください。")
                            .foregroundStyle(Color.accentPink)
                    } else if !allUsersAllowed {
                        Text("選択されたロールのメンバーのみが実行できます。")
                    }
                }

                // ── 詳細設定 ──
                Section {
                    DisclosureGroup(isExpanded: $showAdvanced) {
                        Picker("クールダウン", selection: $cooldownIndex) {
                            ForEach(cooldownOptions.indices, id: \.self) { i in
                                Text(cooldownOptions[i].1).tag(i)
                            }
                        }
                        Toggle("有効", isOn: $enabled)
                            .tint(Color.accentIndigo)
                    } label: {
                        Text("詳細設定")
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }
            .navigationTitle(existingId == nil ? "新規返信" : "返信を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }

    // MARK: Role selector

    private var roleSelector: some View {
        ForEach(mockRoles, id: \.id) { role in
            HStack {
                Circle()
                    .fill(role.color)
                    .frame(width: 10, height: 10)
                Text("@\(role.name)")
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                if selectedRoles.contains(role.id) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentIndigo)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if selectedRoles.contains(role.id) {
                        selectedRoles.remove(role.id)
                    } else {
                        selectedRoles.insert(role.id)
                    }
                }
            }
        }
    }

    // MARK: Variable hints

    private var variableHints: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .spacing8) {
                ForEach(["{user}", "{server}", "{channel}"], id: \.self) { variable in
                    Button {
                        response += variable
                    } label: {
                        Text(variable)
                            .font(.caption)
                            .foregroundStyle(Color.accentIndigo)
                            .padding(.horizontal, .spacing8)
                            .padding(.vertical, 4)
                            .background(Color.accentIndigo.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: Save

    private func save() {
        let cooldownSec = cooldownOptions[cooldownIndex].0
        let item = AutoResponse(
            id: existingId ?? UUID().uuidString,
            guildId: guildId,
            trigger: trigger.trimmingCharacters(in: .whitespaces),
            response: response,
            matchType: .exact,
            enabled: enabled,
            cooldownSeconds: cooldownSec,
            channelIds: []
        )
        Task {
            let saved: AutoResponse
            if existingId != nil {
                saved = (try? await services.autoResponses.update(item)) ?? item
            } else {
                saved = (try? await services.autoResponses.create(item)) ?? item
            }
            onSave(saved)
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        AutoResponsesListView(guildId: "g001")
    }
    .environment(\.services, ServiceContainer.live())
}
