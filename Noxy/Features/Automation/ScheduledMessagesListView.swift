import SwiftUI

// MARK: - Recurrence & Format Helpers

private func nextOccurrences(from date: Date, rule: RepeatRule, count: Int) -> [Date] {
    guard rule != .none else { return [date] }
    let cal = Calendar.current
    var result: [Date] = []
    var current = date
    for _ in 0 ..< count {
        result.append(current)
        switch rule {
        case .daily:
            current = cal.date(byAdding: .day, value: 1, to: current) ?? current
        case .weekly:
            current = cal.date(byAdding: .day, value: 7, to: current) ?? current
        case .monthly:
            current = cal.date(byAdding: .month, value: 1, to: current) ?? current
        case .none:
            break
        }
    }
    return result
}

private let japaneseDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateFormat = "yyyy年MM月dd日 HH:mm"
    return f
}()

private func japaneseFormattedDate(_ date: Date) -> String {
    japaneseDateFormatter.string(from: date)
}

private func repeatDisplayName(_ rule: RepeatRule) -> String {
    switch rule {
    case .none: "なし"
    case .daily: "毎日"
    case .weekly: "毎週"
    case .monthly: "毎月"
    }
}

// MARK: - ScheduledMessagesListView

struct ScheduledMessagesListView: View {
    private static let pageSize = 10
    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState
    @State private var messages: [ScheduledMessage] = []
    @State private var embeds: [EmbedModel] = []
    @State private var isLoading = true
    @State private var showScheduler = false
    @State private var toast: ToastMessage? = nil
    @State private var selectedTab: ScheduledStatus? = nil
    @State private var detailMessage: ScheduledMessage? = nil
    @State private var showEmbedEditor = false
    @State private var displayCount = 10
    @State private var viewMode: ScheduledViewMode = .list
    @State private var calendarDate = Date()
    @State private var selectedDayPosts: ScheduledDayPosts? = nil

    // Pre-fill params for ScheduleMessageView (reuse)
    @State private var prefillEmbedId: String? = nil
    @State private var prefillChannelId: String? = nil
    // prefillRepeatRule 削除済み（予約投稿は繰り返しなし）

    enum ScheduledViewMode { case list, calendar }

    private var filtered: [ScheduledMessage] {
        guard let tab = selectedTab else { return messages }
        return messages.filter { $0.status == tab }
    }

    private var displayedMessages: [ScheduledMessage] {
        Array(filtered.prefix(displayCount))
    }

    private var hasMore: Bool {
        displayCount < filtered.count
    }

    private var postsByDay: [String: [ScheduledMessage]] {
        Dictionary(grouping: filtered) { scheduledDayKey($0.scheduledFor) }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.bgPrimary)
            } else if messages.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.clock",
                    title: "予約投稿がありません",
                    description: "埋め込みメッセージを指定時刻に送信するよう設定しましょう。",
                    actionTitle: "メッセージを予約"
                ) {
                    clearPrefill()
                    showScheduler = true
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.bgPrimary)
            } else {
                VStack(spacing: 0) {
                    Picker("", selection: $selectedTab) {
                        Text("すべて").tag(nil as ScheduledStatus?)
                        Text("予約済み").tag(ScheduledStatus.pending as ScheduledStatus?)
                        Text("送信済み").tag(ScheduledStatus.sent as ScheduledStatus?)
                        Text("キャンセル").tag(ScheduledStatus.cancelled as ScheduledStatus?)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, .spacing8)

                    switch viewMode {
                    case .list:
                        if filtered.isEmpty {
                            Spacer()
                            Text(emptyMessage)
                                .font(.bodySmall)
                                .foregroundStyle(Color.textTertiary)
                            Spacer()
                        } else {
                            List {
                                ForEach(displayedMessages) { msg in
                                    Button {
                                        detailMessage = msg
                                    } label: {
                                        ScheduledMessageRow(message: msg, embeds: embeds)
                                    }
                                    .buttonStyle(.plain)
                                    .onAppear {
                                        if msg.id == displayedMessages.last?.id && hasMore {
                                            displayCount = min(displayCount + Self.pageSize, filtered.count)
                                        }
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        if msg.status == .pending {
                                            Button(role: .destructive) {
                                                cancelMessage(msg)
                                            } label: {
                                                Label("キャンセル", systemImage: "xmark.circle")
                                            }
                                        }
                                    }
                                }
                                .listRowBackground(Color.bgSurface)
                                .listRowInsets(EdgeInsets(top: .spacing4, leading: .spacing16, bottom: .spacing4, trailing: .spacing16))
                            }
                            .listStyle(.plain)
                            .listRowSpacing(.spacing4)
                            .scrollContentBackground(.hidden)
                        }
                    case .calendar:
                        scheduledCalendarView
                    }
                }
                .background(Color.bgPrimary)
            }
        }
        .navigationTitle("予約投稿")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: .spacing16) {
                    if !isLoading && !messages.isEmpty {
                        Button {
                            withAnimation { viewMode = viewMode == .list ? .calendar : .list }
                        } label: {
                            Image(systemName: viewMode == .list ? "calendar" : "list.bullet")
                        }
                    }
                    Button {
                        clearPrefill()
                        showScheduler = true
                    } label: {
                        Image(systemName: "plus").fontWeight(.semibold)
                    }
                }
            }
        }
        .sheet(isPresented: $showScheduler, onDismiss: { Task { await reloadAfterCreate() } }) {
            ScheduleMessageView(
                embeds: embeds,
                prefillEmbedId: prefillEmbedId,
                prefillChannelId: prefillChannelId
            ) { msg in
                messages.insert(msg, at: 0)
                displayCount = min(displayCount + 1, messages.count)
                toast = ToastMessage(type: .success, message: "メッセージを予約しました")
            } onCreateTemplate: {
                showScheduler = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showEmbedEditor = true
                }
            }
        }
        .sheet(isPresented: $showEmbedEditor, onDismiss: { Task { embeds = (try? await services.embeds.fetchAll()) ?? [] } }) {
            EmbedEditorView(embed: nil) { saved in
                embeds.insert(saved, at: 0)
            }
        }
        .sheet(item: $detailMessage) { msg in
            ScheduledMessageDetailView(
                message: msg,
                embeds: embeds,
                onUpdate: { updated in
                    if let idx = messages.firstIndex(where: { $0.id == updated.id }) {
                        messages[idx] = updated
                    }
                },
                onCancel: { cancelled in
                    if let idx = messages.firstIndex(where: { $0.id == cancelled.id }) {
                        messages[idx] = cancelled
                    }
                },
                onReuse: { reusedMsg in
                    detailMessage = nil
                    prefillEmbedId = reusedMsg.embedId
                    prefillChannelId = reusedMsg.channelId
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showScheduler = true
                    }
                }
            )
        }
        .sheet(item: $selectedDayPosts) { dayPosts in
            ScheduledDayPostsSheet(posts: dayPosts.posts, embeds: embeds)
        }
        .toast($toast)
        .task { await loadData() }
        .onChange(of: appState.selectedGuildId) { Task { await loadData() } }
    }

    private func loadData() async {
        guard !appState.selectedGuildId.isEmpty else {
            messages = []
            isLoading = false
            return
        }
        let msgs = (try? await services.scheduledMessages.fetchAll()) ?? []
        let ems  = (try? await services.embeds.fetchAll()) ?? []
        messages = msgs.filter { $0.guildId == appState.selectedGuildId }
        displayCount = min(Self.pageSize, messages.count)
        embeds = ems
        isLoading = false
    }

    private func reloadAfterCreate() async {
        let msgs = (try? await services.scheduledMessages.fetchAll()) ?? []
        let ems  = (try? await services.embeds.fetchAll()) ?? []
        messages = msgs.filter { $0.guildId == appState.selectedGuildId }
        displayCount = min(Self.pageSize, messages.count)
        embeds = ems
    }

    private var emptyMessage: String {
        switch selectedTab {
        case .pending:   return "予約中のメッセージはありません"
        case .sent:      return "送信済みのメッセージはありません"
        case .cancelled: return "キャンセルされたメッセージはありません"
        case nil:        return "メッセージはありません"
        }
    }

    private func clearPrefill() {
        prefillEmbedId = nil
        prefillChannelId = nil
    }

    private func cancelMessage(_ msg: ScheduledMessage) {
        Task {
            try? await services.scheduledMessages.cancel(id: msg.id)
            var cancelled = msg
            cancelled.status = .cancelled
            if let idx = messages.firstIndex(where: { $0.id == msg.id }) {
                messages[idx] = cancelled
            }
            toast = ToastMessage(type: .info, message: "予約をキャンセルしました")
        }
    }
}

// MARK: - ScheduledMessageRow

private struct ScheduledMessageRow: View {
    let message: ScheduledMessage
    let embeds: [EmbedModel]

    private var embedName: String {
        embeds.first(where: { $0.id == message.embedId })?.name ?? "不明なテンプレート"
    }

    private var embedColor: Color {
        if let e = embeds.first(where: { $0.id == message.embedId }) {
            return Color(uiColor: UIColor(hex: e.colorHex))
        }
        return .accentIndigo
    }

    private var statusColor: Color {
        switch message.status {
        case .pending:   .accentOrange
        case .sent:      .accentGreen
        case .cancelled: .textTertiary
        }
    }

    private var statusIcon: String {
        switch message.status {
        case .pending:   "clock.fill"
        case .sent:      "checkmark.circle.fill"
        case .cancelled: "xmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: .spacing12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(embedColor)
                .frame(width: 4, height: 40)

            Image(systemName: statusIcon)
                .font(.system(size: 14))
                .foregroundStyle(statusColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(message.title.isEmpty ? embedName : message.title)
                    .font(.bodySmall)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                HStack(spacing: .spacing6) {
                    Text(japaneseFormattedDate(message.scheduledFor))
                        .font(.captionRegular)
                        .foregroundStyle(Color.textSecondary)
                    // 繰り返し表示は予約投稿では非表示
                }
                .font(.captionSmall)
                .foregroundStyle(Color.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.captionSmall)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.vertical, .spacing6)
    }
}

// MARK: - ScheduledMessageDetailView

private struct ScheduledMessageDetailView: View {
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    let message: ScheduledMessage
    let embeds: [EmbedModel]
    let onUpdate: (ScheduledMessage) -> Void
    let onCancel: (ScheduledMessage) -> Void
    let onReuse: (ScheduledMessage) -> Void

    @State private var scheduledDate: Date
    @State private var isSaving = false

    private var embed: EmbedModel? {
        embeds.first(where: { $0.id == message.embedId })
    }

    init(message: ScheduledMessage, embeds: [EmbedModel],
         onUpdate: @escaping (ScheduledMessage) -> Void,
         onCancel: @escaping (ScheduledMessage) -> Void,
         onReuse: @escaping (ScheduledMessage) -> Void) {
        self.message = message
        self.embeds = embeds
        self.onUpdate = onUpdate
        self.onCancel = onCancel
        self.onReuse = onReuse
        _scheduledDate = State(initialValue: message.scheduledFor)
    }

    private var isPending: Bool { message.status == .pending }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: .spacing20) {
                    if let e = embed {
                        VStack(alignment: .leading, spacing: .spacing8) {
                            Text("コンテンツ")
                                .font(.captionSmall)
                                .foregroundStyle(Color.textTertiary)
                                .textCase(.uppercase)
                            EmbedPreviewCard(embed: .from(e))
                        }
                        .padding(.horizontal)
                    }

                    HStack {
                        Text("ステータス")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                            .textCase(.uppercase)
                        Spacer()
                        Badge(text: message.status.rawValue.uppercased(),
                              color: statusColor)
                    }
                    .padding(.horizontal)

                    Divider().background(Color.border).padding(.horizontal)

                    VStack(alignment: .leading, spacing: .spacing4) {
                        Text("送信日時")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                            .textCase(.uppercase)
                        if isPending {
                            DatePicker("", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .tint(Color.accentIndigo)
                        } else {
                            Text(japaneseFormattedDate(message.scheduledFor))
                                .font(.bodySmall)
                                .foregroundStyle(Color.textPrimary)
                        }
                    }
                    .padding(.horizontal)

                    if isPending {
                        PrimaryButton("変更を保存", style: .filled, size: .large) {
                            saveChanges()
                        }
                        .padding(.horizontal)
                        .disabled(isSaving)

                        PrimaryButton("予約をキャンセル", style: .outlined, size: .medium) {
                            cancelReservation()
                        }
                        .padding(.horizontal)
                    }

                    // 再利用ボタン
                    if message.status != .pending {
                        PrimaryButton("この内容で再度予約する", style: .outlined, size: .large) {
                            onReuse(message)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.bgPrimary)
            .navigationTitle("予約詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    private var statusColor: Color {
        switch message.status {
        case .pending: .accentOrange
        case .sent: .accentGreen
        case .cancelled: .textTertiary
        }
    }

    private func saveChanges() {
        isSaving = true
        Task {
            var updated = message
            updated.scheduledFor = scheduledDate
            let saved = (try? await services.scheduledMessages.update(updated)) ?? updated
            onUpdate(saved)
            isSaving = false
            dismiss()
        }
    }

    private func cancelReservation() {
        Task {
            try? await services.scheduledMessages.cancel(id: message.id)
            var cancelled = message
            cancelled.status = .cancelled
            onCancel(cancelled)
            dismiss()
        }
    }
}

// MARK: - ScheduleMessageView

struct ScheduleMessageView: View {
    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let onSchedule: (ScheduledMessage) -> Void
    let onCreateTemplate: () -> Void
    var initialEmbeds: [EmbedModel]? = nil
    var prefillEmbedId: String? = nil
    var prefillChannelId: String? = nil
    init(embeds: [EmbedModel]? = nil,
         prefillEmbedId: String? = nil,
         prefillChannelId: String? = nil,
         onSchedule: @escaping (ScheduledMessage) -> Void,
         onCreateTemplate: @escaping () -> Void) {
        self.initialEmbeds = embeds
        self.prefillEmbedId = prefillEmbedId
        self.prefillChannelId = prefillChannelId
        self.onSchedule = onSchedule
        self.onCreateTemplate = onCreateTemplate
    }

    @State private var embeds: [EmbedModel] = []
    @State private var title = ""
    @State private var selectedEmbedId = ""
    @State private var selectedChannelId = ""
    @State private var channels: [Channel] = []
    @State private var scheduledDate = Date.now.addingTimeInterval(3600)
    // recurrence 削除済み（予約投稿は繰り返しなし）
    @State private var isModified = false
    @State private var showCancelAlert = false
    @State private var showValidationAlert = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !selectedEmbedId.isEmpty
    }

    private var textChannels: [Channel] {
        channels.filter { $0.type == .text && $0.botCanSend }
    }

    private var selectedEmbed: EmbedModel? {
        embeds.first(where: { $0.id == selectedEmbedId })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: .spacing24) {
                    // タイトル ※必須
                    VStack(alignment: .leading, spacing: .spacing4) {
                        Text("タイトル ※必須")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                            .textCase(.uppercase)
                        TextField("予約投稿のタイトル", text: $title)
                            .inputStyle()
                            .onChange(of: title) { isModified = true }
                    }
                    .padding(.horizontal)

                    // 埋め込みメッセージ選択
                    VStack(alignment: .leading, spacing: .spacing10) {
                        Text("埋め込みメッセージ")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                            .textCase(.uppercase)
                            .padding(.horizontal)

                        Picker(selection: $selectedEmbedId) {
                            Text("埋め込みメッセージを選択").tag("")
                            ForEach(embeds) { embed in
                                Text(embed.name).tag(embed.id)
                            }
                        } label: {
                            EmptyView()
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedEmbedId) { isModified = true }
                        .padding(.horizontal)

                        Button {
                            onCreateTemplate()
                        } label: {
                            Label("埋め込みメッセージを新規作成する", systemImage: "plus.circle.fill")
                                .font(.bodySmall)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.accentIndigo)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderless)
                        .padding(.horizontal)
                    }

                    if let embed = selectedEmbed {
                        VStack(alignment: .leading, spacing: .spacing8) {
                            Text("プレビュー")
                                .font(.captionSmall)
                                .foregroundStyle(Color.textTertiary)
                                .textCase(.uppercase)
                                .padding(.horizontal)
                            EmbedPreviewCard(embed: .from(embed))
                                .padding(.horizontal)
                        }
                    }

                    Divider().background(Color.border).padding(.horizontal)

                    // 送信先チャンネル
                    VStack(alignment: .leading, spacing: .spacing8) {
                        Text("送信先チャンネル")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                            .textCase(.uppercase)
                            .padding(.horizontal)

                        if channels.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 60)
                        } else {
                            ForEach(textChannels) { ch in
                                Button {
                                    selectedChannelId = ch.id
                                    isModified = true
                                } label: {
                                    ScheduleChannelRow(channel: ch, isSelected: selectedChannelId == ch.id)
                                }
                                .buttonStyle(.plain)

                                if ch.id != textChannels.last?.id {
                                    Divider()
                                        .background(Color.border)
                                        .padding(.leading, 52)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Divider().background(Color.border).padding(.horizontal)

                    // 送信日時
                    VStack(alignment: .leading, spacing: .spacing8) {
                        Text("送信日時")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                            .textCase(.uppercase)
                            .padding(.horizontal)
                        DatePicker("", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .tint(Color.accentIndigo)
                            .padding(.horizontal)
                            .onChange(of: scheduledDate) { isModified = true }
                    }

                    // 予約ボタン
                    PrimaryButton("予約する", style: .filled, size: .large) {
                        if isValid {
                            schedule()
                        } else {
                            showValidationAlert = true
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.bgPrimary)
            .navigationTitle("メッセージを予約")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        if isModified {
                            showCancelAlert = true
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundStyle(Color.textSecondary)
                }
            }
            .alert("変更が破棄されます", isPresented: $showCancelAlert) {
                Button("破棄する", role: .destructive) { dismiss() }
                Button("続ける", role: .cancel) { }
            } message: {
                Text("変更が破棄されますがよろしいでしょうか？")
            }
            .alert("入力エラー", isPresented: $showValidationAlert) {
                Button("OK") { }
            } message: {
                Text("タイトルと埋め込みメッセージは必須です。")
            }
        }
        .interactiveDismissDisabled(isModified)
        .task {
            channels = (try? await services.guilds.fetchChannels(guildId: appState.selectedGuildId)) ?? []
            if let embeds = initialEmbeds {
                self.embeds = embeds
            } else {
                self.embeds = (try? await services.embeds.fetchAll()) ?? []
            }
            // プリフィル処理
            if let prefillId = prefillEmbedId, embeds.contains(where: { $0.id == prefillId }) {
                selectedEmbedId = prefillId
            } else if let first = embeds.first {
                selectedEmbedId = first.id
            }
            if let prefillCh = prefillChannelId, textChannels.contains(where: { $0.id == prefillCh }) {
                selectedChannelId = prefillCh
            }
            // prefillRepeatRule 削除済み
        }
    }

    private func schedule() {
        guard let embed = selectedEmbed else { return }
        let msg = ScheduledMessage(
            id: UUID().uuidString,
            guildId: appState.selectedGuildId,
            channelId: selectedChannelId.isEmpty ? "c001" : selectedChannelId,
            embedId: embed.id,
            title: title.trimmingCharacters(in: .whitespaces),
            scheduledFor: scheduledDate,
            repeatRule: .none,
            status: .pending
        )
        Task {
            let saved = (try? await services.scheduledMessages.create(msg)) ?? msg
            onSchedule(saved)
            dismiss()
        }
    }
}

// MARK: - ScheduleChannelRow

struct ScheduleChannelRow: View {
    let channel: Channel
    let isSelected: Bool

    private var icon: String {
        switch channel.type {
        case .text: "number"
        case .announcement: "megaphone.fill"
        case .voice: "speaker.wave.2.fill"
        }
    }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.captionRegular)
                .foregroundStyle(Color.textTertiary)
                .frame(width: 20)

            Text(channel.name)
                .font(.bodySmall)
                .foregroundStyle(Color.textPrimary)

            if let cat = channel.categoryName {
                Text(cat)
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentIndigo)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, .spacing16)
        .padding(.vertical, .spacing10)
        .background(
            RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                .fill(isSelected ? Color.accentIndigo.opacity(0.08) : Color.clear)
        )
    }
}

// MARK: - Calendar Helpers

private func scheduledDayKey(_ date: Date) -> String {
    let cal = Calendar.current
    let c = cal.dateComponents([.year, .month, .day], from: date)
    return "\(c.year!)-\(c.month!)-\(c.day!)"
}

private struct ScheduledCalendarCell: Identifiable {
    let id = UUID()
    let day: Int?
    let date: Date?
}

// MARK: - ScheduledDayPosts

private struct ScheduledDayPosts: Identifiable {
    let id = UUID()
    let posts: [ScheduledMessage]
}

// MARK: - ScheduledDayPostsSheet

private struct ScheduledDayPostsSheet: View {
    let posts: [ScheduledMessage]
    let embeds: [EmbedModel]
    @Environment(\.dismiss) private var dismiss

    private var date: Date? { posts.first?.scheduledFor }

    var body: some View {
        NavigationStack {
            Group {
                if posts.isEmpty {
                    VStack(spacing: .spacing12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.textTertiary)
                        Text("この日の予約はありません")
                            .font(.bodyRegular)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.bgPrimary)
                } else {
                    List {
                        if let date {
                            Section {
                                Text(japaneseFormattedDate(date))
                                    .font(.bodySmall)
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                        ForEach(posts) { post in
                            VStack(alignment: .leading, spacing: .spacing4) {
                                HStack(spacing: .spacing8) {
                                    Image(systemName: post.status == .pending ? "clock.fill"
                                          : (post.status == .sent ? "checkmark.circle.fill" : "xmark.circle.fill"))
                                        .font(.system(size: 12))
                                        .foregroundStyle(post.status == .pending ? Color.accentOrange
                                                         : (post.status == .sent ? Color.accentGreen : Color.textTertiary))
                                    Text(post.title.isEmpty
                                         ? (embeds.first(where: { $0.id == post.embedId })?.name ?? "無題")
                                         : post.title)
                                        .font(.bodySmall)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.textPrimary)
                                }
                                Text(japaneseFormattedDate(post.scheduledFor))
                                    .font(.captionSmall)
                                    .foregroundStyle(Color.textTertiary)
                            }
                            .padding(.vertical, .spacing4)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.bgPrimary)
                }
            }
            .navigationTitle("予約投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }
}

// MARK: - Calendar View (extension on ScheduledMessagesListView)

extension ScheduledMessagesListView {
    var scheduledCalendarView: some View {
        let cal = Calendar.current
        let monthInterval = cal.dateInterval(of: .month, for: calendarDate)!
        let monthDays = cal.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day!
        let firstWeekday = cal.component(.weekday, from: monthInterval.start)
        let weekdayOffset = (firstWeekday - cal.firstWeekday + 7) % 7

        return ScrollView {
            VStack(spacing: .spacing8) {
                HStack {
                    Button {
                        calendarDate = cal.date(byAdding: .month, value: -1, to: calendarDate) ?? calendarDate
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.bodyRegular)
                            .foregroundStyle(Color.accentIndigo)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                    Text(scheduledMonthYearString(calendarDate))
                        .font(.titleMedium)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()

                    Button {
                        calendarDate = cal.date(byAdding: .month, value: 1, to: calendarDate) ?? calendarDate
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.bodyRegular)
                            .foregroundStyle(Color.accentIndigo)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, .spacing20)
                .padding(.top, .spacing8)

                HStack(spacing: 0) {
                    ForEach(scheduledShortWeekdaySymbols(), id: \.self) { day in
                        Text(day)
                            .font(.captionSmall)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, .spacing4)

                let cells = scheduledCalendarCells(cal: cal, monthDays: monthDays, weekdayOffset: weekdayOffset)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                    ForEach(cells) { cell in
                        if let dayNum = cell.day {
                            let cellDate = cell.date!
                            let key = scheduledDayKey(cellDate)
                            let hasPosts = postsByDay[key] != nil
                            let isToday = cal.isDateInToday(cellDate)

                            Button {
                                selectedDayPosts = ScheduledDayPosts(posts: postsByDay[key] ?? [])
                            } label: {
                                VStack(spacing: 2) {
                                    Text("\(dayNum)")
                                        .font(.captionRegular)
                                        .fontWeight(isToday ? .bold : .regular)
                                        .foregroundStyle(isToday ? Color.accentIndigo : Color.textPrimary)
                                        .frame(width: 32, height: 32)
                                        .background(
                                            Circle()
                                                .fill(isToday ? Color.accentIndigo.opacity(0.15) : Color.clear)
                                        )
                                    if hasPosts {
                                        Circle()
                                            .fill(Color.accentIndigo)
                                            .frame(width: 4, height: 4)
                                    } else {
                                        Circle().fill(Color.clear).frame(width: 4, height: 4)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.horizontal, .spacing4)
            }
            .padding(.bottom)
        }
    }

    private func scheduledMonthYearString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年 M月"
        return f.string(from: date)
    }

    private func scheduledShortWeekdaySymbols() -> [String] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        return f.shortWeekdaySymbols
    }

    private func scheduledCalendarCells(cal: Calendar, monthDays: Int, weekdayOffset: Int) -> [ScheduledCalendarCell] {
        let totalCells = weekdayOffset + monthDays
        let numWeeks = Int(ceil(Double(totalCells) / 7.0))
        let totalSlots = numWeeks * 7
        return (0 ..< totalSlots).map { index in
            let dayNum = index - weekdayOffset + 1
            if dayNum >= 1 && dayNum <= monthDays {
                var components = cal.dateComponents([.year, .month], from: calendarDate)
                components.day = dayNum
                let date = cal.date(from: components)!
                return ScheduledCalendarCell(day: dayNum, date: date)
            } else {
                return ScheduledCalendarCell(day: nil, date: nil)
            }
        }
    }
}

#Preview {
    ScheduledMessagesListView()
        .environment(\.services, ServiceContainer.live())
        .environment(AppState())
}
