import SwiftUI

// MARK: - WobbleModifier

struct WobbleModifier: ViewModifier {
    let isActive: Bool
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onChange(of: isActive) { _, active in
                if active {
                    withAnimation(.easeInOut(duration: 0.11).repeatForever(autoreverses: true)) {
                        angle = 1.4
                    }
                } else {
                    withAnimation(.spring(duration: 0.2)) { angle = 0 }
                }
            }
            .onAppear {
                guard isActive else { return }
                withAnimation(.easeInOut(duration: 0.11).repeatForever(autoreverses: true)) {
                    angle = 1.4
                }
            }
    }
}

extension View {
    func wobble(_ isActive: Bool) -> some View {
        modifier(WobbleModifier(isActive: isActive))
    }
}

// MARK: - RolesListView

struct RolesListView: View {

    var guildId: String = ""

    @State private var roles: [DiscordRole] = []
    @State private var isLoadingRoles = false

    @State private var isReordering      = false
    @State private var editMode: EditMode = .inactive

    // 並び替えモード突入時にスナップショット → キャンセル時に戻す
    @State private var reorderSnapshot: [DiscordRole] = []

    @State private var showCreateSheet  = false
    @State private var showDiscardAlert = false
    @State private var isSavingOrder    = false
    @State private var saveOrderSuccess = false

    private var orderChangedFromSnapshot: Bool {
        roles.map(\.id) != reorderSnapshot.map(\.id)
    }

    private var noxyRole:   DiscordRole? { roles.first(where: \.managed) }
    private var noxyIndex:  Int?         { noxyRole.flatMap { n in roles.firstIndex(where: { $0.id == n.id }) } }
    private var noxyNeedsWarning: Bool   { (noxyIndex ?? 0) != 1 && noxyRole != nil }

    var body: some View {
        ZStack(alignment: .bottom) {
            roleList
                // バナーをリストの上に固定（スクロールしても動かない）
                .safeAreaInset(edge: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        if noxyNeedsWarning { noxyWarningBanner }
                        if isReordering     { reorderModeBanner }
                    }
                }

            if isReordering && orderChangedFromSnapshot {
                orderSaveBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: orderChangedFromSnapshot)
        .animation(.spring(duration: 0.25), value: isReordering)
        .animation(.easeInOut(duration: 0.2), value: noxyNeedsWarning)
        .navigationTitle("ロール管理")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(isReordering)
        .environment(\.editMode, $editMode)
        .toolbar { toolbarContent }
        .task { await loadRoles() }
        .refreshable { await loadRoles() }
        .onChange(of: guildId) { _, _ in Task { await loadRoles() } }
        .sheet(isPresented: $showCreateSheet) {
            CreateRoleSheet(guildId: guildId) { role in
                roles.insert(role, at: max(1, roles.count - 1))
                recalcPositions()
            }
        }
        .alert("変更を破棄しますか？", isPresented: $showDiscardAlert) {
            Button("破棄してキャンセル", role: .destructive) {
                roles = reorderSnapshot
                exitReorderMode()
            }
            Button("並び替えを続ける", role: .cancel) {}
        } message: {
            Text("並び順の変更が保存されていません。")
        }
    }

    // MARK: - Noxy Warning Banner

    private var noxyWarningBanner: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            HStack(spacing: .spacing10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentOrange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Noxyの権限位置が低すぎます")
                        .font(.bodySmall).fontWeight(.bold).foregroundStyle(Color.textPrimary)
                    Text("ボットのロールが下位だと一部機能が動作しません")
                        .font(.captionSmall).foregroundStyle(Color.textSecondary)
                }

                Spacer()

                if let i = noxyIndex {
                    Text("現在 \(i + 1)番目")
                        .font(.captionSmall).fontWeight(.semibold)
                        .foregroundStyle(Color.accentOrange)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.accentOrange.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: .spacing8) {
                affectedBadge("ロール付与・剥奪", icon: "shield")
                affectedBadge("タイムアウト",     icon: "timer")
                affectedBadge("キック・BAN",      icon: "person.badge.minus")
            }

            Button(action: fixNoxyPosition) {
                Label("今すぐ自動修正する", systemImage: "arrow.up.circle.fill")
                    .font(.captionRegular).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 36)
                    .background(Color.accentIndigo)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
            }
            .buttonStyle(.plain)
        }
        .padding(.spacing16)
        .background(Color.accentOrange.opacity(0.1))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.accentOrange.opacity(0.35)).frame(height: 1)
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.accentOrange).frame(width: 4)
        }
    }

    private func affectedBadge(_ label: String, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9, weight: .semibold))
            Text(label).font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(Color.accentRed)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Color.accentRed.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Reorder Mode Banner

    private var reorderModeBanner: some View {
        HStack(spacing: .spacing10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentIndigo)

            VStack(alignment: .leading, spacing: 2) {
                Text("並び替えモード")
                    .font(.bodySmall).fontWeight(.bold).foregroundStyle(Color.accentIndigo)
                Text("行をドラッグして順序を変更  •  @everyoneは固定")
                    .font(.captionSmall).foregroundStyle(Color.accentIndigo.opacity(0.7))
            }

            Spacer()

            Image(systemName: "arrow.up.arrow.down.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.accentIndigo.opacity(0.5))
        }
        .padding(.horizontal, .spacing16)
        .padding(.vertical, .spacing12)
        .background(Color.accentIndigo.opacity(0.08))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.accentIndigo.opacity(0.2)).frame(height: 1)
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.accentIndigo).frame(width: 4)
        }
    }

    // MARK: - Role List

    private var roleList: some View {
        List {
            hintRow
                .listRowBackground(Color.bgPrimary)
                .listRowInsets(.init(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
                .moveDisabled(true)

            ForEach(roles) { role in
                roleCell(role)
                    .listRowBackground(Color.bgSurface)
                    .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                    .moveDisabled(!isReordering || role.name == "@everyone")
            }
            .onMove(perform: moveRoles)

            Color.clear.frame(height: isReordering && orderChangedFromSnapshot ? 100 : 40)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .moveDisabled(true)
        }
        .listStyle(.plain)
        .background(Color.bgPrimary)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Role Cell

    @ViewBuilder
    private func roleCell(_ role: DiscordRole) -> some View {
        if isReordering {
            RoleRow(role: role, isReordering: true)
        } else {
            NavigationLink {
                RoleDetailView(
                    role: role,
                    onSaved: { updated in
                        if let i = roles.firstIndex(where: { $0.id == updated.id }) {
                            roles[i] = updated
                        }
                    },
                    onDeleted: {
                        roles.removeAll { $0.id == role.id }
                        recalcPositions()
                    }
                )
            } label: {
                RoleRow(role: role, isReordering: false)
            }
        }
    }

    // MARK: - Hint Row

    private var hintRow: some View {
        HStack(spacing: .spacing6) {
            Image(systemName: isReordering ? "hand.draw" : "hand.tap")
                .font(.captionSmall).foregroundStyle(Color.textTertiary)
            Text(isReordering
                 ? "ドラッグして並び替え。@everyoneは末尾固定。"
                 : "上のロールほど権限が強い。「並び替え」で順序変更。")
                .font(.captionSmall).foregroundStyle(Color.textTertiary)
            Spacer()
            Text("\(roles.count) ロール")
                .font(.captionSmall).foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, .spacing16).padding(.vertical, .spacing6)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isReordering {
            // 並び替え中は左に「キャンセル」
            ToolbarItem(placement: .navigationBarLeading) {
                Button("キャンセル") {
                    if orderChangedFromSnapshot {
                        showDiscardAlert = true
                    } else {
                        exitReorderMode()
                    }
                }
                .foregroundStyle(Color.accentIndigo)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                // 変更なし時は「完了」で素直に抜ける
                Button("完了") {
                    exitReorderMode()
                }
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentIndigo)
            }
        } else {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: .spacing12) {
                    Button("並び替え") { enterReorderMode() }
                        .foregroundStyle(Color.accentIndigo)
                    Button { showCreateSheet = true } label: {
                        Image(systemName: "plus").foregroundStyle(Color.accentIndigo)
                    }
                }
            }
        }
    }

    // MARK: - Order Save Bar

    private var orderSaveBar: some View {
        HStack(spacing: .spacing12) {
            Button {
                withAnimation { roles = reorderSnapshot }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Text("リセット")
                    .font(.bodySmall).foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            }
            .buttonStyle(.plain)

            Button { saveOrder() } label: {
                Group {
                    if isSavingOrder {
                        ProgressView().tint(.white)
                    } else if saveOrderSuccess {
                        Label("保存済み", systemImage: "checkmark").foregroundStyle(.white)
                    } else {
                        Text("並び順を保存").foregroundStyle(.white)
                    }
                }
                .font(.bodySmall).fontWeight(.semibold)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(Color.accentIndigo)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            }
            .buttonStyle(.plain).disabled(isSavingOrder)
        }
        .padding(.horizontal, .spacing16).padding(.vertical, .spacing12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Logic

    private func enterReorderMode() {
        reorderSnapshot = roles
        withAnimation(.spring(duration: 0.3)) {
            isReordering = true
            editMode     = .active
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func exitReorderMode() {
        withAnimation(.spring(duration: 0.3)) {
            isReordering = false
            editMode     = .inactive
        }
        isSavingOrder    = false
        saveOrderSuccess = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func moveRoles(from source: IndexSet, to destination: Int) {
        guard isReordering else { return }
        let everyone = roles.last
        roles.move(fromOffsets: source, toOffset: destination)
        if let e = everyone, roles.last?.id != e.id {
            roles.removeAll { $0.id == e.id }
            roles.append(e)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func recalcPositions() {
        for i in roles.indices { roles[i].position = roles.count - i }
    }

    private func fixNoxyPosition() {
        guard let noxyRole else { return }
        withAnimation(.spring(duration: 0.4)) {
            roles.removeAll { $0.id == noxyRole.id }
            roles.insert(noxyRole, at: min(1, roles.count))
            recalcPositions()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        saveOrder()
    }

    private func loadRoles() async {
        guard !guildId.isEmpty else {
            roles = []
            isLoadingRoles = false
            return
        }
        roles = []
        isLoadingRoles = true
        if let fetched = try? await DiscordService().fetchRoles(guildId: guildId) {
            roles = fetched.sorted { $0.position > $1.position }
        }
        isLoadingRoles = false
    }

    private func saveOrder() {
        isSavingOrder = true
        recalcPositions()
        let positions = roles.map { (id: $0.id, position: $0.position) }
        Task {
            if !guildId.isEmpty {
                try? await DiscordService().reorderRoles(guildId: guildId, positions: positions)
            }
            await MainActor.run {
                isSavingOrder    = false
                saveOrderSuccess = true
                reorderSnapshot  = roles
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            try? await Task.sleep(for: .milliseconds(1500))
            await MainActor.run { saveOrderSuccess = false }
        }
    }
}

// MARK: - RoleRow

private struct RoleRow: View {
    let role: DiscordRole
    let isReordering: Bool

    var body: some View {
        HStack(spacing: .spacing12) {
            Circle()
                .fill(role.swiftUIColor)
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(Color.border, lineWidth: role.color == 0 ? 1 : 0))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: .spacing6) {
                    Text(role.name)
                        .font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                    if role.has(.administrator) { badge("管理者", color: .accentRed) }
                    if role.managed            { badge("Bot",   color: .accentGreen) }
                }
                Text(permissionSummary)
                    .font(.captionSmall).foregroundStyle(Color.textTertiary).lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, .spacing8)
        .contentShape(Rectangle())
        .wobble(isReordering && role.name != "@everyone")
    }

    private func badge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.captionSmall).foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var permissionSummary: String {
        if role.name == "@everyone" { return "全メンバーの基本権限" }
        let bits = role.permissionBits
        if bits & (1 << 3) != 0 { return "すべての権限" }
        let names = RolePermission.all.filter { bits & $0.bit != 0 }.prefix(3).map(\.displayName)
        if names.isEmpty { return "権限なし" }
        let rest = role.permissionBits.nonzeroBitCount - names.count
        return names.joined(separator: "・") + (rest > 0 ? " 他\(rest)件" : "")
    }
}

// MARK: - CreateRoleSheet

private struct CreateRoleSheet: View {
    let guildId: String
    let onCreated: (DiscordRole) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedColor = 0
    @State private var isCreating = false
    @State private var errorMessage: String? = nil
    @FocusState private var focused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()
                VStack(spacing: .spacing20) {
                    VStack(alignment: .leading, spacing: .spacing8) {
                        Text("ロール名").font(.captionSmall).foregroundStyle(Color.textTertiary)
                        TextField("例: モデレーター", text: $name)
                            .font(.bodyRegular).padding(.spacing12)
                            .background(Color.bgSurface)
                            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
                            .overlay(RoundedRectangle(cornerRadius: .cornerRadiusSmall).stroke(Color.border, lineWidth: 1))
                            .focused($focused)
                    }
                    VStack(alignment: .leading, spacing: .spacing8) {
                        Text("ロールカラー").font(.captionSmall).foregroundStyle(Color.textTertiary)
                        colorGrid
                    }
                    if let error = errorMessage {
                        Text(error)
                            .font(.captionSmall)
                            .foregroundStyle(Color.accentRed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer()
                }
                .padding(.spacing16)
            }
            .navigationTitle("ロールを作成").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                        .disabled(isCreating)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await createRole() }
                    } label: {
                        if isCreating {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("作成").fontWeight(.semibold).foregroundStyle(Color.accentIndigo)
                        }
                    }
                    .disabled(isCreating)
                }
            }
            .onAppear { focused = true }
        }
    }

    private func createRole() async {
        isCreating = true
        errorMessage = nil
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let roleName = trimmed.isEmpty ? "新しいロール" : trimmed
        do {
            let created = try await DiscordService().createRole(guildId: guildId, name: roleName, color: selectedColor)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onCreated(created)
            dismiss()
        } catch {
            errorMessage = "ロールの作成に失敗しました。再試行してください。"
            isCreating = false
        }
    }

    private var colorGrid: some View {
        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 6), spacing: .spacing8) {
            ForEach(Color.discordRoleColors, id: \.value) { item in
                Button {
                    selectedColor = item.value
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    ZStack {
                        if item.value == 0 {
                            Circle().stroke(Color.border, lineWidth: 1.5).frame(width: 34, height: 34)
                            Image(systemName: "xmark").font(.captionSmall).foregroundStyle(Color.textTertiary)
                        } else {
                            Circle().fill(Color(uiColor: UIColor(hex: UInt32(item.value)))).frame(width: 34, height: 34)
                        }
                        if selectedColor == item.value {
                            Circle().stroke(Color.white, lineWidth: 2.5).frame(width: 34, height: 34)
                            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    NavigationStack { RolesListView() }
}
