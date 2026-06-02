import SwiftUI

// MARK: - Root Editor

struct ServerSetupEditorView: View {
    @State var vm: ServerSetupViewModel
    @State private var showPreview = false
    @State private var showApply = false
    @State private var serverNameFocused = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Section picker
                sectionPicker
                    .padding(.horizontal, .spacing16)
                    .padding(.vertical, .spacing8)

                // Content
                Group {
                    switch vm.activeSection {
                    case .channels:    ChannelsSectionView(vm: vm)
                    case .roles:       RolesSectionView(vm: vm)
                    case .onboarding:  OnboardingSectionView(vm: vm)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom bar spacer
                Color.clear.frame(height: 72)
            }

            // Sticky bottom bar
            editorBottomBar
        }
        .navigationTitle(vm.draft.serverName.isEmpty ? "新しいセットアップ" : vm.draft.serverName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showPreview = true
                } label: {
                    Image(systemName: "eye")
                        .foregroundStyle(Color.accentIndigo)
                }
            }
        }
        .sheet(isPresented: $showPreview) {
            DiscordLivePreviewView(draft: vm.draft)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showApply) {
            ServerSetupApplyView(vm: vm)
        }
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(ServerSetupViewModel.EditorSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        vm.activeSection = section
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 4) {
                        Text(section.rawValue)
                            .font(.bodySmall)
                            .fontWeight(vm.activeSection == section ? .semibold : .regular)
                            .foregroundStyle(vm.activeSection == section ? Color.accentIndigo : Color.textSecondary)
                        Rectangle()
                            .fill(vm.activeSection == section ? Color.accentIndigo : Color.clear)
                            .frame(height: 2)
                            .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Bottom Bar

    private var editorBottomBar: some View {
        HStack(spacing: .spacing12) {
            // Undo
            Button {
                vm.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(vm.canUndo ? Color.textPrimary : Color.textTertiary)
                    .frame(width: 44, height: 44)
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
            }
            .disabled(!vm.canUndo)
            .buttonStyle(.plain)

            // Redo
            Button {
                vm.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(vm.canRedo ? Color.textPrimary : Color.textTertiary)
                    .frame(width: 44, height: 44)
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
            }
            .disabled(!vm.canRedo)
            .buttonStyle(.plain)

            Spacer()

            // Stats
            HStack(spacing: .spacing8) {
                EditorStat(value: vm.totalCategories, label: "カテゴリ")
                EditorStat(value: vm.totalChannels, label: "ch")
                EditorStat(value: vm.totalRoles, label: "ロール")
            }

            Spacer()

            // Apply
            Button {
                showApply = true
            } label: {
                Text("適用")
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, .spacing20)
                    .frame(height: 44)
                    .background(Color.accentIndigo)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, .spacing16)
        .padding(.vertical, .spacing12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}

private struct EditorStat: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.captionRegular)
                .fontWeight(.semibold)
                .foregroundStyle(Color.textPrimary)
            Text(label)
                .font(.captionSmall)
                .foregroundStyle(Color.textTertiary)
        }
    }
}

// MARK: - Channels Section

struct ChannelsSectionView: View {
    let vm: ServerSetupViewModel
    @State private var addingCategoryName = false
    @State private var newCategoryName = ""
    @FocusState private var categoryNameFocused: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                // Server name field at top
                serverNameField
                    .padding(.horizontal, .spacing16)
                    .padding(.top, .spacing12)
                    .padding(.bottom, .spacing8)

                // Categories
                ForEach(vm.draft.categories) { cat in
                    CategorySectionView(vm: vm, category: cat)
                        .padding(.bottom, 2)
                }

                // Add category row
                addCategorySection
                    .padding(.horizontal, .spacing16)
                    .padding(.top, .spacing8)

                // Suggestion chips for new channels
                if !vm.draft.categories.isEmpty {
                    channelSuggestionChips
                        .padding(.horizontal, .spacing16)
                        .padding(.top, .spacing12)
                }

                Spacer(minLength: 100)
            }
        }
    }

    private var serverNameField: some View {
        VStack(alignment: .leading, spacing: .spacing6) {
            Text("サーバー名")
                .font(.captionSmall)
                .foregroundStyle(Color.textTertiary)
            TextField("例: ゲーミングサーバー", text: Binding(
                get: { vm.draft.serverName },
                set: { vm.draft.serverName = $0 }
            ))
            .font(.titleMedium)
            .foregroundStyle(Color.textPrimary)
            .padding(.spacing12)
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                    .stroke(Color.border, lineWidth: 1)
            )
        }
    }

    private var addCategorySection: some View {
        Group {
            if addingCategoryName {
                HStack(spacing: .spacing8) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Color.accentIndigo)
                        .font(.system(size: 14))
                    TextField("カテゴリ名", text: $newCategoryName)
                        .font(.bodySmall)
                        .focused($categoryNameFocused)
                        .onSubmit { commitNewCategory() }
                    Button("追加") {
                        commitNewCategory()
                    }
                    .font(.bodySmall)
                    .foregroundStyle(Color.accentIndigo)
                    Button {
                        addingCategoryName = false
                        newCategoryName = ""
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                .padding(.spacing12)
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                        .stroke(Color.accentIndigo.opacity(0.4), lineWidth: 1)
                )
                .onAppear { categoryNameFocused = true }
            } else {
                GhostAddButton(label: "カテゴリを追加") {
                    addingCategoryName = true
                    newCategoryName = ""
                }
            }
        }
    }

    private func commitNewCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        vm.addCategory(name: name.isEmpty ? "新しいカテゴリ" : name)
        addingCategoryName = false
        newCategoryName = ""
    }

    private var channelSuggestionChips: some View {
        let lastCat = vm.draft.categories.last
        let suggestions = lastCat?.channelSuggestions ?? []
        return Group {
            if !suggestions.isEmpty, let cat = lastCat {
                VStack(alignment: .leading, spacing: .spacing8) {
                    Text("よく使われるチャンネル")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: .spacing8) {
                            ForEach(suggestions, id: \.self) { name in
                                SuggestionChip(label: name) {
                                    vm.addChannel(to: cat.id, name: name)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Category Section

private struct CategorySectionView: View {
    let vm: ServerSetupViewModel
    let category: SetupCategory

    @State private var isEditingName = false
    @State private var editName = ""
    @State private var addingChannel = false
    @State private var newChannelName = ""
    @State private var newChannelType: SetupChannelType = .text
    @FocusState private var catNameFocused: Bool
    @FocusState private var newChannelFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Category header
            categoryHeader
                .padding(.horizontal, .spacing16)
                .padding(.vertical, .spacing8)
                .background(Color.bgPrimary)

            if category.isExpanded {
                // Channels
                ForEach(category.channels) { ch in
                    EditorChannelRow(vm: vm, categoryId: category.id, channel: ch)
                        .padding(.horizontal, .spacing16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Ghost add channel
                addChannelRow
                    .padding(.horizontal, .spacing16)
                    .padding(.bottom, .spacing4)
            }
        }
        .background(category.isExpanded ? Color.bgSurface.opacity(0.4) : Color.clear)
    }

    private var categoryHeader: some View {
        HStack(spacing: .spacing8) {
            // Collapse toggle
            Button {
                withAnimation(.spring(duration: 0.25)) {
                    vm.toggleCategory(id: category.id)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.textTertiary)
                    .rotationEffect(.degrees(category.isExpanded ? 90 : 0))
                    .animation(.spring(duration: 0.25), value: category.isExpanded)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)

            // Category name
            if isEditingName {
                TextField("カテゴリ名", text: $editName)
                    .font(.captionSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
                    .focused($catNameFocused)
                    .onSubmit { commitCategoryRename() }
                    .onAppear { catNameFocused = true }
            } else {
                Text(category.name)
                    .font(.captionSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textSecondary)
                    .onTapGesture(count: 2) {
                        editName = category.name
                        isEditingName = true
                    }
            }

            Spacer()

            // Channel count badge
            if !category.isExpanded && !category.channels.isEmpty {
                Text("\(category.channels.count)")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.bgElevated)
                    .clipShape(Capsule())
            }

            // Delete category
            Button {
                vm.deleteCategory(id: category.id)
            } label: {
                Image(systemName: "trash")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    private func commitCategoryRename() {
        vm.renameCategory(id: category.id, name: editName)
        isEditingName = false
    }

    private var addChannelRow: some View {
        Group {
            if addingChannel {
                HStack(spacing: .spacing8) {
                    // Type picker chips
                    HStack(spacing: 4) {
                        ForEach(SetupChannelType.allCases, id: \.self) { t in
                            Button {
                                newChannelType = t
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Image(systemName: t.icon)
                                    .font(.system(size: 12))
                                    .foregroundStyle(newChannelType == t ? Color.accentIndigo : Color.textTertiary)
                                    .frame(width: 28, height: 28)
                                    .background(newChannelType == t ? Color.accentIndigo.opacity(0.12) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    TextField("チャンネル名", text: $newChannelName)
                        .font(.bodySmall)
                        .focused($newChannelFocused)
                        .onSubmit { commitNewChannel() }

                    Button("追加") { commitNewChannel() }
                        .font(.bodySmall)
                        .foregroundStyle(Color.accentIndigo)

                    Button {
                        addingChannel = false
                        newChannelName = ""
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.textTertiary)
                            .font(.captionSmall)
                    }
                }
                .padding(.vertical, .spacing8)
                .padding(.horizontal, .spacing12)
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                        .stroke(Color.accentIndigo.opacity(0.4), lineWidth: 1)
                )
                .onAppear { newChannelFocused = true }
            } else {
                GhostAddButton(label: "チャンネルを追加") {
                    addingChannel = true
                    newChannelName = ""
                    newChannelType = .text
                }
            }
        }
    }

    private func commitNewChannel() {
        let name = newChannelName.trimmingCharacters(in: .whitespaces)
        vm.addChannel(to: category.id, name: name.isEmpty ? "新しいチャンネル" : name, type: newChannelType)
        newChannelName = ""
        newChannelType = .text
        addingChannel = false
    }
}

// MARK: - Editor Channel Row

private struct EditorChannelRow: View {
    let vm: ServerSetupViewModel
    let categoryId: UUID
    let channel: SetupChannel

    @State private var editingName: String
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    init(vm: ServerSetupViewModel, categoryId: UUID, channel: SetupChannel) {
        self.vm = vm
        self.categoryId = categoryId
        self.channel = channel
        self._editingName = State(initialValue: channel.name)
    }

    var body: some View {
        HStack(spacing: .spacing8) {
            // Type icon — tap to cycle
            Button {
                vm.cycleChannelType(categoryId: categoryId, channelId: channel.id)
            } label: {
                Image(systemName: channel.type.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 28, height: 28)
                    .background(Color.bgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Name
            if isEditing {
                TextField("チャンネル名", text: $editingName)
                    .font(.bodySmall)
                    .foregroundStyle(Color.textPrimary)
                    .focused($isFocused)
                    .onSubmit { commitRename() }
                    .onChange(of: isFocused) { _, focused in
                        if !focused { commitRename() }
                    }
            } else {
                Text(channel.name)
                    .font(.bodySmall)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingName = channel.name
                        isEditing = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isFocused = true
                        }
                    }
            }

            Spacer()

            // Private lock toggle
            Button {
                vm.toggleChannelPrivacy(categoryId: categoryId, channelId: channel.id)
            } label: {
                Image(systemName: channel.isPrivate ? "lock.fill" : "lock.open")
                    .font(.system(size: 12))
                    .foregroundStyle(channel.isPrivate ? Color.accentOrange : Color.textTertiary)
            }
            .buttonStyle(.plain)

            // Delete
            Button {
                vm.deleteChannel(categoryId: categoryId, channelId: channel.id)
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(uiColor: UIColor(hex: 0xEF4444)).opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, .spacing8)
        .padding(.horizontal, .spacing12)
        .background(Color.bgSurface)
        .onAppear {
            // Auto-focus newly added channels
            if channel.name == "新しいチャンネル" {
                editingName = channel.name
                isEditing = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
        }
    }

    private func commitRename() {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        vm.renameChannel(categoryId: categoryId, channelId: channel.id, name: trimmed.isEmpty ? channel.name : trimmed)
        isEditing = false
    }
}

// MARK: - Roles Section

struct RolesSectionView: View {
    let vm: ServerSetupViewModel
    @State private var expandedRoleId: UUID? = nil
    @State private var addingRole = false
    @State private var newRoleName = ""
    @FocusState private var newRoleFocused: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: .spacing8) {
                ForEach(vm.draft.roles) { role in
                    RoleCard(vm: vm, role: role, isExpanded: expandedRoleId == role.id) {
                        withAnimation(.spring(duration: 0.3)) {
                            expandedRoleId = expandedRoleId == role.id ? nil : role.id
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }

                // Ghost add
                if addingRole {
                    addRoleField
                } else {
                    GhostAddButton(label: "ロールを追加") {
                        addingRole = true
                        newRoleName = ""
                    }
                }

                // Role suggestions
                if !vm.roleSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: .spacing8) {
                        Text("よく使われるロール")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: .spacing8) {
                                ForEach(vm.roleSuggestions, id: \.self) { name in
                                    SuggestionChip(label: name) {
                                        vm.addRole(name: name)
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, .spacing16)
            .padding(.top, .spacing12)
        }
    }

    private var addRoleField: some View {
        HStack(spacing: .spacing8) {
            Image(systemName: "shield.fill")
                .foregroundStyle(Color.accentPurple)
                .font(.system(size: 14))
            TextField("ロール名", text: $newRoleName)
                .font(.bodySmall)
                .focused($newRoleFocused)
                .onSubmit { commitNewRole() }
            Button("追加") { commitNewRole() }
                .font(.bodySmall)
                .foregroundStyle(Color.accentIndigo)
            Button {
                addingRole = false
                newRoleName = ""
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(Color.textTertiary)
                    .font(.captionSmall)
            }
        }
        .padding(.spacing12)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                .stroke(Color.accentIndigo.opacity(0.4), lineWidth: 1)
        )
        .onAppear { newRoleFocused = true }
    }

    private func commitNewRole() {
        let name = newRoleName.trimmingCharacters(in: .whitespaces)
        vm.addRole(name: name.isEmpty ? "新しいロール" : name)
        addingRole = false
        newRoleName = ""
    }
}

// MARK: - Role Card

private struct RoleCard: View {
    let vm: ServerSetupViewModel
    let role: SetupRole
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: onTap) {
                HStack(spacing: .spacing12) {
                    Circle()
                        .fill(role.swiftUIColor)
                        .frame(width: 12, height: 12)

                    Text(role.name)
                        .font(.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)

                    if role.isAutoAssigned {
                        Text("自動付与")
                            .font(.captionSmall)
                            .foregroundStyle(Color.accentGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentGreen.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(.spring(duration: 0.25), value: isExpanded)

                    Button {
                        vm.deleteRole(id: role.id)
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    } label: {
                        Image(systemName: "trash")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.spacing12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .padding(.horizontal, .spacing12)

                RolePermissionsView(vm: vm, roleId: role.id, permissions: role.permissions, isAutoAssigned: role.isAutoAssigned)
                    .padding(.spacing12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(Color.border, lineWidth: 1)
        )
        .animation(.spring(duration: 0.3), value: isExpanded)
    }
}

// MARK: - Role Permissions

private struct RolePermissionsView: View {
    let vm: ServerSetupViewModel
    let roleId: UUID
    var permissions: RolePermissions
    var isAutoAssigned: Bool

    private var roleIdx: Int? {
        vm.draft.roles.firstIndex(where: { $0.id == roleId })
    }

    var body: some View {
        VStack(spacing: .spacing12) {
            // Auto-assign toggle
            permToggle(
                label: "入室時に自動付与",
                icon: "person.badge.plus",
                value: Binding(
                    get: { vm.draft.roles.first(where: { $0.id == roleId })?.isAutoAssigned ?? false },
                    set: { newVal in
                        guard let i = roleIdx else { return }
                        vm.draft.roles[i].isAutoAssigned = newVal
                        vm.checkpoint()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                )
            )

            Divider()

            Text("権限")
                .font(.captionSmall)
                .foregroundStyle(Color.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(permissionItems, id: \.0) { item in
                permToggle(
                    label: item.0,
                    icon: item.1,
                    value: item.2
                )
            }
        }
    }

    private var permissionItems: [(String, String, Binding<Bool>)] {
        guard let i = roleIdx else { return [] }
        return [
            ("メッセージ送信", "text.bubble", Binding(
                get: { vm.draft.roles[i].permissions.sendMessages },
                set: { vm.draft.roles[i].permissions.sendMessages = $0; vm.checkpoint() }
            )),
            ("メッセージ管理", "pencil.and.outline", Binding(
                get: { vm.draft.roles[i].permissions.manageMessages },
                set: { vm.draft.roles[i].permissions.manageMessages = $0; vm.checkpoint() }
            )),
            ("チャンネル管理", "folder.badge.gear", Binding(
                get: { vm.draft.roles[i].permissions.manageChannels },
                set: { vm.draft.roles[i].permissions.manageChannels = $0; vm.checkpoint() }
            )),
            ("ロール管理", "shield.lefthalf.filled", Binding(
                get: { vm.draft.roles[i].permissions.manageRoles },
                set: { vm.draft.roles[i].permissions.manageRoles = $0; vm.checkpoint() }
            )),
            ("メンバーをキック", "person.badge.minus", Binding(
                get: { vm.draft.roles[i].permissions.kickMembers },
                set: { vm.draft.roles[i].permissions.kickMembers = $0; vm.checkpoint() }
            )),
            ("メンバーをBAN", "hand.raised.slash", Binding(
                get: { vm.draft.roles[i].permissions.banMembers },
                set: { vm.draft.roles[i].permissions.banMembers = $0; vm.checkpoint() }
            )),
            ("@everyoneメンション", "at", Binding(
                get: { vm.draft.roles[i].permissions.mentionEveryone },
                set: { vm.draft.roles[i].permissions.mentionEveryone = $0; vm.checkpoint() }
            )),
            ("監査ログ閲覧", "doc.text.magnifyingglass", Binding(
                get: { vm.draft.roles[i].permissions.viewAuditLog },
                set: { vm.draft.roles[i].permissions.viewAuditLog = $0; vm.checkpoint() }
            )),
        ]
    }

    private func permToggle(label: String, icon: String, value: Binding<Bool>) -> some View {
        HStack(spacing: .spacing12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .frame(width: 20)
            Text(label)
                .font(.bodySmall)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Toggle("", isOn: value)
                .tint(Color.accentIndigo)
                .labelsHidden()
        }
    }
}

// MARK: - Onboarding Section

struct OnboardingSectionView: View {
    let vm: ServerSetupViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: .spacing12) {
                infoCard

                toggleCard(
                    icon: "📋",
                    title: "ルールチャンネル",
                    subtitle: "サーバー参加時に同意が必要なルール",
                    isOn: Binding(
                        get: { vm.draft.onboarding.rulesEnabled },
                        set: { vm.draft.onboarding.rulesEnabled = $0; vm.checkpoint() }
                    ),
                    channelName: vm.draft.onboarding.rulesEnabled
                        ? Binding(
                            get: { vm.draft.onboarding.rulesChannelName },
                            set: { vm.draft.onboarding.rulesChannelName = $0 }
                        )
                        : nil
                )

                toggleCard(
                    icon: "👋",
                    title: "ウェルカムメッセージ",
                    subtitle: "新規メンバーへの自動挨拶メッセージ",
                    isOn: Binding(
                        get: { vm.draft.onboarding.welcomeEnabled },
                        set: { vm.draft.onboarding.welcomeEnabled = $0; vm.checkpoint() }
                    ),
                    channelName: vm.draft.onboarding.welcomeEnabled
                        ? Binding(
                            get: { vm.draft.onboarding.welcomeChannelName },
                            set: { vm.draft.onboarding.welcomeChannelName = $0 }
                        )
                        : nil
                )

                toggleCard(
                    icon: "✅",
                    title: "認証ゲート",
                    subtitle: "ボタンを押してサーバーにアクセスする設定",
                    isOn: Binding(
                        get: { vm.draft.onboarding.verifyEnabled },
                        set: { vm.draft.onboarding.verifyEnabled = $0; vm.checkpoint() }
                    )
                )

                autoRoleCard

                Spacer(minLength: 100)
            }
            .padding(.horizontal, .spacing16)
            .padding(.top, .spacing12)
        }
    }

    private var infoCard: some View {
        HStack(spacing: .spacing12) {
            Image(systemName: "info.circle")
                .foregroundStyle(Color.accentIndigo)
            Text("オンボーディング設定は、指定のチャンネルとロールをサーバーに作成する際に自動的に追加されます。")
                .font(.captionRegular)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.spacing12)
        .background(Color.accentIndigo.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
    }

    private func toggleCard(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        channelName: Binding<String>? = nil
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: .spacing12) {
                Text(icon)
                    .font(.titleMedium)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                    Text(subtitle)
                        .font(.captionRegular)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Toggle("", isOn: isOn)
                    .tint(Color.accentIndigo)
                    .labelsHidden()
                    .onChange(of: isOn.wrappedValue) { vm.checkpoint() }
            }
            .padding(.spacing12)

            if let channelName, isOn.wrappedValue {
                Divider().padding(.horizontal, .spacing12)
                HStack {
                    Image(systemName: "number")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                    TextField("チャンネル名", text: channelName)
                        .font(.bodySmall)
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(.horizontal, .spacing12)
                .padding(.vertical, .spacing10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(Color.border, lineWidth: 1)
        )
        .animation(.spring(duration: 0.25), value: isOn.wrappedValue)
    }

    private var autoRoleCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: .spacing12) {
                Text("🤖")
                    .font(.titleMedium)
                VStack(alignment: .leading, spacing: 2) {
                    Text("入室時の自動ロール付与")
                        .font(.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                    Text("参加したメンバーに自動でロールを付与")
                        .font(.captionRegular)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { vm.draft.onboarding.autoRoleEnabled },
                    set: { vm.draft.onboarding.autoRoleEnabled = $0; vm.checkpoint() }
                ))
                .tint(Color.accentIndigo)
                .labelsHidden()
            }
            .padding(.spacing12)

            if vm.draft.onboarding.autoRoleEnabled {
                Divider().padding(.horizontal, .spacing12)
                HStack {
                    Image(systemName: "shield.fill")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                    TextField("ロール名", text: Binding(
                        get: { vm.draft.onboarding.autoRoleName },
                        set: { vm.draft.onboarding.autoRoleName = $0 }
                    ))
                    .font(.bodySmall)
                    .foregroundStyle(Color.textPrimary)
                }
                .padding(.horizontal, .spacing12)
                .padding(.vertical, .spacing10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(Color.border, lineWidth: 1)
        )
        .animation(.spring(duration: 0.25), value: vm.draft.onboarding.autoRoleEnabled)
    }
}

// MARK: - Shared Components

struct GhostAddButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: .spacing8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                Text(label)
                    .font(.bodySmall)
            }
            .foregroundStyle(Color.accentIndigo.opacity(0.6))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, .spacing10)
            .padding(.horizontal, .spacing12)
            .background(
                RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                    .strokeBorder(
                        Color.accentIndigo.opacity(0.25),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 3])
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct SuggestionChip: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.captionRegular)
            }
            .foregroundStyle(Color.accentIndigo)
            .padding(.horizontal, .spacing10)
            .padding(.vertical, .spacing6)
            .background(Color.accentIndigo.opacity(0.1))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.accentIndigo.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ServerSetupEditorView(vm: ServerSetupViewModel(draft: ServerTemplate.gaming.draft))
    }
    .preferredColorScheme(.dark)
}
