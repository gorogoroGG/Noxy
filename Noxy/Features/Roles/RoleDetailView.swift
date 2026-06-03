import SwiftUI

struct RoleDetailView: View {
    let role: DiscordRole
    let onSaved: (DiscordRole) -> Void
    let onDeleted: () -> Void

    @State private var editedRole: DiscordRole
    @State private var activeCategory: RolePermission.Category = .general
    @State private var showColorPicker = false
    @State private var showDeleteAlert = false
    @State private var showDiscardAlert = false
    @State private var isSaving = false
    @State private var saveSuccess = false
    @Environment(\.dismiss) private var dismiss

    init(role: DiscordRole, onSaved: @escaping (DiscordRole) -> Void, onDeleted: @escaping () -> Void) {
        self.role = role
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        self._editedRole = State(initialValue: role)
    }

    var hasChanges: Bool { editedRole != role }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: .spacing12, pinnedViews: [.sectionHeaders]) {
                    roleHeader
                        .padding(.horizontal, .spacing16)
                        .padding(.top, .spacing8)

                    Section {
                        categoryPermissions
                            .padding(.horizontal, .spacing16)
                    } header: {
                        categoryPicker
                    }

                    // メンバー管理セクション
                    memberManagementRow
                        .padding(.horizontal, .spacing16)
                        .padding(.top, .spacing8)

                    if !role.managed {
                        dangerZone
                            .padding(.horizontal, .spacing16)
                            .padding(.top, .spacing4)
                    }

                    Spacer(minLength: 80)
                }
            }

            // Sticky save bar
            if hasChanges && !role.managed {
                VStack {
                    Spacer()
                    saveBar
                }
            }
        }
        .navigationTitle(editedRole.name)
        .navigationBarTitleDisplayMode(.inline)
        // 変更中は標準の「戻る」ボタンを非表示にしてカスタムに差し替え
        .navigationBarBackButtonHidden(hasChanges && !role.managed)
        .toolbar {
            if hasChanges && !role.managed {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showDiscardAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .fontWeight(.semibold)
                            Text("戻る")
                        }
                        .foregroundStyle(Color.accentIndigo)
                    }
                }
            }
        }
        .sheet(isPresented: $showColorPicker) {
            RoleColorPickerView(currentColor: editedRole.color) { newColor in
                editedRole.color = newColor
            }
        }
        .alert("ロールを削除", isPresented: $showDeleteAlert) {
            Button("削除", role: .destructive) {
                onDeleted()
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("「\(editedRole.name)」を削除します。この操作は取り消せません。")
        }
        .alert("変更を破棄しますか？", isPresented: $showDiscardAlert) {
            Button("破棄して戻る", role: .destructive) { dismiss() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("保存されていない変更があります。破棄して戻りますか？")
        }
    }

    // MARK: - Header

    private var roleHeader: some View {
        VStack(spacing: .spacing16) {
            HStack(spacing: .spacing16) {
                // Color chip
                Button {
                    if !role.managed { showColorPicker = true }
                } label: {
                    ZStack {
                        Circle()
                            .fill(editedRole.swiftUIColor)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle()
                                    .stroke(Color.border, lineWidth: editedRole.color == 0 ? 1.5 : 0)
                            )
                        if !role.managed {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.9))
                                .offset(x: 16, y: 16)
                        }
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: .spacing4) {
                    // Name field
                    if role.managed {
                        Text(editedRole.name)
                            .font(.titleMedium)
                            .foregroundStyle(Color.textPrimary)
                        Text("連携管理ロール（編集不可）")
                            .font(.captionRegular)
                            .foregroundStyle(Color.textTertiary)
                    } else {
                        TextField("ロール名", text: $editedRole.name)
                            .font(.titleMedium)
                            .foregroundStyle(Color.textPrimary)
                        Text("タップして名前を編集")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                Spacer()
            }

            // Stats
            HStack(spacing: 0) {
                roleStatCell(
                    label: "有効な権限",
                    value: "\(enabledPermissionCount)個",
                    icon: "checkmark.shield.fill",
                    color: .accentGreen
                )
                Divider().frame(height: 32)
                roleStatCell(
                    label: "作成元",
                    value: role.managed ? "Bot連携" : "手動作成",
                    icon: role.managed ? "link.circle.fill" : "person.circle.fill",
                    color: role.managed ? .accentOrange : .accentIndigo,
                    tooltip: role.managed ? "外部サービス・Botが管理（編集不可）" : "管理者が手動で作成したロール"
                )
            }
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        }
    }

    private func roleStatCell(label: String, value: String, icon: String, color: Color, tooltip: String? = nil) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.bodySmall)
                .fontWeight(.semibold)
                .foregroundStyle(Color.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.captionSmall)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
            if let tooltip {
                Text(tooltip)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.textTertiary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .spacing12)
    }

    private var enabledPermissionCount: Int {
        let bits = editedRole.permissionBits
        if bits & (1 << 3) != 0 { return RolePermission.all.count } // admin
        return RolePermission.all.filter { bits & $0.bit != 0 }.count
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(RolePermission.Category.allCases, id: \.self) { cat in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { activeCategory = cat }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Text(cat.rawValue)
                                    .font(.bodySmall)
                                    .fontWeight(activeCategory == cat ? .semibold : .regular)
                                    .foregroundStyle(activeCategory == cat ? Color.accentIndigo : Color.textSecondary)
                                let count = enabledCount(for: cat)
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.captionSmall)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.accentIndigo)
                                        .clipShape(Capsule())
                                }
                            }
                            Rectangle()
                                .fill(activeCategory == cat ? Color.accentIndigo : Color.clear)
                                .frame(height: 2)
                                .clipShape(Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, .spacing16)
                }
            }
        }
        .background(Color.bgPrimary)
        .overlay(alignment: .bottom) { Divider() }
        .padding(.top, .spacing8)
    }

    private func enabledCount(for category: RolePermission.Category) -> Int {
        let bits = editedRole.permissionBits
        if bits & (1 << 3) != 0 { return RolePermission.items(for: category).count } // admin
        return RolePermission.items(for: category).filter { bits & $0.bit != 0 }.count
    }

    // MARK: - Permissions

    private var categoryPermissions: some View {
        VStack(spacing: .spacing8) {
            let permissions = RolePermission.items(for: activeCategory)
            let isAdmin = editedRole.permissionBits & (1 << 3) != 0

            if activeCategory == .general, let adminPerm = permissions.first(where: { $0.id == "administrator" }) {
                AdminPermissionRow(
                    permission: adminPerm,
                    isOn: isAdmin,
                    isDisabled: role.managed
                ) { newVal in
                    editedRole.permissions = editedRole.toggling(adminPerm, on: newVal)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }

            ForEach(permissions.filter { $0.id != "administrator" }) { perm in
                PermissionRow(
                    permission: perm,
                    isOn: isAdmin || (editedRole.permissionBits & perm.bit != 0),
                    isDisabledByAdmin: isAdmin,
                    isDisabled: role.managed
                ) { newVal in
                    editedRole.permissions = editedRole.toggling(perm, on: newVal)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
    }

    // MARK: - Member Management Row

    private var memberManagementRow: some View {
        let holderCount = MockData.members.filter { $0.roles.contains(role.name) }.count
        return NavigationLink {
            RoleMembersView(role: editedRole, guildId: "g001")
        } label: {
            HStack(spacing: .spacing12) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.accentPurple)
                    .frame(width: 36, height: 36)
                    .background(Color.accentPurple.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("メンバー管理")
                        .font(.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                    Text("ロールの一括付与・削除")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Text("\(holderCount)人")
                    .font(.captionRegular)
                    .foregroundStyle(Color.textTertiary)

                Image(systemName: "chevron.right")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.spacing12)
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                    .stroke(Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            Text("危険な操作")
                .font(.captionSmall)
                .foregroundStyle(Color.textTertiary)

            Button {
                showDeleteAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("ロールを削除")
                }
                .font(.bodySmall)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentRed)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.accentRed.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                        .stroke(Color.accentRed.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Save Bar

    private var saveBar: some View {
        HStack(spacing: .spacing12) {
            Button {
                editedRole = role
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Text("リセット")
                    .font(.bodySmall)
                    .foregroundStyle(Color.textSecondary)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            }
            .buttonStyle(.plain)

            Button {
                save()
            } label: {
                Group {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else if saveSuccess {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                    } else {
                        Text("変更を保存")
                            .font(.bodySmall)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                }
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(Color.accentIndigo)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
        }
        .padding(.horizontal, .spacing16)
        .padding(.vertical, .spacing12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private func save() {
        isSaving = true
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run {
                isSaving = false
                saveSuccess = true
                onSaved(editedRole)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            try? await Task.sleep(for: .milliseconds(1200))
            await MainActor.run { saveSuccess = false }
        }
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let permission: RolePermission
    let isOn: Bool
    var isDisabledByAdmin: Bool = false
    var isDisabled: Bool = false
    let onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: .spacing12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.displayName)
                    .font(.bodySmall)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.textPrimary)
                Text(permission.description)
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(2)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { if !isDisabled && !isDisabledByAdmin { onChange($0) } }
            ))
            .tint(Color.accentIndigo)
            .labelsHidden()
            .disabled(isDisabled || isDisabledByAdmin)
        }
        .padding(.spacing12)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
        .opacity(isDisabledByAdmin ? 0.5 : 1)
    }
}

// MARK: - Admin Permission Row (special styling)

private struct AdminPermissionRow: View {
    let permission: RolePermission
    let isOn: Bool
    var isDisabled: Bool = false
    let onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: .spacing12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: .spacing6) {
                    Text(permission.displayName)
                        .font(.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.captionSmall)
                        .foregroundStyle(Color.accentRed)
                }
                Text("ONにするとすべての権限チェックが無効になります")
                    .font(.captionSmall)
                    .foregroundStyle(Color.accentRed.opacity(0.8))
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { if !isDisabled { onChange($0) } }
            ))
            .tint(Color.accentRed)
            .labelsHidden()
            .disabled(isDisabled)
        }
        .padding(.spacing12)
        .background(
            isOn
                ? Color.accentRed.opacity(0.08)
                : Color.bgSurface
        )
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                .stroke(
                    isOn ? Color.accentRed.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }
}

// MARK: - Color Picker Sheet

struct RoleColorPickerView: View {
    let currentColor: Int
    let onSelected: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: .init(.flexible()), count: 5),
                        spacing: .spacing16
                    ) {
                        ForEach(Color.discordRoleColors, id: \.value) { item in
                            Button {
                                onSelected(item.value)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                dismiss()
                            } label: {
                                VStack(spacing: .spacing8) {
                                    ZStack {
                                        if item.value == 0 {
                                            Circle()
                                                .stroke(Color.border, lineWidth: 1.5)
                                                .frame(width: 48, height: 48)
                                            Image(systemName: "xmark")
                                                .foregroundStyle(Color.textTertiary)
                                        } else {
                                            Circle()
                                                .fill(Color(uiColor: UIColor(hex: UInt32(item.value))))
                                                .frame(width: 48, height: 48)
                                        }
                                        if currentColor == item.value {
                                            Circle()
                                                .stroke(Color.white, lineWidth: 3)
                                                .frame(width: 48, height: 48)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    Text(item.name)
                                        .font(.captionSmall)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.spacing20)
                }
            }
            .navigationTitle("ロールカラー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        RoleDetailView(
            role: DiscordRole.mockRoles[1],
            onSaved: { _ in },
            onDeleted: {}
        )
    }
}
