import SwiftUI

// MARK: - AutoMod State

@Observable
final class AutoModSettings {
    // ── スパム対策 ────────────────────────────────────────────
    var msgSpamEnabled   = true;  var msgSpamCount  = 5;  var msgSpamSeconds = 5
    var dupMsgEnabled    = false; var dupMsgCount   = 3
    var mentionEnabled   = true;  var mentionLimit  = 5
    var massMentionEnabled = true; var massMentionLimit = 3
    var emojiEnabled     = false; var emojiLimit    = 10
    var capsEnabled      = true;  var capsPercent   = 70

    // ── コンテンツフィルター ──────────────────────────────────
    var keywordEnabled   = true
    var blockedKeywords: [String] = ["スパム", "詐欺", "hack", "discord.gg"]
    var regexEnabled     = false
    var blockedRegex: [String] = []
    var inviteLinkEnabled = true
    var phishingEnabled  = true
    var linkFilterEnabled = false; var linkMode: LinkMode = .allowAll
    var allowedLinks: [String] = []
    var nsfwEnabled      = false

    // ── アカウント保護 ─────────────────────────────────────────
    var minAgeEnabled    = false; var minAgeDays    = 7
    var newMemberEnabled = false; var newMemberMins = 10
    var raidEnabled      = false; var raidJoins     = 10; var raidSeconds  = 30

    // ── アンチヌーク ──────────────────────────────────────────
    var antiNukeEnabled  = false
    var channelDeleteLimit = 3; var channelDeleteSeconds = 10
    var roleDeleteEnabled = false
    var roleDeleteLimit  = 3; var roleDeleteSeconds = 10
    var massBanEnabled   = false
    var massBanLimit     = 5; var massBanSeconds = 30

    // ── アクション ────────────────────────────────────────────
    var defaultAction: ViolationAction = .deleteAndWarn
    var timeoutMinutes  = 60
    var escalationEnabled = true
    var escalationSteps: [EscalationStep] = [
        EscalationStep(violations: 3, action: .timeout(minutes: 10)),
        EscalationStep(violations: 5, action: .timeout(minutes: 60)),
        EscalationStep(violations: 10, action: .kick),
        EscalationStep(violations: 15, action: .ban),
    ]
    var logEnabled      = true
    var logChannelName  = ""

    // ── 除外 ──────────────────────────────────────────────────
    var exemptRoles:    [String] = ["管理者", "モデレーター"]
    var exemptChannels: [String] = []

    enum LinkMode: String, CaseIterable {
        case allowAll   = "全リンクを許可"
        case blockAll   = "全リンクをブロック"
        case whitelist  = "ホワイトリストのみ許可"
    }
}

struct EscalationStep: Identifiable {
    let id = UUID()
    var violations: Int
    var action: EscalationAction

    enum EscalationAction: Codable, Equatable {
        case warn
        case timeout(minutes: Int)
        case kick
        case ban

        var label: String {
            switch self {
            case .warn: return "警告"
            case .timeout(let m): return "\(m)分タイムアウト"
            case .kick: return "キック"
            case .ban: return "BAN"
            }
        }
    }

    var summary: String {
        "\(violations)回違反 → \(action.label)"
    }
}

enum ViolationAction: String, CaseIterable {
    case deleteOnly      = "メッセージ削除のみ"
    case deleteAndWarn   = "削除 + 警告"
    case deleteAndTimeout = "削除 + タイムアウト"
    case deleteAndKick   = "削除 + キック"
    case deleteAndBan    = "削除 + BAN"

    var icon: String {
        switch self {
        case .deleteOnly:       "trash"
        case .deleteAndWarn:    "exclamationmark.triangle"
        case .deleteAndTimeout: "timer"
        case .deleteAndKick:    "person.fill.xmark"
        case .deleteAndBan:     "hand.raised.slash.fill"
        }
    }
    var color: Color {
        switch self {
        case .deleteOnly:       .textTertiary
        case .deleteAndWarn:    .accentOrange
        case .deleteAndTimeout: .accentPurple
        case .deleteAndKick:    .accentOrange
        case .deleteAndBan:     .accentRed
        }
    }
}

// MARK: - AutoModSettingsView

struct AutoModSettingsView: View {
    @State private var settings = AutoModSettings()
    @State private var hasChanges = false
    @State private var saveSuccess = false
    @State private var newKeyword = ""
    @State private var expandedSection: AutoModSection? = nil

    enum AutoModSection: String, CaseIterable {
        case spam     = "スパム対策"
        case content  = "コンテンツフィルター"
        case account  = "アカウント保護"
        case antinuke = "アンチヌーク"
        case action   = "アクション設定"
        case exempt   = "除外設定"

        var icon: String {
            switch self {
            case .spam:    "message.badge.filled.fill"
            case .content: "doc.text.magnifyingglass"
            case .account: "person.badge.shield.checkmark.fill"
            case .antinuke: "shield.slash.fill"
            case .action:  "bolt.shield.fill"
            case .exempt:  "checkmark.shield"
            }
        }
        var color: Color {
            switch self {
            case .spam:    .accentPurple
            case .content: .accentIndigo
            case .account: .accentGreen
            case .antinuke: .accentRed
            case .action:  .accentOrange
            case .exempt:  .textSecondary
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVStack(spacing: .spacing8) {
                    overviewBanner
                    ForEach(AutoModSection.allCases, id: \.self) { section in
                        AutoModSectionCard(
                            section: section,
                            isExpanded: expandedSection == section
                        ) {
                            withAnimation(.spring(duration: 0.3)) {
                                expandedSection = expandedSection == section ? nil : section
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } content: {
                            sectionContent(section)
                        }
                    }
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, .spacing16)
                .padding(.top, .spacing12)
            }

            if hasChanges {
                saveBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: hasChanges)
        .background(Color.bgPrimary)
    }

    // MARK: - Overview

    private var overviewBanner: some View {
        HStack(spacing: .spacing12) {
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 28)).foregroundStyle(Color.accentIndigo)
            VStack(alignment: .leading, spacing: 2) {
                Text("自動モデレーション")
                    .font(.bodySmall).fontWeight(.bold).foregroundStyle(Color.textPrimary)
                let active = countActiveRules()
                Text("現在 \(active) 個のルールが有効です")
                    .font(.captionSmall).foregroundStyle(Color.textSecondary)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("\(countActiveRules())")
                    .font(.titleLarge).fontWeight(.bold).foregroundStyle(Color.accentIndigo)
                Text("有効").font(.captionSmall).foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.spacing16)
        .background(Color.accentIndigo.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .overlay(RoundedRectangle(cornerRadius: .cornerRadiusMedium)
            .stroke(Color.accentIndigo.opacity(0.2), lineWidth: 1))
        .padding(.top, .spacing4)
    }

    private func countActiveRules() -> Int {
        let s = settings
        return [s.msgSpamEnabled, s.dupMsgEnabled, s.mentionEnabled, s.massMentionEnabled,
                s.emojiEnabled, s.capsEnabled, s.keywordEnabled, s.regexEnabled,
                s.inviteLinkEnabled, s.phishingEnabled, s.linkFilterEnabled,
                s.nsfwEnabled, s.minAgeEnabled, s.newMemberEnabled, s.raidEnabled,
                s.antiNukeEnabled, s.roleDeleteEnabled, s.massBanEnabled, s.logEnabled].filter { $0 }.count
    }

    // MARK: - Save Bar

    private var saveBar: some View {
        HStack(spacing: .spacing12) {
            Button {
                settings = AutoModSettings()
                hasChanges = false
            } label: {
                Text("リセット")
                    .font(.bodySmall).foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            }
            .buttonStyle(.plain)

            Button { saveSettings() } label: {
                Group {
                    if saveSuccess {
                        Label("保存済み", systemImage: "checkmark").foregroundStyle(.white)
                    } else {
                        Text("変更を保存").foregroundStyle(.white)
                    }
                }
                .font(.bodySmall).fontWeight(.semibold)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(saveSuccess ? Color.accentGreen : Color.accentIndigo)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, .spacing16).padding(.vertical, .spacing12)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
    }

    private func saveSettings() {
        // 実際のAPI保存処理
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { saveSuccess = true; hasChanges = false }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run { withAnimation { saveSuccess = false } }
        }
    }

    // MARK: - Section Contents

    @ViewBuilder
    private func sectionContent(_ section: AutoModSection) -> some View {
        switch section {
        case .spam:    spamSection
        case .content: contentSection
        case .account: accountSection
        case .antinuke: antinukeSection
        case .action:  actionSection
        case .exempt:  exemptSection
        }
    }

    // ── スパム対策 ──────────────────────────────────────────────

    private var spamSection: some View {
        VStack(spacing: 0) {
            RuleRow(
                title: "メッセージスパム",
                description: "\(settings.msgSpamSeconds)秒以内に\(settings.msgSpamCount)件以上で検知",
                isOn: Binding(get: { settings.msgSpamEnabled }, set: { settings.msgSpamEnabled = $0; hasChanges = true })
            ) {
                VStack(spacing: .spacing12) {
                    StepperRow(label: "検知メッセージ数", value: Binding(get: { settings.msgSpamCount }, set: { settings.msgSpamCount = $0; hasChanges = true }), range: 2...20, unit: "件")
                    StepperRow(label: "検知秒数",         value: Binding(get: { settings.msgSpamSeconds }, set: { settings.msgSpamSeconds = $0; hasChanges = true }), range: 1...30, unit: "秒")
                }
            }
            Divider().padding(.leading, 52)
            RuleRow(
                title: "重複メッセージ",
                description: "同じ内容を\(settings.dupMsgCount)回以上送信で検知",
                isOn: Binding(get: { settings.dupMsgEnabled }, set: { settings.dupMsgEnabled = $0; hasChanges = true })
            ) {
                StepperRow(label: "繰り返し回数", value: Binding(get: { settings.dupMsgCount }, set: { settings.dupMsgCount = $0; hasChanges = true }), range: 2...10, unit: "回")
            }
            Divider().padding(.leading, 52)
            RuleRow(
                title: "メンションスパム",
                description: "1メッセージに@メンションが\(settings.mentionLimit)件以上",
                isOn: Binding(get: { settings.mentionEnabled }, set: { settings.mentionEnabled = $0; hasChanges = true })
            ) {
                StepperRow(label: "最大メンション数", value: Binding(get: { settings.mentionLimit }, set: { settings.mentionLimit = $0; hasChanges = true }), range: 2...20, unit: "件")
            }
            Divider().padding(.leading, 52)
            RuleRow(
                title: "一括メンション (@everyone/@here)",
                description: "@everyone/@hereを\(settings.massMentionLimit)回以上使用で検知",
                isOn: Binding(get: { settings.massMentionEnabled }, set: { settings.massMentionEnabled = $0; hasChanges = true })
            ) {
                StepperRow(label: "検知回数", value: Binding(get: { settings.massMentionLimit }, set: { settings.massMentionLimit = $0; hasChanges = true }), range: 1...10, unit: "回")
            }
            Divider().padding(.leading, 52)
            RuleRow(
                title: "絵文字スパム",
                description: "1メッセージに絵文字が\(settings.emojiLimit)個以上",
                isOn: Binding(get: { settings.emojiEnabled }, set: { settings.emojiEnabled = $0; hasChanges = true })
            ) {
                StepperRow(label: "最大絵文字数", value: Binding(get: { settings.emojiLimit }, set: { settings.emojiLimit = $0; hasChanges = true }), range: 5...30, unit: "個")
            }
            Divider().padding(.leading, 52)
            RuleRow(
                title: "大文字スパム (CAPS)",
                description: "メッセージの\(settings.capsPercent)%以上が大文字",
                isOn: Binding(get: { settings.capsEnabled }, set: { settings.capsEnabled = $0; hasChanges = true })
            ) {
                StepperRow(label: "大文字の割合", value: Binding(get: { settings.capsPercent }, set: { settings.capsPercent = $0; hasChanges = true }), range: 50...100, unit: "%")
            }
        }
    }

    // ── コンテンツフィルター ────────────────────────────────────

    private var contentSection: some View {
        VStack(spacing: 0) {
            RuleRow(
                title: "キーワードフィルター",
                description: "NGワード・フレーズを含むメッセージをブロック",
                isOn: Binding(get: { settings.keywordEnabled }, set: { settings.keywordEnabled = $0; hasChanges = true })
            ) {
                keywordEditor
            }
            Divider().padding(.leading, 52)
            RuleRow(
                title: "正規表現フィルター",
                description: "正規表現パターンに一致するメッセージをブロック",
                isOn: Binding(get: { settings.regexEnabled }, set: { settings.regexEnabled = $0; hasChanges = true })
            ) {
                regexEditor
            }
            Divider().padding(.leading, 52)
            RuleRow(
                title: "Discord招待リンクをブロック",
                description: "discord.gg/... 形式の招待リンクを自動削除",
                isOn: Binding(get: { settings.inviteLinkEnabled }, set: { settings.inviteLinkEnabled = $0; hasChanges = true })
            )
            Divider().padding(.leading, 52)
            RuleRow(
                title: "フィッシングリンク検出",
                description: "既知のフィッシングサイトURLを自動検出・削除",
                isOn: Binding(get: { settings.phishingEnabled }, set: { settings.phishingEnabled = $0; hasChanges = true })
            )
            Divider().padding(.leading, 52)
            RuleRow(
                title: "リンクフィルター",
                description: settings.linkMode.rawValue,
                isOn: Binding(get: { settings.linkFilterEnabled }, set: { settings.linkFilterEnabled = $0; hasChanges = true })
            ) {
                VStack(spacing: .spacing12) {
                    Picker("リンク設定", selection: Binding(get: { settings.linkMode }, set: { settings.linkMode = $0; hasChanges = true })) {
                        ForEach(AutoModSettings.LinkMode.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    if settings.linkMode == .whitelist {
                        allowedLinksEditor
                    }
                }
            }
            Divider().padding(.leading, 52)
            RuleRow(
                title: "NSFWコンテンツ検出",
                description: "不適切な画像・コンテンツを自動検出して削除",
                isOn: Binding(get: { settings.nsfwEnabled }, set: { settings.nsfwEnabled = $0; hasChanges = true })
            )
        }
    }

    private var keywordEditor: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            // 既存キーワード
            FlowLayout(spacing: .spacing6) {
                ForEach(settings.blockedKeywords, id: \.self) { word in
                    HStack(spacing: 4) {
                        Text(word).font(.captionSmall).foregroundStyle(Color.textPrimary)
                        Button {
                            settings.blockedKeywords.removeAll { $0 == word }
                            hasChanges = true
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, .spacing8).padding(.vertical, 4)
                    .background(Color.bgElevated)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.border, lineWidth: 1))
                }
            }
            // 追加フィールド
            HStack(spacing: .spacing8) {
                TextField("キーワードを追加", text: $newKeyword)
                    .font(.bodySmall)
                    .onSubmit { addKeyword() }
                Button("追加") { addKeyword() }
                    .font(.captionRegular).fontWeight(.semibold)
                    .foregroundStyle(Color.accentIndigo)
                    .disabled(newKeyword.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    @State private var newRegex = ""
    @State private var newAllowedLink = ""

    private var allowedLinksEditor: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            FlowLayout(spacing: .spacing6) {
                ForEach(settings.allowedLinks, id: \.self) { link in
                    HStack(spacing: 4) {
                        Image(systemName: "link").font(.system(size: 10)).foregroundStyle(Color.accentGreen)
                        Text(link).font(.captionSmall).foregroundStyle(Color.textPrimary)
                        Button {
                            settings.allowedLinks.removeAll { $0 == link }
                            hasChanges = true
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, .spacing8).padding(.vertical, 4)
                    .background(Color.bgElevated)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.accentGreen.opacity(0.3), lineWidth: 1))
                }
            }
            HStack(spacing: .spacing8) {
                TextField("許可URLを追加", text: $newAllowedLink)
                    .font(.bodySmall)
                    .onSubmit { addAllowedLink() }
                Button("追加") { addAllowedLink() }
                    .font(.captionRegular).fontWeight(.semibold)
                    .foregroundStyle(Color.accentGreen)
                    .disabled(newAllowedLink.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addAllowedLink() {
        let link = newAllowedLink.trimmingCharacters(in: .whitespaces)
        guard !link.isEmpty, !settings.allowedLinks.contains(link) else { return }
        settings.allowedLinks.append(link)
        newAllowedLink = ""
        hasChanges = true
    }

    private var regexEditor: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            FlowLayout(spacing: .spacing6) {
                ForEach(settings.blockedRegex, id: \.self) { pattern in
                    HStack(spacing: 4) {
                        Text(pattern).font(.captionSmall).foregroundStyle(Color.textPrimary)
                        Button {
                            settings.blockedRegex.removeAll { $0 == pattern }
                            hasChanges = true
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, .spacing8).padding(.vertical, 4)
                    .background(Color.bgElevated)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.accentIndigo.opacity(0.3), lineWidth: 1))
                }
            }
            HStack(spacing: .spacing8) {
                TextField("正規表現パターン", text: $newRegex)
                    .font(.bodySmall)
                    .onSubmit { addRegex() }
                Button("追加") { addRegex() }
                    .font(.captionRegular).fontWeight(.semibold)
                    .foregroundStyle(Color.accentIndigo)
                    .disabled(newRegex.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("例: `https?://[^\\s]+` で全URLを検知")
                .font(.captionSmall).foregroundStyle(Color.textTertiary)
        }
    }

    private func addRegex() {
        let pattern = newRegex.trimmingCharacters(in: .whitespaces)
        guard !pattern.isEmpty, !settings.blockedRegex.contains(pattern) else { return }
        settings.blockedRegex.append(pattern)
        newRegex = ""
        hasChanges = true
    }

    private func addKeyword() {
        let kw = newKeyword.trimmingCharacters(in: .whitespaces).lowercased()
        guard !kw.isEmpty, !settings.blockedKeywords.contains(kw) else { return }
        settings.blockedKeywords.append(kw)
        newKeyword = ""
        hasChanges = true
    }

    // ── アカウント保護 ───────────────────────────────────────────

    private var accountSection: some View {
        VStack(spacing: 0) {
            RuleRow(
                title: "最低アカウント年齢",
                description: "作成から\(settings.minAgeDays)日未満のアカウントの発言を制限",
                isOn: Binding(get: { settings.minAgeEnabled }, set: { settings.minAgeEnabled = $0; hasChanges = true })
            ) {
                StepperRow(label: "最低日数", value: Binding(get: { settings.minAgeDays }, set: { settings.minAgeDays = $0; hasChanges = true }), range: 1...365, unit: "日")
            }
            Divider().padding(.leading, 52)
            RuleRow(
                title: "新規メンバー制限",
                description: "参加から\(settings.newMemberMins)分間はメッセージ送信を制限",
                isOn: Binding(get: { settings.newMemberEnabled }, set: { settings.newMemberEnabled = $0; hasChanges = true })
            ) {
                StepperRow(label: "制限時間", value: Binding(get: { settings.newMemberMins }, set: { settings.newMemberMins = $0; hasChanges = true }), range: 1...1440, unit: "分")
            }
            Divider().padding(.leading, 52)
            RuleRow(
                title: "レイド保護",
                description: "\(settings.raidSeconds)秒以内に\(settings.raidJoins)人以上参加でサーバーロック",
                isOn: Binding(get: { settings.raidEnabled }, set: { settings.raidEnabled = $0; hasChanges = true })
            ) {
                VStack(spacing: .spacing12) {
                    StepperRow(label: "参加人数閾値", value: Binding(get: { settings.raidJoins }, set: { settings.raidJoins = $0; hasChanges = true }), range: 3...50, unit: "人")
                    StepperRow(label: "検知秒数",     value: Binding(get: { settings.raidSeconds }, set: { settings.raidSeconds = $0; hasChanges = true }), range: 5...120, unit: "秒")
                }
            }
        }
    }

    // ── アンチヌーク ───────────────────────────────────────────

    private var antinukeSection: some View {
        VStack(spacing: 0) {
            RuleRow(
                title: "チャンネル大量削除保護",
                description: "\(settings.channelDeleteSeconds)秒以内に\(settings.channelDeleteLimit)件以上の削除で検知",
                isOn: Binding(get: { settings.antiNukeEnabled }, set: { settings.antiNukeEnabled = $0; hasChanges = true })
            ) {
                VStack(spacing: .spacing12) {
                    StepperRow(label: "削除閾値", value: Binding(get: { settings.channelDeleteLimit }, set: { settings.channelDeleteLimit = $0; hasChanges = true }), range: 2...10, unit: "件")
                    StepperRow(label: "検知秒数", value: Binding(get: { settings.channelDeleteSeconds }, set: { settings.channelDeleteSeconds = $0; hasChanges = true }), range: 5...60, unit: "秒")
                }
            }
            Divider().padding(.leading, 52)
            RuleRow(
                title: "ロール大量削除保護",
                description: "\(settings.roleDeleteSeconds)秒以内に\(settings.roleDeleteLimit)件以上の削除で検知",
                isOn: Binding(get: { settings.roleDeleteEnabled }, set: { settings.roleDeleteEnabled = $0; hasChanges = true })
            ) {
                VStack(spacing: .spacing12) {
                    StepperRow(label: "削除閾値", value: Binding(get: { settings.roleDeleteLimit }, set: { settings.roleDeleteLimit = $0; hasChanges = true }), range: 2...10, unit: "件")
                    StepperRow(label: "検知秒数", value: Binding(get: { settings.roleDeleteSeconds }, set: { settings.roleDeleteSeconds = $0; hasChanges = true }), range: 5...60, unit: "秒")
                }
            }
            Divider().padding(.leading, 52)
            RuleRow(
                title: "大量BAN保護",
                description: "\(settings.massBanSeconds)秒以内に\(settings.massBanLimit)人以上のBANで検知",
                isOn: Binding(get: { settings.massBanEnabled }, set: { settings.massBanEnabled = $0; hasChanges = true })
            ) {
                VStack(spacing: .spacing12) {
                    StepperRow(label: "BAN閾値", value: Binding(get: { settings.massBanLimit }, set: { settings.massBanLimit = $0; hasChanges = true }), range: 3...20, unit: "人")
                    StepperRow(label: "検知秒数", value: Binding(get: { settings.massBanSeconds }, set: { settings.massBanSeconds = $0; hasChanges = true }), range: 10...120, unit: "秒")
                }
            }
        }
    }

    // ── アクション設定 ───────────────────────────────────────────

    private var actionSection: some View {
        VStack(spacing: 0) {
            // エスカレーション設定
            RuleRow(
                title: "自動エスカレーション",
                description: "違反回数に応じて処罰を強化",
                isOn: Binding(get: { settings.escalationEnabled }, set: { settings.escalationEnabled = $0; hasChanges = true })
            ) {
                VStack(spacing: .spacing8) {
                    ForEach(settings.escalationSteps) { step in
                        HStack(spacing: .spacing8) {
                            Image(systemName: step.violations <= 3 ? "exclamationmark.triangle.fill" : step.violations <= 10 ? "hand.raised.fill" : "hand.raised.slash.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(step.violations <= 3 ? Color.accentOrange : step.violations <= 10 ? Color.accentPurple : .accentRed)
                                .frame(width: 16)
                            Text(step.summary)
                                .font(.captionRegular)
                                .foregroundStyle(Color.textSecondary)
                            Spacer()
                        }
                    }
                }
                .padding(.spacing10)
                .background(Color.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
            }
            Divider().padding(.leading, 52)

            // デフォルトアクション
            VStack(alignment: .leading, spacing: .spacing10) {
                Text("違反時のデフォルトアクション")
                    .font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                ForEach(ViolationAction.allCases, id: \.self) { action in
                    Button {
                        settings.defaultAction = action
                        hasChanges = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: .spacing10) {
                            Image(systemName: action.icon)
                                .font(.system(size: 14)).foregroundStyle(action.color).frame(width: 20)
                            Text(action.rawValue)
                                .font(.bodySmall).foregroundStyle(Color.textPrimary)
                            Spacer()
                            if settings.defaultAction == action {
                                Image(systemName: "checkmark").font(.captionSmall)
                                    .foregroundStyle(Color.accentIndigo)
                            }
                        }
                        .padding(.spacing10)
                        .background(settings.defaultAction == action
                            ? Color.accentIndigo.opacity(0.08) : Color.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.spacing12)

            Divider()

            // タイムアウト時間
            VStack(alignment: .leading, spacing: .spacing10) {
                Text("タイムアウト時間")
                    .font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                let durations = [(10, "10分"), (60, "1時間"), (360, "6時間"), (1440, "24時間"), (4320, "3日"), (10080, "1週間")]
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: .spacing8) {
                    ForEach(durations, id: \.0) { mins, label in
                        Button {
                            settings.timeoutMinutes = mins; hasChanges = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text(label)
                                .font(.captionRegular)
                                .foregroundStyle(settings.timeoutMinutes == mins ? .white : Color.textSecondary)
                                .padding(.horizontal, .spacing8).padding(.vertical, .spacing6)
                                .background(settings.timeoutMinutes == mins ? Color.accentPurple : Color.bgElevated)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.spacing12)

            Divider()

            // ログチャンネル
            RuleRow(
                title: "違反ログ",
                description: settings.logChannelName.isEmpty ? "ログチャンネル未設定" : "#\(settings.logChannelName)",
                isOn: Binding(get: { settings.logEnabled }, set: { settings.logEnabled = $0; hasChanges = true })
            ) {
                HStack(spacing: .spacing8) {
                    Image(systemName: "number").foregroundStyle(Color.textTertiary)
                    TextField("チャンネル名", text: Binding(get: { settings.logChannelName }, set: { settings.logChannelName = $0; hasChanges = true }))
                        .font(.bodySmall)
                }
                .padding(.spacing10)
                .background(Color.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
            }
        }
    }

    // ── 除外設定 ─────────────────────────────────────────────────

    private var exemptSection: some View {
        VStack(spacing: 0) {
            ExemptEditor(
                title: "除外ロール",
                subtitle: "指定ロールを持つメンバーはAutoModをバイパス",
                icon: "shield.fill",
                items: Binding(get: { settings.exemptRoles }, set: { settings.exemptRoles = $0; hasChanges = true }),
                placeholder: "ロール名を追加（例: モデレーター）"
            )
            Divider()
            ExemptEditor(
                title: "除外チャンネル",
                subtitle: "指定チャンネルではAutoModが動作しない",
                icon: "number",
                items: Binding(get: { settings.exemptChannels }, set: { settings.exemptChannels = $0; hasChanges = true }),
                placeholder: "チャンネル名を追加（例: bot-commands）"
            )
        }
    }
}

// MARK: - AutoModSectionCard

    private struct AutoModSectionCard<Content: View>: View {
        let section: AutoModSettingsView.AutoModSection
        let isExpanded: Bool
        let onToggle: () -> Void
        @ViewBuilder let content: () -> Content

        var body: some View {
            VStack(spacing: 0) {
                Button(action: onToggle) {
                    HStack(spacing: .spacing12) {
                        Image(systemName: section.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(section.color)
                            .frame(width: 36, height: 36)
                            .background(section.color.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text(section.rawValue)
                            .font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.captionSmall).foregroundStyle(Color.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 0 : -90))
                            .animation(.spring(duration: 0.25), value: isExpanded)
                    }
                    .padding(.horizontal, .spacing12)
                    .padding(.vertical, .spacing10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Divider()
                    content()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            .overlay(RoundedRectangle(cornerRadius: .cornerRadiusMedium).stroke(Color.border, lineWidth: 1))
            .animation(.spring(duration: 0.3), value: isExpanded)
        }
    }

// MARK: - RuleRow

private struct RuleRow<Detail: View>: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    @ViewBuilder var detail: () -> Detail

    init(title: String, description: String, isOn: Binding<Bool>,
         @ViewBuilder detail: @escaping () -> Detail = { EmptyView() }) {
        self.title = title
        self.description = description
        self._isOn = isOn
        self.detail = detail
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: .spacing12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.bodySmall).fontWeight(.medium).foregroundStyle(Color.textPrimary)
                    Text(description).font(.captionSmall).foregroundStyle(Color.textTertiary).lineLimit(2)
                }
                Spacer()
                Toggle("", isOn: $isOn)
                    .tint(Color.accentIndigo)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .padding(.horizontal, .spacing12)
            .padding(.vertical, .spacing10)
            .contentShape(Rectangle())

            if isOn, !(detail() is EmptyView) {
                Divider()
                    .padding(.leading, 52)
                detail()
                    .padding(.horizontal, .spacing12)
                    .padding(.bottom, .spacing10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }
}

// MARK: - StepperRow

private struct StepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        HStack {
            Text(label).font(.captionRegular).foregroundStyle(Color.textSecondary)
            Spacer()
            HStack(spacing: .spacing12) {
                Button {
                    if value > range.lowerBound { value -= 1 }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(value > range.lowerBound ? Color.accentIndigo : Color.textTertiary)
                }
                .buttonStyle(.plain)

                Text("\(value)\(unit)")
                    .font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                    .frame(minWidth: 60, alignment: .center)

                Button {
                    if value < range.upperBound { value += 1 }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(value < range.upperBound ? Color.accentIndigo : Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - ExemptEditor

private struct ExemptEditor: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var items: [String]
    let placeholder: String
    @State private var newItem = ""

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing10) {
            HStack(spacing: .spacing8) {
                Image(systemName: icon).font(.captionSmall).foregroundStyle(Color.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                    Text(subtitle).font(.captionSmall).foregroundStyle(Color.textTertiary)
                }
            }
            if !items.isEmpty {
                FlowLayout(spacing: .spacing6) {
                    ForEach(items, id: \.self) { item in
                        HStack(spacing: 4) {
                            Image(systemName: icon).font(.system(size: 10)).foregroundStyle(Color.textTertiary)
                            Text(item).font(.captionSmall).foregroundStyle(Color.textPrimary)
                            Button {
                                items.removeAll { $0 == item }
                            } label: {
                                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, .spacing8).padding(.vertical, 4)
                        .background(Color.bgElevated)
                        .clipShape(Capsule())
                    }
                }
            }
            HStack(spacing: .spacing8) {
                TextField(placeholder, text: $newItem)
                    .font(.captionRegular).onSubmit { addItem() }
                Button("追加") { addItem() }
                    .font(.captionSmall).fontWeight(.semibold).foregroundStyle(Color.accentIndigo)
                    .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.spacing12)
    }

    private func addItem() {
        let t = newItem.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !items.contains(t) else { return }
        items.append(t); newItem = ""
    }
}

// MARK: - FlowLayout（タグの折り返し）

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0; var x: CGFloat = 0; var rowH: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 { height += rowH + spacing; x = 0; rowH = 0 }
            x += size.width + spacing; rowH = max(rowH, size.height)
        }
        return CGSize(width: width, height: height + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; rowH = max(rowH, size.height)
        }
    }
}

#Preview {
    NavigationStack { AutoModSettingsView() }
}
