import SwiftUI
import AppKit

// MARK: - Editable Component Modifier
// 編集モードでタップ選択・ハイライト・ホバー表示を行うViewModifier

private struct EditableComponentModifier: ViewModifier {
    let path: String
    let cornerRadius: CGFloat
    @State private var state = EditorState.shared
    @State private var isHovered = false

    private var isSelected: Bool {
        state.editorMode == .edit && state.selectedComponentPath == path
    }
    private var shortName: String {
        path.components(separatedBy: "/").last ?? path
    }

    func body(content: Content) -> some View {
        content
            // ── 選択時の青枠ボーダー ──
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.accentIndigo, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            // ── 選択時のコンポーネント名ラベル ──
            .overlay(alignment: .topLeading) {
                if isSelected {
                    Text(shortName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentIndigo)
                        .clipShape(Capsule())
                        .padding(.top, 5).padding(.leading, 6)
                        .allowsHitTesting(false)
                }
            }
            // ── 編集モード: 透明タップキャプチャ層 + ホバー効果 ──
            .overlay {
                if state.editorMode == .edit {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            isSelected
                                ? Color.accentIndigo.opacity(0.07)
                                : (isHovered ? Color.accentIndigo.opacity(0.04) : .clear)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                state.selectedComponentPath = path
                            }
                        }
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isHovered = hovering
                            }
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                }
            }
    }
}

extension View {
    fileprivate func editableComponent(path: String, cornerRadius: CGFloat = 10) -> some View {
        modifier(EditableComponentModifier(path: path, cornerRadius: cornerRadius))
    }
}

// MARK: - PreviewCanvas

struct PreviewCanvas: View {
    @State private var editorState = EditorState.shared
    @State private var selectedScreen = "Dashboard"
    @State private var screenshotMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            canvasArea
        }
        // コンポーネントツリーから選択されたとき、対応タブへ自動切替
        .onChange(of: editorState.selectedComponentPath) { _, newPath in
            guard let path = newPath else { return }
            let tab: String
            if path.contains("/Features")   { tab = "Features" }
            else if path.contains("/Automation")  { tab = "Automation" }
            else if path.contains("/Moderation")  { tab = "Moderation" }
            else                                  { tab = "Dashboard" }
            if selectedScreen != tab {
                withAnimation(.easeInOut(duration: 0.2)) { selectedScreen = tab }
            }
        }
        // プレビューモードへの切替時に選択解除
        .onChange(of: editorState.editorMode) { _, newMode in
            if newMode == .preview {
                editorState.selectedComponentPath = nil
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            // ── モード切替 ──
            modePicker

            Divider().frame(height: 20)

            // ── 画面タブ ──
            Picker("", selection: $selectedScreen) {
                Text("ダッシュボード").tag("Dashboard")
                Text("機能").tag("Features")
                Text("自動化").tag("Automation")
                Text("モデレーション").tag("Moderation")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            Spacer()

            if let msg = screenshotMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .transition(.opacity)
            }

            Button(action: captureScreenshot) {
                Label("スクリーンショット", systemImage: "camera.fill")
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var modePicker: some View {
        HStack(spacing: 1) {
            modeButton(icon: "pencil",    label: "編集",     mode: .edit)
            modeButton(icon: "play.fill", label: "プレビュー", mode: .preview)
        }
        .fixedSize()   // テキストが縦になるのを防ぐ
        .padding(2)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
        .background(Color.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.border, lineWidth: 1))
    }

    private func modeButton(icon: String, label: String, mode: EditorMode) -> some View {
        let isActive = editorState.editorMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                editorState.editorMode = mode
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(isActive ? .white : .textSecondary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(isActive ? Color.accentIndigo : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Canvas

    private var canvasArea: some View {
        GeometryReader { geometry in
            let availH = geometry.size.height - 32
            let scale  = min(0.88, availH / 812)

            ZStack {
                canvasBackground
                iPhoneMockFrame(scale: scale) {
                    previewContent
                }
                // 編集モードのオーバーレイヒント
                if editorState.editorMode == .edit {
                    editModeHint
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // 編集モード時のヒントテキスト（下部）
    private var editModeHint: some View {
        VStack {
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "cursorarrow.click")
                    .font(.system(size: 10))
                Text("コンポーネントをタップして選択")
                    .font(.system(size: 10))
            }
            .foregroundColor(.textTertiary)
            .padding(.bottom, 12)
        }
    }

    private var canvasBackground: some View {
        Color(nsColor: NSColor(hex: 0x1E1E1E))
            .overlay {
                Canvas { context, size in
                    guard size.width.isFinite, size.height.isFinite,
                          size.width > 0, size.height > 0,
                          size.width < 4000, size.height < 4000 else { return }
                    let spacing: CGFloat = 24
                    let dotSize: CGFloat = 1.5
                    let color = Color.white.opacity(0.07)
                    var x: CGFloat = spacing
                    while x < size.width {
                        var y: CGFloat = spacing
                        while y < size.height {
                            context.fill(
                                Path(ellipseIn: CGRect(x: x, y: y, width: dotSize, height: dotSize)),
                                with: .color(color)
                            )
                            y += spacing
                        }
                        x += spacing
                    }
                }
            }
    }

    // MARK: - Preview Content

    @ViewBuilder
    private var previewContent: some View {
        switch selectedScreen {
        case "Dashboard":   DashboardPreview()
        case "Features":    FeaturesPreview()
        case "Automation":  AutomationPreview()
        case "Moderation":  ModerationPreview()
        default:            DashboardPreview()
        }
    }

    // MARK: - Screenshot

    private func captureScreenshot() {
        guard let window = NSApplication.shared.keyWindow else { return }
        if let path = ScreenshotManager.shared.captureView(window.contentView!) {
            editorState.lastScreenshotPath = path
            withAnimation {
                screenshotMessage = "保存: \((path as NSString).lastPathComponent)"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { screenshotMessage = nil }
            }
        }
    }
}

// MARK: - iOS Status Bar

private struct iOSStatusBar: View {
    var body: some View {
        HStack {
            Text("9:41")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.textPrimary)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "cellularbars")
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "wifi")
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: "battery.100")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 54)
        .padding(.bottom, 6)
    }
}

// MARK: - iOS Navigation Bar

private struct iOSNavBar: View {
    let title: String
    var large: Bool = true

    var body: some View {
        if large {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
        } else {
            ZStack {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
        }
    }
}

// MARK: - Dashboard Preview
// 各セクションに editableComponent() を適用して双方向選択に対応

struct DashboardPreview: View {
    @State private var state = EditorState.shared

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Color.clear.frame(height: 106)

                    greetingSection
                    botStatusCard
                    notifSection
                    quickActionsSection
                    activitySection

                    Color.clear.frame(height: 90)
                }
            }
            .background(Color.bgPrimary)

            VStack(spacing: 0) {
                iOSStatusBar()
                iOSNavBar(title: "ホーム")
            }
            .background(Color.bgPrimary.opacity(0.95))
            .allowsHitTesting(false)  // 編集モードでのタップを邪魔しない
        }
    }

    // MARK: Greeting + Server Selector

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── WelcomeCard ──
            VStack(alignment: .leading, spacing: 3) {
                Text("こんにちは 👋")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                Text("Welcome back!")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .editableComponent(
                path: "RootView/MainTabView/Dashboard/Header/WelcomeCard",
                cornerRadius: 8
            )

            // ── ServerSelector ──
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentIndigo.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "server.rack")
                            .font(.system(size: 13))
                            .foregroundColor(.accentIndigo)
                    }
                Text("My Server")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.border, lineWidth: 1))
            .editableComponent(
                path: "RootView/MainTabView/Dashboard/Header/ServerSelector",
                cornerRadius: 10
            )
        }
        .padding(.horizontal, 16)
    }

    // MARK: Bot Status Card (選択可能だがツリーにはないのでインジケーターなし)

    private var botStatusCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.accentIndigo, .accentPurple],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 48, height: 48)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Noxy Bot")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)
                HStack(spacing: 5) {
                    Circle().fill(Color.accentGreen).frame(width: 7, height: 7)
                    Text("オンライン")
                        .font(.system(size: 12))
                        .foregroundColor(.accentGreen)
                    Text("· 42ms")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    // MARK: Notification Feed

    private var notifSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("お知らせ")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSecondary)
                Text("2件")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.accentRed)
                    .clipShape(Capsule())
                Spacer()
            }
            .padding(.horizontal, 16)

            VStack(spacing: 0) {
                notifRow(
                    icon: "ticket.fill", color: .accentOrange,
                    label: "チケット", time: "3分前",
                    title: "新着チケット",
                    detail: "ロールについて質問があります"
                )
                Divider().padding(.leading, 52)
                notifRow(
                    icon: "exclamationmark.triangle.fill", color: .accentRed,
                    label: "モデレーション", time: "1時間前",
                    title: "警告: user#1234",
                    detail: "スパム送信による警告"
                )
            }
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
        .editableComponent(
            path: "RootView/MainTabView/Dashboard/Notifications",
            cornerRadius: 6
        )
    }

    private func notifRow(icon: String, color: Color, label: String, time: String, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.14))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(color)
                }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(label).font(.system(size: 10, weight: .semibold)).foregroundColor(color)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(color.opacity(0.12)).clipShape(Capsule())
                    Text(time).font(.system(size: 10)).foregroundColor(.textTertiary)
                }
                Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(.textPrimary).lineLimit(1)
                Text(detail).font(.system(size: 11)).foregroundColor(.textSecondary).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundColor(.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("クイックアクション")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSecondary)
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "pencil").font(.system(size: 10, weight: .semibold))
                    Text("編集").font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.accentIndigo)
            }
            .padding(.horizontal, 16)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                quickActionCard(icon: "rectangle.stack.badge.plus", title: "Embed作成", subtitle: "テンプレート作成", color: .accentIndigo)
                quickActionCard(icon: "ticket.fill",                title: "チケット",  subtitle: "サポート対応",     color: .accentOrange)
                quickActionCard(icon: "person.3.fill",              title: "メンバー",  subtitle: "メンバー管理",     color: .accentPurple)
                quickActionCard(icon: "shield.lefthalf.filled",     title: "モデレーション", subtitle: "BAN・警告",  color: .accentRed)
            }
            .padding(.horizontal, 16)
        }
        .editableComponent(
            path: "RootView/MainTabView/Dashboard/QuickActions",
            cornerRadius: 6
        )
    }

    private func quickActionCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(.textPrimary)
                Text(subtitle).font(.system(size: 11)).foregroundColor(.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Recent Activity / StatsGrid

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("サーバーの状況")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                activityRow(icon: "🎫", text: "user#5678 がチケットを作成", time: "5分前")
                Divider().padding(.leading, 52)
                activityRow(icon: "🛡", text: "automod がスパムをブロック", time: "12分前")
                Divider().padding(.leading, 52)
                activityRow(icon: "👤", text: "new_member がサーバーに参加", time: "1時間前")
            }
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
        .editableComponent(
            path: "RootView/MainTabView/Dashboard/StatsGrid",
            cornerRadius: 6
        )
    }

    private func activityRow(icon: String, text: String, time: String) -> some View {
        HStack(spacing: 10) {
            Text(icon).font(.system(size: 18)).frame(width: 32)
            Text(text).font(.system(size: 13)).foregroundColor(.textPrimary).lineLimit(1)
            Spacer()
            Text(time).font(.system(size: 11)).foregroundColor(.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

// MARK: - Features Preview

struct FeaturesPreview: View {
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 106)

                    featureSection("コンテンツ", items: [
                        FeatureItem(icon: "rectangle.stack.fill", title: "埋め込みメッセージ", subtitle: "Embedテンプレートの作成・送信", color: .accentIndigo, badge: nil),
                    ])
                    featureSection("コミュニティ", items: [
                        FeatureItem(icon: "person.3.fill",        title: "メンバー",     subtitle: "メンバー一覧と管理",            color: .accentIndigo, badge: nil),
                        FeatureItem(icon: "checkmark.shield.fill", title: "認証",        subtitle: "CAPTCHA認証でロールを自動付与",  color: .accentGreen,  badge: "Pro"),
                        FeatureItem(icon: "ticket.fill",          title: "チケット",    subtitle: "サポートチケットの管理",          color: .accentOrange, badge: "Pro"),
                        FeatureItem(icon: "waveform.and.mic",     title: "一時チャンネル", subtitle: "参加すると自動でVCを作成",      color: .accentPurple, badge: "Pro"),
                        FeatureItem(icon: "chart.bar.fill",       title: "レベリング",  subtitle: "XP・リーダーボード",             color: .accentIndigo, badge: "近日"),
                        FeatureItem(icon: "gift.fill",            title: "ギブアウェイ", subtitle: "景品プレゼント抽選",             color: .accentPink,  badge: "近日"),
                    ])
                    featureSection("自動化・通知", items: [
                        FeatureItem(icon: "heart.fill",           title: "リアクションロール", subtitle: "リアクションでロールを自動付与", color: .accentPink, badge: "Pro"),
                        FeatureItem(icon: "hand.wave.fill",       title: "入退室メッセージ",  subtitle: "参加・退室時の自動メッセージ",  color: .accentGreen, badge: nil),
                    ])
                    featureSection("モデレーション", items: [
                        FeatureItem(icon: "shield.lefthalf.filled", title: "モデレーション", subtitle: "BAN・タイムアウト・警告を一括管理", color: .accentRed, badge: nil),
                    ])
                    featureSection("ツール", items: [
                        FeatureItem(icon: "cart.fill",           title: "ショップ",          subtitle: "商品販売・注文管理",               color: .accentGreen,  badge: "Pro"),
                        FeatureItem(icon: "chart.bar.xaxis",     title: "ステータスチャンネル", subtitle: "メンバー数などをVC名に表示",    color: .accentPurple, badge: "Pro"),
                    ])

                    Color.clear.frame(height: 90)
                }
            }
            .background(Color(nsColor: NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.09, alpha: 1)))

            VStack(spacing: 0) {
                iOSStatusBar()
                iOSNavBar(title: "機能")
            }
            .background(Color(nsColor: NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.09, alpha: 1)).opacity(0.96))
            .allowsHitTesting(false)
        }
    }

    private struct FeatureItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
        let color: Color
        let badge: String?
    }

    @ViewBuilder
    private func featureSection(_ title: String, items: [FeatureItem]) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    featureRow(item)
                    if idx < items.count - 1 {
                        Divider().padding(.leading, 54)
                    }
                }
            }
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
    }

    private func featureRow(_ item: FeatureItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(item.color)
                .frame(width: 30, height: 30)
                .background(item.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(item.title)
                        .font(.system(size: 15))
                        .foregroundColor(item.badge == "近日" ? .textTertiary : .textPrimary)
                    if let badge = item.badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background {
                                if badge == "近日" {
                                    Color.textTertiary
                                } else {
                                    LinearGradient(colors: [.accentOrange, .accentPink], startPoint: .leading, endPoint: .trailing)
                                }
                            }
                            .clipShape(Capsule())
                    }
                }
                Text(item.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if item.badge == "近日" {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .opacity(item.badge == "近日" ? 0.5 : 1.0)
    }
}

// MARK: - Automation Preview

struct AutomationPreview: View {
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 106)

                    sectionHeader("自動化")
                    automationList

                    sectionHeader("モデレーション")
                    moderationList

                    Color.clear.frame(height: 90)
                }
            }
            .background(Color(nsColor: NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.09, alpha: 1)))

            VStack(spacing: 0) {
                iOSStatusBar()
                iOSNavBar(title: "自動化")
            }
            .background(Color(nsColor: NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.09, alpha: 1)).opacity(0.96))
            .allowsHitTesting(false)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    private var automationList: some View {
        VStack(spacing: 0) {
            automationRow(icon: "bubble.left.and.text.bubble.right.fill",
                          title: "自動返信", subtitle: "キーワード → 返信の自動化", color: .accentIndigo)
            Divider().padding(.leading, 54)
            automationRow(icon: "heart.fill",
                          title: "リアクションロール", subtitle: "リアクションでロールを付与", color: .accentPink)
            Divider().padding(.leading, 54)
            automationRow(icon: "arrow.left.arrow.right.circle.fill",
                          title: "入退室メッセージ", subtitle: "参加・退室時の自動メッセージ", color: .accentGreen)
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private var moderationList: some View {
        VStack(spacing: 0) {
            automationRow(icon: "shield.fill",
                          title: "自動モデレーション", subtitle: "スパム・大文字・メンション制限", color: .accentRed,
                          locked: true)
            Divider().padding(.leading, 54)
            automationRow(icon: "nosign",
                          title: "ワードフィルター", subtitle: "特定ワードをブロック", color: .accentRed,
                          locked: true)
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private func automationRow(icon: String, title: String, subtitle: String, color: Color, locked: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(locked ? .textTertiary : color)
                .frame(width: 36, height: 36)
                .background((locked ? Color.textTertiary : color).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15)).foregroundColor(locked ? .textTertiary : .textPrimary)
                Text(subtitle).font(.system(size: 12)).foregroundColor(.textSecondary).lineLimit(1)
            }

            Spacer()

            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .opacity(locked ? 0.5 : 1.0)
    }
}

// MARK: - Moderation Preview
// プレビューモードでタブ操作が可能

struct ModerationPreview: View {
    @State private var selectedTab = 0

    private let tabs = [
        ("hand.raised.slash.fill", "BANリスト", Color.accentRed),
        ("timer",                  "タイムアウト", Color.accentPurple),
        ("exclamationmark.triangle.fill", "警告管理", Color.accentOrange),
        ("shield.lefthalf.filled.badge.checkmark", "AutoMod", Color.accentIndigo),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            tabContent
                .padding(.top, 148)

            VStack(spacing: 0) {
                iOSStatusBar()
                iOSNavBar(title: "モデレーション", large: false)
                tabBar
            }
            .background(Color.bgSurface.opacity(0.97))
        }
        .background(Color.bgPrimary)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { idx, tab in
                Button { selectedTab = idx } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.0)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selectedTab == idx ? tab.2 : .textTertiary)
                        Text(tab.1)
                            .font(.system(size: 9, weight: selectedTab == idx ? .semibold : .regular))
                            .foregroundColor(selectedTab == idx ? tab.2 : .textTertiary)
                        Rectangle()
                            .fill(selectedTab == idx ? tab.2 : Color.clear)
                            .frame(height: 2)
                            .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.bgSurface)
        .overlay(Divider(), alignment: .bottom)
    }

    @ViewBuilder
    private var tabContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                switch selectedTab {
                case 0: banListContent
                case 1: timeoutContent
                case 2: warningContent
                default: autoModContent
                }
                Color.clear.frame(height: 90)
            }
        }
        .background(Color.bgPrimary)
    }

    private var banListContent: some View {
        VStack(spacing: 0) {
            modRow(avatar: "🚫", name: "bad_actor#0001", detail: "スパム大量送信", time: "2日前", color: .accentRed)
            Divider().padding(.leading, 54)
            modRow(avatar: "⛔", name: "troll_user#9999", detail: "荒らし行為", time: "5日前", color: .accentRed)
            Divider().padding(.leading, 54)
            modRow(avatar: "🔨", name: "bot_acct#0000", detail: "Bot不正使用", time: "1週間前", color: .accentRed)
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(16)
    }

    private var timeoutContent: some View {
        VStack(spacing: 0) {
            modRow(avatar: "⏱", name: "noisy_user#1234", detail: "連続スパム", time: "30分後解除", color: .accentPurple)
            Divider().padding(.leading, 54)
            modRow(avatar: "⏰", name: "rule_breaker#5678", detail: "暴言", time: "2時間後解除", color: .accentPurple)
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(16)
    }

    private var warningContent: some View {
        VStack(spacing: 0) {
            modRow(avatar: "⚠️", name: "member#2345", detail: "規約違反 (1/3)", time: "3時間前", color: .accentOrange)
            Divider().padding(.leading, 54)
            modRow(avatar: "⚠️", name: "member#6789", detail: "不適切な発言 (2/3)", time: "昨日", color: .accentOrange)
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(16)
    }

    private var autoModContent: some View {
        VStack(spacing: 0) {
            autoModRule(icon: "envelope.open.fill", title: "スパムフィルター", subtitle: "5秒間に3件以上で自動削除", enabled: true)
            Divider().padding(.leading, 54)
            autoModRule(icon: "textformat.size", title: "大文字制限", subtitle: "70%以上の大文字でブロック", enabled: true)
            Divider().padding(.leading, 54)
            autoModRule(icon: "at", title: "メンション制限", subtitle: "5人以上のメンションでブロック", enabled: false)
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(16)
    }

    private func modRow(avatar: String, name: String, detail: String, time: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(avatar).font(.system(size: 20)).frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.system(size: 14, weight: .medium)).foregroundColor(.textPrimary)
                Text(detail).font(.system(size: 12)).foregroundColor(.textSecondary)
            }
            Spacer()
            Text(time).font(.system(size: 11)).foregroundColor(.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func autoModRule(icon: String, title: String, subtitle: String, enabled: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.accentIndigo)
                .frame(width: 30, height: 30)
                .background(Color.accentIndigo.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14)).foregroundColor(.textPrimary)
                Text(subtitle).font(.system(size: 11)).foregroundColor(.textSecondary).lineLimit(1)
            }

            Spacer()

            ZStack {
                Capsule().fill(enabled ? Color.accentGreen : Color.bgElevated)
                    .frame(width: 42, height: 24)
                Circle().fill(Color.white)
                    .frame(width: 18, height: 18)
                    .offset(x: enabled ? 9 : -9)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
