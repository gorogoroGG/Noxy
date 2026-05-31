import SwiftUI

// MARK: - Date Key Helper

private func dayKey(_ date: Date) -> String {
    let cal = Calendar.current
    let comps = cal.dateComponents([.year, .month, .day], from: date)
    return "\(comps.year!)-\(comps.month!)-\(comps.day!)"
}

private let pageSize = 10

// MARK: - RecurringPostsListView

struct RecurringPostsListView: View {
    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState
    @State private var allMessages: [ScheduledMessage] = []
    @State private var embeds: [EmbedModel] = []
    @State private var isLoading = true
    @State private var showCreate = false
    @State private var showEmbedEditor = false
    @State private var toast: ToastMessage? = nil
    @State private var viewMode: ViewMode = .list
    @State private var calendarDate = Date()
    @State private var selectedDayPosts: DayPosts? = nil
    @State private var editingMessage: ScheduledMessage? = nil
    @State private var displayCount = pageSize

    enum ViewMode: String, CaseIterable { case list, calendar }

    private var recurringMessages: [ScheduledMessage] {
        allMessages.filter { $0.repeatRule != .none }
    }

    private var displayedMessages: [ScheduledMessage] {
        Array(recurringMessages.prefix(displayCount))
    }

    private var hasMore: Bool {
        displayCount < recurringMessages.count
    }

    private var postsByDay: [String: [ScheduledMessage]] {
        Dictionary(grouping: recurringMessages) { msg in
            dayKey(msg.scheduledFor)
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.bgPrimary)
            } else if recurringMessages.isEmpty {
                EmptyStateView(
                    icon: "repeat.circle.fill",
                    title: "定期投稿がありません",
                    description: "繰り返し送信するメッセージを設定しましょう。",
                    actionTitle: "定期投稿を作成"
                ) { showCreate = true }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.bgPrimary)
            } else {
                VStack(spacing: 0) {
                    Picker("", selection: $viewMode) {
                        Text("リスト").tag(ViewMode.list)
                        Text("カレンダー").tag(ViewMode.calendar)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, .spacing8)

                    switch viewMode {
                    case .list:
                        listView
                    case .calendar:
                        calendarView
                    }
                }
                .background(Color.bgPrimary)
            }

            if !isLoading && !recurringMessages.isEmpty {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.accentIndigo)
                        .clipShape(Circle())
                        .shadow(color: Color.accentIndigo.opacity(0.4), radius: 12, x: 0, y: 4)
                }
                .padding(.trailing, .spacing20)
                .padding(.bottom, .spacing24)
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle("定期投稿")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreate = true } label: {
                    Image(systemName: "plus").fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showCreate, onDismiss: { Task { await load() } }) {
            RecurringPostCreateView(embeds: embeds) { msg in
                allMessages.append(msg)
                displayCount = min(displayCount + 1, allMessages.count)
                toast = ToastMessage(type: .success, message: "定期投稿を作成しました")
            } onCreateTemplate: {
                showCreate = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showEmbedEditor = true
                }
            }
        }
        .sheet(isPresented: $showEmbedEditor, onDismiss: { Task { await reloadAfterCreate() } }) {
            EmbedEditorView(embed: nil) { saved in
                embeds.append(saved)
            }
        }
        .sheet(item: $selectedDayPosts) { dayPosts in
            DayPostsSheet(posts: dayPosts.posts, embeds: embeds) { msg in
                editingMessage = msg
            }
        }
        .sheet(item: $editingMessage) { msg in
            RecurringPostEditSheet(message: msg, embeds: embeds) { updated in
                if let idx = allMessages.firstIndex(where: { $0.id == updated.id }) {
                    allMessages[idx] = updated
                }
                toast = ToastMessage(type: .success, message: "定期投稿を更新しました")
            }
        }
        .toast($toast)
        .task { await load() }
        .onChange(of: appState.selectedGuildId) { Task { await load() } }
    }

    // MARK: - List View

    private var listView: some View {
        List {
            ForEach(displayedMessages) { msg in
                Button {
                    editingMessage = msg
                } label: {
                    RecurringPostRow(message: msg, embeds: embeds)
                }
                .buttonStyle(.plain)
                .onAppear {
                    if msg.id == displayedMessages.last?.id && hasMore {
                        displayCount = min(displayCount + pageSize, recurringMessages.count)
                    }
                }
            }
            .onDelete { indexSet in
                let toDelete = indexSet.map { displayedMessages[$0] }
                for msg in toDelete {
                    Task {
                        try? await services.scheduledMessages.cancel(id: msg.id)
                        allMessages.removeAll { $0.id == msg.id }
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

    // MARK: - Calendar View

    private var calendarView: some View {
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
                    Text(monthYearString(calendarDate))
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
                    ForEach(shortWeekdaySymbols(), id: \.self) { day in
                        Text(day)
                            .font(.captionSmall)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, .spacing4)

                let cells = calendarCells(cal: cal, monthDays: monthDays, weekdayOffset: weekdayOffset)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                    ForEach(cells) { cell in
                        if let dayNum = cell.day {
                            let cellDate = cell.date!
                            let key = dayKey(cellDate)
                            let hasPosts = postsByDay[key] != nil
                            let isToday = cal.isDateInToday(cellDate)

                            Button {
                                selectedDayPosts = DayPosts(posts: postsByDay[key] ?? [])
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

    // MARK: - Helpers

    private func monthYearString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年 M月"
        return f.string(from: date)
    }

    private func shortWeekdaySymbols() -> [String] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        return f.shortWeekdaySymbols
    }

    private func load() async {
        guard !appState.selectedGuildId.isEmpty else {
            allMessages = []
            isLoading = false
            return
        }
        let msgs = (try? await services.scheduledMessages.fetchAll()) ?? []
        let ems  = (try? await services.embeds.fetchAll()) ?? []
        allMessages = msgs.filter { $0.guildId == appState.selectedGuildId || $0.guildId == nil }
        displayCount = min(pageSize, allMessages.count)
        embeds = ems
        isLoading = false
    }

    private func reloadAfterCreate() async {
        let msgs = (try? await services.scheduledMessages.fetchAll()) ?? []
        let ems  = (try? await services.embeds.fetchAll()) ?? []
        allMessages = msgs.filter { $0.guildId == appState.selectedGuildId || $0.guildId == nil }
        embeds = ems
    }

    private func calendarCells(cal: Calendar, monthDays: Int, weekdayOffset: Int) -> [CalendarCell] {
        let totalCells = weekdayOffset + monthDays
        let numWeeks = Int(ceil(Double(totalCells) / 7.0))
        let totalSlots = numWeeks * 7
        return (0 ..< totalSlots).map { index in
            let dayNum = index - weekdayOffset + 1
            if dayNum >= 1 && dayNum <= monthDays {
                var components = cal.dateComponents([.year, .month], from: calendarDate)
                components.day = dayNum
                let date = cal.date(from: components)!
                return CalendarCell(day: dayNum, date: date)
            } else {
                return CalendarCell(day: nil, date: nil)
            }
        }
    }
}

// MARK: - CalendarCell

private struct CalendarCell: Identifiable {
    let id = UUID()
    let day: Int?
    let date: Date?
}

// MARK: - RecurringPostRow

private struct RecurringPostRow: View {
    let message: ScheduledMessage
    let embeds: [EmbedModel]

    private var embed: EmbedModel? {
        embeds.first(where: { $0.id == message.embedId })
    }

    private var embedColor: Color {
        if let e = embed {
            return Color(uiColor: UIColor(hex: e.colorHex))
        }
        return .accentIndigo
    }

    var body: some View {
        HStack(spacing: .spacing12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(embedColor)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(message.title.isEmpty ? (embed?.name ?? "無題") : message.title)
                    .font(.bodySmall)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                HStack(spacing: .spacing6) {
                    if let e = embed {
                        Text(e.name)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Text("·")
                    Text(repeatDisplayName(message.repeatRule))
                    if let end = message.endDate {
                        Text("·")
                        Text("〜 \(shortDate(end))")
                    }
                }
                .font(.captionSmall)
                .foregroundStyle(Color.textTertiary)
            }

            Spacer()
        }
        .padding(.vertical, .spacing6)
    }

    private func repeatDisplayName(_ rule: RepeatRule) -> String {
        switch rule {
        case .none: ""
        case .daily: "毎日"
        case .weekly: "毎週"
        case .monthly: "毎月"
        }
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月d日"
        return f.string(from: date)
    }
}

// MARK: - DayPosts

private struct DayPosts: Identifiable {
    let id = UUID()
    let posts: [ScheduledMessage]
}

private struct DayPostsSheet: View {
    let posts: [ScheduledMessage]
    let embeds: [EmbedModel]
    let onEdit: (ScheduledMessage) -> Void
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
                        Text("投稿はありません")
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
                            Button {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onEdit(post)
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: .spacing4) {
                                        Text(post.title.isEmpty ? (embeds.first(where: { $0.id == post.embedId })?.name ?? "無題") : post.title)
                                            .font(.bodySmall)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.textPrimary)
                                        HStack(spacing: .spacing6) {
                                            if let e = embeds.first(where: { $0.id == post.embedId }) {
                                                Text(e.name)
                                            }
                                            Text("·")
                                            Text(repeatDisplayName(post.repeatRule))
                                        }
                                        .font(.captionSmall)
                                        .foregroundStyle(Color.textTertiary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.captionSmall)
                                        .foregroundStyle(Color.textTertiary)
                                }
                                .padding(.vertical, .spacing4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.bgPrimary)
                }
            }
            .navigationTitle("投稿予定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    private func repeatDisplayName(_ rule: RepeatRule) -> String {
        switch rule {
        case .none: ""
        case .daily: "毎日"
        case .weekly: "毎週"
        case .monthly: "毎月"
        }
    }
}

// MARK: - RecurringPostCreateView

private struct RecurringPostCreateView: View {
    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let embeds: [EmbedModel]
    let onSchedule: (ScheduledMessage) -> Void
    let onCreateTemplate: () -> Void

    @State private var title = ""
    @State private var selectedEmbedId = ""
    @State private var selectedChannelId = ""
    @State private var channels: [Channel] = []
    @State private var scheduledDate = Date.now.addingTimeInterval(3600)
    @State private var repeatRule: RepeatRule = .daily
    @State private var hasEndDate = false
    @State private var endDate = Date.now.addingTimeInterval(86400 * 30)
    @State private var isModified = false
    @State private var showCancelAlert = false
    @State private var showValidationAlert = false

    private var textChannels: [Channel] {
        channels.filter { $0.type == .text && $0.botCanSend }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !selectedEmbedId.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: .spacing20) {
                    VStack(alignment: .leading, spacing: .spacing4) {
                        Text("タイトル ※必須")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                            .textCase(.uppercase)
                        TextField("定期投稿のタイトル", text: $title)
                            .inputStyle()
                            .onChange(of: title) { isModified = true }
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: .spacing4) {
                        Text("埋め込みメッセージ ※必須")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                            .textCase(.uppercase)
                        Picker(selection: $selectedEmbedId) {
                            Text("埋め込みメッセージを選択").tag("")
                            ForEach(embeds) { embed in
                                Text(embed.name).tag(embed.id)
                            }
                        } label: { EmptyView() }
                        .pickerStyle(.menu)
                        .onChange(of: selectedEmbedId) { isModified = true }
                    }
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

                    if let embed = embeds.first(where: { $0.id == selectedEmbedId }) {
                        EmbedPreviewCard(embed: .from(embed))
                            .padding(.horizontal)
                    }

                    Divider().background(Color.border).padding(.horizontal)

                    VStack(alignment: .leading, spacing: .spacing8) {
                        Text("送信先チャンネル")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                            .textCase(.uppercase)
                            .padding(.horizontal)

                        if channels.isEmpty {
                            ProgressView().frame(maxWidth: .infinity, minHeight: 60)
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
                                    Divider().background(Color.border).padding(.leading, 52)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Divider().background(Color.border).padding(.horizontal)

                    VStack(alignment: .leading, spacing: .spacing4) {
                        Text("初回送信日時")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                            .textCase(.uppercase)
                        DatePicker("", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .tint(Color.accentIndigo)
                            .onChange(of: scheduledDate) { isModified = true }
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: .spacing8) {
                        Text("繰り返し")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                            .textCase(.uppercase)
                            .padding(.horizontal)
                        Picker("", selection: $repeatRule) {
                            ForEach([RepeatRule.daily, .weekly, .monthly], id: \.self) { r in
                                Text(repeatDisplayName(r)).tag(r)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .onChange(of: repeatRule) { isModified = true }

                        VStack(alignment: .leading, spacing: .spacing4) {
                            Text("直近5回の送信予定")
                                .font(.captionSmall)
                                .foregroundStyle(Color.textTertiary)
                            ForEach(Array(nextOccurrences(from: scheduledDate, rule: repeatRule, count: 5).enumerated()), id: \.offset) { _, date in
                                HStack(spacing: .spacing6) {
                                    Circle()
                                        .fill(Color.accentIndigo.opacity(0.4))
                                        .frame(width: 5, height: 5)
                                    Text(japaneseFormattedDate(date))
                                        .font(.captionRegular)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    Divider().background(Color.border).padding(.horizontal)

                    VStack(alignment: .leading, spacing: .spacing8) {
                        Toggle("終了日を設定する", isOn: $hasEndDate)
                            .font(.bodySmall)
                            .foregroundStyle(Color.textPrimary)
                            .tint(Color.accentIndigo)
                            .onChange(of: hasEndDate) { isModified = true }
                        if hasEndDate {
                            DatePicker("", selection: $endDate, displayedComponents: [.date])
                                .labelsHidden()
                                .tint(Color.accentIndigo)
                                .onChange(of: endDate) { isModified = true }
                        }
                    }
                    .padding(.horizontal)

                    PrimaryButton("定期投稿を作成する", style: .filled, size: .large) {
                        if isValid {
                            create()
                        } else {
                            showValidationAlert = true
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.bgPrimary)
            .navigationTitle("定期投稿を作成")
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
        }
    }

    private func repeatDisplayName(_ rule: RepeatRule) -> String {
        switch rule {
        case .none: ""
        case .daily: "毎日"
        case .weekly: "毎週"
        case .monthly: "毎月"
        }
    }

    private func create() {
        guard !selectedEmbedId.isEmpty else { return }
        let msg = ScheduledMessage(
            id: UUID().uuidString,
            guildId: appState.selectedGuildId,
            channelId: selectedChannelId.isEmpty ? "c001" : selectedChannelId,
            embedId: selectedEmbedId,
            title: title.trimmingCharacters(in: .whitespaces),
            scheduledFor: scheduledDate,
            repeatRule: repeatRule,
            status: .pending,
            endDate: hasEndDate ? endDate : nil
        )
        Task {
            let saved = (try? await services.scheduledMessages.create(msg)) ?? msg
            onSchedule(saved)
            dismiss()
        }
    }
}

// MARK: - Reused Helpers

private func repeatDisplayName(_ rule: RepeatRule) -> String {
    switch rule {
    case .none: ""
    case .daily: "毎日"
    case .weekly: "毎週"
    case .monthly: "毎月"
    }
}

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
        case .none: break
        }
    }
    return result
}

private func japaneseFormattedDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateFormat = "yyyy年MM月dd日 HH:mm"
    return f.string(from: date)
}

// MARK: - RecurringPostEditSheet

private struct RecurringPostEditSheet: View {
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    let message: ScheduledMessage
    let embeds: [EmbedModel]
    let onSave: (ScheduledMessage) -> Void

    @State private var scheduledDate: Date
    @State private var repeatRule: RepeatRule
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var isSaving = false

    private var embed: EmbedModel? {
        embeds.first(where: { $0.id == message.embedId })
    }

    init(message: ScheduledMessage, embeds: [EmbedModel], onSave: @escaping (ScheduledMessage) -> Void) {
        self.message = message
        self.embeds = embeds
        self.onSave = onSave
        _scheduledDate = State(initialValue: message.scheduledFor)
        _repeatRule = State(initialValue: message.repeatRule)
        _hasEndDate = State(initialValue: message.endDate != nil)
        _endDate = State(initialValue: message.endDate ?? Date.now.addingTimeInterval(86400 * 30))
    }

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

                    Divider().background(Color.border).padding(.horizontal)

                    VStack(alignment: .leading, spacing: .spacing4) {
                        Text("次回送信日時")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                            .textCase(.uppercase)
                        DatePicker("", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .tint(Color.accentIndigo)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: .spacing8) {
                        Text("繰り返し")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                            .textCase(.uppercase)
                        Picker("", selection: $repeatRule) {
                            ForEach([RepeatRule.daily, .weekly, .monthly], id: \.self) { r in
                                Text(repeatDisplayName(r)).tag(r)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: .spacing4) {
                            Text("直近5回の送信予定")
                                .font(.captionSmall)
                                .foregroundStyle(Color.textTertiary)
                            ForEach(Array(nextOccurrences(from: scheduledDate, rule: repeatRule, count: 5).enumerated()), id: \.offset) { _, date in
                                HStack(spacing: .spacing6) {
                                    Circle()
                                        .fill(Color.accentIndigo.opacity(0.4))
                                        .frame(width: 5, height: 5)
                                    Text(japaneseFormattedDate(date))
                                        .font(.captionRegular)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    Divider().background(Color.border).padding(.horizontal)

                    VStack(alignment: .leading, spacing: .spacing8) {
                        Toggle("終了日を設定する", isOn: $hasEndDate)
                            .font(.bodySmall)
                            .foregroundStyle(Color.textPrimary)
                            .tint(Color.accentIndigo)
                        if hasEndDate {
                            DatePicker("", selection: $endDate, displayedComponents: [.date])
                                .labelsHidden()
                                .tint(Color.accentIndigo)
                        }
                    }
                    .padding(.horizontal)

                    PrimaryButton("変更を保存", style: .filled, size: .large) {
                        save()
                    }
                    .padding(.horizontal)
                    .disabled(isSaving)
                }
                .padding(.vertical)
            }
            .background(Color.bgPrimary)
            .navigationTitle("定期投稿を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            var updated = message
            updated.scheduledFor = scheduledDate
            updated.repeatRule = repeatRule
            updated.endDate = hasEndDate ? endDate : nil
            let saved = (try? await services.scheduledMessages.update(updated)) ?? updated
            onSave(saved)
            isSaving = false
            dismiss()
        }
    }

    private func repeatDisplayName(_ rule: RepeatRule) -> String {
        switch rule {
        case .none: "なし"
        case .daily: "毎日"
        case .weekly: "毎週"
        case .monthly: "毎月"
        }
    }
}

#Preview {
    NavigationStack {
        RecurringPostsListView()
            .environment(\.services, ServiceContainer.live())
            .environment(AppState())
            .preferredColorScheme(.dark)
    }
}
