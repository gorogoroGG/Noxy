import SwiftUI

// MARK: - SplashView (Cyber Boot Screen)
//
// Discord Bot 管理アプリ「Noxy」のサイバー起動画面。
// 動画 / Lottie を一切使わず、SwiftUI のみで構成（MeshGradient / Canvas /
// TimelineView）。青紫系の高級感ある近未来トーンで、「システムを起動し、
// サーバーへ接続し、Bot を同期している」印象を演出する。
//
// 起動フロー:
//   1. まずスプラッシュを表示し、進捗をゲート地点（~62%）まで進める。
//   2. その間に AuthManager がセッション復元（ログイン状態の確認）を行う。
//   3. 未ログインなら進捗を一旦ゲートで止め、Discord ログインボタンを
//      ふわっと表示する。ログイン成功後に残りの進捗を進める。
//   4. ログイン済みならそのまま 100% まで進め、「SYSTEM READY」と光の波紋を
//      見せてから onFinished() を呼ぶ。
// 実際のホーム遷移は NoxyApp 側で onFinished と AppState.isAppReady の両方が
// 揃った時点で行う。

struct SplashView: View {
    /// ログイン状態の確認 / ログイン実行に使う
    var authManager: AuthManager
    /// ブートシーケンス（進捗 100% + 完了演出）が終わったときに呼ばれる
    var onFinished: () -> Void = {}

    // 進捗（0...1）を手動で 60fps 更新することで、パーセンテージのカウントアップと
    // ゲートでの一時停止（ログイン待ち）を両立する。
    @State private var progress: Double = 0
    @State private var isReady = false
    @State private var rippleProgress: CGFloat = 0
    @State private var logoGlow: CGFloat = 0
    @State private var appeared = false

    // ログイン関連
    @State private var showLoginButton = false
    @State private var isLoggingIn = false
    @State private var loginError: String? = nil

    /// ログイン確認のために一旦進捗を止めるゲート地点
    private let gateProgress: Double = 0.62
    private let stage1Duration: Double = 2.0   // 0 → gate
    private let stage2Duration: Double = 1.3   // gate → 1.0

    var body: some View {
        ZStack {
            // 1. ベース（漆黒）
            Cyber.base.ignoresSafeArea()

            // 2. アニメーションする青紫メッシュグラデーション（静かに流れる光）
            AnimatedMesh()
                .ignoresSafeArea()
                .opacity(0.92)
                .blur(radius: 0.5)

            // 3. 奥でぼやけて流れるコード断片（世界観の装飾）
            CodeFragmentsLayer()
                .ignoresSafeArea()
                .blur(radius: 2.4)
                .opacity(0.18)

            // 4. グリッド + パーティクル + 流れる光（Canvas で 60fps 描画）
            CyberCanvas()
                .ignoresSafeArea()

            // 5. 周辺減光（ヴィネット）で中央に視線を集める
            RadialGradient(
                colors: [.clear, Cyber.base.opacity(0.85)],
                center: .center,
                startRadius: 120,
                endRadius: 520
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // 6. 中央コンテンツ（ロゴ + ステータス + プログレス + ログ + ログインボタン）
            content

            // 7. 完了時の光の波紋
            RippleOverlay(progress: rippleProgress)
                .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.2)) {
                appeared = true
            }
        }
        .task { await runBootSequence() }
    }

    // MARK: - Center content

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            logoBlock
                .scaleEffect(appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)

            Spacer(minLength: 0)

            VStack(spacing: 16) {
                console
                    .opacity(appeared ? 1 : 0)

                if showLoginButton {
                    loginBlock
                        .transition(
                            .opacity
                                .combined(with: .move(edge: .bottom))
                                .combined(with: .scale(scale: 0.96))
                        )
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
    }

    // MARK: Logo

    private var logoBlock: some View {
        VStack(spacing: 16) {
            Text("NOXY")
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .tracking(12)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Cyber.cyan, Cyber.violet],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Cyber.violet.opacity(0.55 + logoGlow * 0.45),
                        radius: 18 + logoGlow * 26)
                .shadow(color: Cyber.cyan.opacity(logoGlow * 0.6),
                        radius: logoGlow * 34)

            // INITIALIZING ••• / AUTHORIZE TO CONTINUE / SYSTEM READY
            HStack(spacing: 8) {
                if isReady {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Cyber.done)
                        .transition(.scale.combined(with: .opacity))
                }

                Text(centerStatusText)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(isReady ? Cyber.done : Color.white.opacity(0.55))
                    .contentTransition(.opacity)

                // 「Initializing」中だけ ••• を 1→2→3 とリズミカルに表示
                if !isReady && !showLoginButton {
                    InitializingDots(color: Cyber.cyan)
                }
            }
            .animation(.easeOut(duration: 0.4), value: isReady)
            .animation(.easeOut(duration: 0.4), value: showLoginButton)
        }
    }

    private var centerStatusText: String {
        if isReady { return "SYSTEM READY" }
        if showLoginButton { return "AUTHORIZE TO CONTINUE" }
        return "INITIALIZING"
    }

    // MARK: Console (status + progress + log stream)

    private var console: some View {
        VStack(spacing: 14) {
            // ステータス + パーセンテージ
            HStack {
                Text(statusText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: statusText)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Cyber.heat(progress))
                    .monospacedDigit()
            }

            progressBar

            // ターミナル風タイプライターログ（完了時に DONE!! を強制表示）
            LogStream(isComplete: isReady)
                .frame(height: 92)
        }
        // iOS 26 風 Liquid Glass パネル
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Cyber.cyan.opacity(0.35), Cyber.violet.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .opacity(0.9)
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let fillWidth = max(0, geo.size.width * progress)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 4)

                // フル幅のヒートグラデーションを進捗ぶんだけマスク表示。
                // 進むほど右（赤）が現れ、完了に近づくほど赤くなる。
                LinearGradient(
                    colors: [Cyber.cyan, Cyber.indigo, Cyber.violet, Cyber.orange, Cyber.red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width, height: 4)
                .mask(alignment: .leading) {
                    Capsule().frame(width: fillWidth, height: 4)
                }
                .shadow(color: Cyber.heat(progress).opacity(0.85), radius: 8)

                // 先端のグロードット（色も進捗に追従）
                Circle()
                    .fill(.white)
                    .frame(width: 7, height: 7)
                    .shadow(color: Cyber.heat(progress), radius: 6)
                    .offset(x: fillWidth - 3.5)
                    .opacity(progress > 0.01 && progress < 0.999 ? 1 : 0)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 8)
    }

    // MARK: Login block (未ログイン時にふわっと表示)

    private var loginBlock: some View {
        VStack(spacing: 10) {
            Button {
                Task { await performLogin() }
            } label: {
                HStack(spacing: 10) {
                    if isLoggingIn {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text(isLoggingIn ? "ログイン中..." : "Discord でログイン")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Cyber.indigo, Cyber.violet],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Cyber.violet.opacity(0.6), radius: 18, y: 6)
                }
            }
            .disabled(isLoggingIn)
            .buttonStyle(.plain)

            if let loginError {
                Text(loginError)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(Cyber.violet.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Boot sequence driver

    private func runBootSequence() async {
        // ステージ 1: ゲート地点まで進める
        await animateProgress(to: gateProgress, duration: stage1Duration)

        // ログイン状態の確認が終わるのを待つ（通常はすぐ完了）
        while !authManager.authChecked && !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(60))
        }

        // 未ログインならログインボタンを表示し、ログイン成功まで待機
        if !authManager.isLoggedIn {
            withAnimation(.spring(duration: 0.55, bounce: 0.25)) { showLoginButton = true }
            while !authManager.isLoggedIn && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(80))
            }
            withAnimation(.easeOut(duration: 0.4)) { showLoginButton = false }
        }

        guard !Task.isCancelled else { return }

        // ステージ 2: 残りを 100% まで進める
        await animateProgress(to: 1.0, duration: stage2Duration)

        // 完了演出（isReady で LogStream が DONE!! を強制表示し、波紋が奥から膨らむ）
        withAnimation(.easeOut(duration: 0.6)) { isReady = true }
        withAnimation(.easeOut(duration: 0.9)) { logoGlow = 1 }
        withAnimation(.easeOut(duration: 1.2)) { rippleProgress = 1 }

        // DONE!! と波紋を見せてから完了を通知
        try? await Task.sleep(for: .seconds(1.25))
        onFinished()
    }

    /// 進捗を smootherstep カーブで滑らかに（パーセンテージがカウントアップする）
    private func animateProgress(to target: Double, duration: Double) async {
        let start = progress
        let frame = 1.0 / 60.0
        let steps = max(1, Int(duration / frame))
        for i in 1...steps {
            if Task.isCancelled { return }
            let f = Double(i) / Double(steps)
            let eased = f * f * f * (f * (f * 6 - 15) + 10)
            progress = start + (target - start) * eased
            try? await Task.sleep(for: .seconds(frame))
        }
        progress = target
    }

    private func performLogin() async {
        guard !isLoggingIn else { return }
        isLoggingIn = true
        loginError = nil
        do {
            try await authManager.login()
            // 成功すると authManager.isLoggedIn が true になり、ブート待機ループが進む
        } catch {
            let nsError = error as NSError
            // ユーザーがキャンセルした場合はエラー表示しない
            let userCancelled = nsError.domain == "com.apple.AuthenticationServices.WebAuthenticationSession"
                && nsError.code == 1
            if !userCancelled {
                loginError = "ログインに失敗しました"
            }
        }
        isLoggingIn = false
    }

    // MARK: - Helpers

    private var statusText: String {
        if showLoginButton { return "Awaiting authorization..." }
        switch progress {
        case ..<0.25: return "Initializing..."
        case ..<0.55: return "Connecting Services..."
        case ..<0.85: return "Syncing Discord Data..."
        case ..<1.0:  return "Finalizing..."
        default:      return "System Ready"
        }
    }
}

// MARK: - Cyber palette

private enum Cyber {
    static let base       = Color(red: 0.02,  green: 0.025, blue: 0.05)   // 漆黒
    static let navy       = Color(red: 0.05,  green: 0.07,  blue: 0.20)   // 濃紺
    static let navyDeep   = Color(red: 0.03,  green: 0.04,  blue: 0.13)
    static let indigo     = Color(red: 0.36,  green: 0.36,  blue: 0.95)   // 青紫
    static let indigoDeep = Color(red: 0.13,  green: 0.13,  blue: 0.42)
    static let violet     = Color(red: 0.56,  green: 0.36,  blue: 1.0)
    static let violetDeep = Color(red: 0.22,  green: 0.12,  blue: 0.45)
    static let cyan       = Color(red: 0.46,  green: 0.72,  blue: 1.0)
    static let glow       = Color(red: 0.62,  green: 0.56,  blue: 1.0)
    static let orange     = Color(red: 1.0,   green: 0.58,  blue: 0.20)
    static let red        = Color(red: 1.0,   green: 0.27,  blue: 0.32)
    static let done       = Color(red: 0.24,  green: 0.95,  blue: 0.55)   // 完了（DONE!!）

    /// 進捗（0...1）に応じて シアン→紫→橙→赤 へ変化する「ヒート」カラー。
    /// 完了が近づくほど赤くなり、一目で進行度がわかる。
    static func heat(_ p: Double) -> Color {
        let stops: [(Double, (Double, Double, Double))] = [
            (0.0,  (0.46, 0.72, 1.0)),   // cyan
            (0.45, (0.56, 0.36, 1.0)),   // violet
            (0.78, (1.0,  0.58, 0.2)),   // orange
            (1.0,  (1.0,  0.27, 0.32))   // red
        ]
        let x = min(max(p, 0), 1)
        for i in 0..<(stops.count - 1) {
            let (p0, c0) = stops[i]
            let (p1, c1) = stops[i + 1]
            if x <= p1 {
                let t = p0 == p1 ? 0 : (x - p0) / (p1 - p0)
                return Color(
                    red:   c0.0 + (c1.0 - c0.0) * t,
                    green: c0.1 + (c1.1 - c0.1) * t,
                    blue:  c0.2 + (c1.2 - c0.2) * t
                )
            }
        }
        let last = stops[stops.count - 1].1
        return Color(red: last.0, green: last.1, blue: last.2)
    }
}

// MARK: - Animated MeshGradient

private struct AnimatedMesh: View {
    private let meshColors: [Color] = [
        Cyber.navyDeep, Cyber.navy,       Cyber.base,
        Cyber.indigoDeep, Cyber.violetDeep, Cyber.navy,
        Cyber.base,     Cyber.navyDeep,   Cyber.indigoDeep
    ]

    var body: some View {
        if #available(iOS 18.0, *) {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                MeshGradient(width: 3, height: 3, points: meshPoints(t), colors: meshColors)
            }
        } else {
            // iOS 18 未満フォールバック（静的な青紫グラデーション）
            LinearGradient(
                colors: [Cyber.navyDeep, Cyber.indigoDeep, Cyber.violetDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func meshPoints(_ t: Double) -> [SIMD2<Float>] {
        func osc(_ phase: Double, _ speed: Double, _ amp: Float) -> Float {
            Float(sin(t * speed + phase)) * amp
        }
        return [
            SIMD2(0, 0),
            SIMD2(0.5 + osc(0, 0.30, 0.08), 0),
            SIMD2(1, 0),

            SIMD2(0, 0.5 + osc(1, 0.25, 0.08)),
            SIMD2(0.5 + osc(2, 0.40, 0.10), 0.5 + osc(3, 0.35, 0.10)),
            SIMD2(1, 0.5 + osc(4, 0.30, 0.08)),

            SIMD2(0, 1),
            SIMD2(0.5 + osc(5, 0.28, 0.08), 1),
            SIMD2(1, 1)
        ]
    }
}

// MARK: - Cyber Canvas (grid + particles + flowing light)

private struct CyberCanvas: View {
    @State private var start = Date()
    private let particles: [Particle] = (0..<64).map { _ in Particle.random() }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            Canvas { ctx, size in
                drawFlowingLight(ctx, size: size, t: t)
                drawGrid(ctx, size: size, t: t)
                drawParticles(ctx, size: size, t: t)
            }
        }
    }

    private func drawFlowingLight(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        var ctx = ctx
        ctx.blendMode = .plusLighter
        let blobs: [(phaseX: Double, phaseY: Double, color: Color)] = [
            (0.0, 1.2, Cyber.violet),
            (2.5, 0.5, Cyber.indigo)
        ]
        for blob in blobs {
            let cx = (0.5 + 0.32 * sin(t * 0.18 + blob.phaseX)) * size.width
            let cy = (0.45 + 0.30 * cos(t * 0.15 + blob.phaseY)) * size.height
            let radius = size.width * 0.55
            let rect = CGRect(x: cx - radius, y: cy - radius,
                              width: radius * 2, height: radius * 2)
            let shading = GraphicsContext.Shading.radialGradient(
                Gradient(colors: [blob.color.opacity(0.22), .clear]),
                center: CGPoint(x: cx, y: cy),
                startRadius: 0,
                endRadius: radius
            )
            ctx.fill(Path(ellipseIn: rect), with: shading)
        }
    }

    private func drawGrid(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let spacing: CGFloat = 46
        let lineColor = Cyber.cyan.opacity(0.05)
        var path = Path()
        var x: CGFloat = 0
        while x <= size.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += spacing
        }
        var y: CGFloat = 0
        while y <= size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += spacing
        }
        ctx.stroke(path, with: .color(lineColor), lineWidth: 0.5)

        // ゆっくり下へ流れる水平スキャンライン
        let scanY = (t * 0.06).truncatingRemainder(dividingBy: 1) * size.height
        let scanRect = CGRect(x: 0, y: scanY - 1, width: size.width, height: 2)
        ctx.fill(Path(scanRect), with: .color(Cyber.cyan.opacity(0.10)))
    }

    private func drawParticles(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        for p in particles {
            // 上方向へゆっくり移動 + ラップ
            var y = (p.y - t * p.speed).truncatingRemainder(dividingBy: 1)
            if y < 0 { y += 1 }
            let x = p.x + 0.012 * sin(t * 0.3 + p.phase)
            let twinkle = 0.5 + 0.5 * sin(t * p.twinkle + p.phase)
            let opacity = p.baseOpacity * twinkle
            let r = p.radius
            let rect = CGRect(x: x * size.width - r, y: y * size.height - r,
                              width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(p.color.opacity(opacity)))
        }
    }
}

private struct Particle {
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let speed: Double
    let twinkle: Double
    let baseOpacity: Double
    let phase: Double
    let color: Color

    static func random() -> Particle {
        Particle(
            x: .random(in: 0...1),
            y: .random(in: 0...1),
            radius: .random(in: 0.6...1.8),
            speed: .random(in: 0.01...0.05),
            twinkle: .random(in: 0.8...2.4),
            baseOpacity: .random(in: 0.25...0.8),
            phase: .random(in: 0...(.pi * 2)),
            color: Bool.random() ? Cyber.cyan : Cyber.glow
        )
    }
}

// MARK: - Drifting code fragments

private struct CodeFragmentsLayer: View {
    @State private var start = Date()

    private struct Fragment {
        let text: String
        let x: CGFloat
        let y: CGFloat
        let speed: Double
        let fontSize: CGFloat
    }

    private let fragments: [Fragment] = [
        Fragment(text: "ticket.create()",    x: 0.18, y: 0.10, speed: 0.018, fontSize: 14),
        Fragment(text: "guild.sync()",        x: 0.72, y: 0.22, speed: 0.024, fontSize: 16),
        Fragment(text: "verify.check()",      x: 0.40, y: 0.38, speed: 0.015, fontSize: 13),
        Fragment(text: "member.fetch()",      x: 0.85, y: 0.55, speed: 0.020, fontSize: 15),
        Fragment(text: "analytics.load()",    x: 0.12, y: 0.66, speed: 0.022, fontSize: 14),
        Fragment(text: "embed.render()",      x: 0.60, y: 0.80, speed: 0.017, fontSize: 16),
        Fragment(text: "ws.connect()",        x: 0.30, y: 0.92, speed: 0.026, fontSize: 13),
        Fragment(text: "session.auth()",      x: 0.78, y: 0.05, speed: 0.019, fontSize: 14)
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            GeometryReader { geo in
                ZStack {
                    ForEach(Array(fragments.enumerated()), id: \.offset) { _, f in
                        let yNorm = (f.y - t * f.speed).truncatingRemainder(dividingBy: 1)
                        let y = (yNorm < 0 ? yNorm + 1 : yNorm) * geo.size.height
                        Text(f.text)
                            .font(.system(size: f.fontSize, weight: .regular, design: .monospaced))
                            .foregroundStyle(Cyber.cyan.opacity(0.55))
                            .position(x: f.x * geo.size.width, y: y)
                    }
                }
            }
        }
    }
}

// MARK: - Terminal-style typewriter log stream
//
// 1 行ずつ、左から右へ 1 文字ずつ「打たれていく」タイプライター表現。
// 完了した行は上に積まれて少しずつ薄くなり、最下行が現在タイプ中の行。

private struct LogStream: View {
    /// 完了したら現在のタイピングを打ち切って「DONE!!」を強制表示する
    var isComplete: Bool

    @State private var completed: [String] = []
    @State private var current: String = ""
    @State private var doneShown = false

    private let pool = [
        "Loading ticket module...",
        "Syncing guild cache...",
        "Authenticating session...",
        "Connecting websocket...",
        "Loading analytics...",
        "Updating permissions...",
        "Verifying bot state...",
        "Fetching member roster...",
        "Resolving slash commands...",
        "Warming embed renderer...",
        "Negotiating gateway...",
        "Decrypting credentials...",
        "Mounting shard 0/1...",
        "Restoring reaction roles...",
        "Indexing audit log...",
        "Sync complete..."
    ]
    private let prefixes = ["» ", "› ", "✓ ", "· "]
    private let maxLines = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(completed.enumerated()), id: \.offset) { idx, line in
                let recency = completed.count <= 1 ? 1 : Double(idx) / Double(completed.count - 1)
                Text(line)
                    .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(Cyber.cyan.opacity(0.18 + recency * 0.34))
                    .lineLimit(1)
            }

            // 現在タイプ中の行（完了時は DONE!! を強調表示）+ 点滅キャレット
            HStack(spacing: 0) {
                Text(current)
                    .font(.system(size: doneShown ? 13 : 10.5,
                                  weight: doneShown ? .heavy : .regular,
                                  design: .monospaced))
                    .foregroundStyle(doneShown ? Cyber.done : Cyber.cyan.opacity(0.85))
                    .shadow(color: doneShown ? Cyber.done.opacity(0.7) : .clear, radius: 8)
                    .lineLimit(1)
                TypingCaret(color: doneShown ? Cyber.done : Cyber.cyan)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .clipped()
        // isComplete が変わったらタスクを切り替える（false=通常ループ / true=DONE!! 表示）
        .task(id: isComplete) {
            if isComplete {
                await showDone()
            } else {
                await typeLoop()
            }
        }
    }

    private func typeLoop() async {
        while !Task.isCancelled {
            let line = makeLine()
            current = ""
            for ch in line {
                if Task.isCancelled { return }
                current.append(ch)
                // タイピング速度（前回より速め）
                try? await Task.sleep(for: .milliseconds(.random(in: 22...34)))
            }
            // 打ち終わった行を少し見せてから確定
            try? await Task.sleep(for: .milliseconds(160))
            if Task.isCancelled { return }
            completed.append(line)
            if completed.count > maxLines { completed.removeFirst() }
            current = ""
            try? await Task.sleep(for: .milliseconds(70))
        }
    }

    private func showDone() async {
        // タイプ途中の行があれば確定してから DONE!! を打つ
        if !current.isEmpty {
            completed.append(current)
            if completed.count > maxLines { completed.removeFirst() }
        }
        current = ""
        doneShown = true
        let done = "✓ DONE!!"
        for ch in done {
            if Task.isCancelled { return }
            current.append(ch)
            try? await Task.sleep(for: .milliseconds(45))
        }
    }

    private func makeLine() -> String {
        let prefix = prefixes.randomElement() ?? "» "
        let body = pool.randomElement() ?? "Sync complete..."
        return prefix + body
    }
}

// MARK: - Typing caret（タイプ行末で点滅する）

private struct TypingCaret: View {
    var color: Color = Cyber.cyan
    @State private var on = true
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(color.opacity(0.9))
            .frame(width: 6, height: 11)
            .opacity(on ? 1 : 0)
            .padding(.leading, 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                    on = false
                }
            }
    }
}

// MARK: - Initializing dots（••• を 1→2→3 とポンポンと表示して繰り返す）

private struct InitializingDots: View {
    let color: Color
    @State private var visible = 1

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
                    .opacity(i < visible ? 1 : 0.18)
                    .scaleEffect(i < visible ? 1 : 0.55)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(360))
                withAnimation(.spring(duration: 0.25, bounce: 0.55)) {
                    visible = visible % 3 + 1
                }
            }
        }
    }
}

// MARK: - Completion ripple

private struct RippleOverlay: View {
    /// 0 = 停止（ローディング中・非表示）, 0→1 = 完了演出
    var progress: CGFloat

    var body: some View {
        ZStack {
            // 中央から広がる光のフラッシュ（1 山）
            Color.white
                .opacity(Double(sin(progress * .pi)) * 0.18)
                .ignoresSafeArea()
                .blendMode(.plusLighter)

            // 奥から「ワーン」と膨らむグローオーブ（小さく現れて拡大しながらフェード）
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Cyber.cyan.opacity(0.9), Cyber.violet.opacity(0.45), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 130
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(0.04 + progress * 3.4)
                .opacity(Double(sin(progress * .pi)))
                .blendMode(.plusLighter)

            // 同心円の波紋（中心から外へ）
            ForEach(0..<3, id: \.self) { i in
                let p = ringProgress(i)
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Cyber.cyan, Cyber.violet],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .opacity((1 - p) * 0.6),
                        lineWidth: 1.5 + (1 - p) * 1.5
                    )
                    .frame(width: 130, height: 130)
                    .scaleEffect(0.04 + p * 7)
            }
        }
        // ローディング中（progress = 0）は完全に非表示。完了時のみ出現。
        .opacity(progress <= 0.001 ? 0 : 1)
    }

    private func ringProgress(_ i: Int) -> CGFloat {
        let shifted = progress * 1.3 - CGFloat(i) * 0.18
        return min(max(shifted, 0), 1)
    }
}

#Preview {
    SplashView(authManager: AuthManager(services: ServiceContainer.live()))
        .preferredColorScheme(.dark)
}
