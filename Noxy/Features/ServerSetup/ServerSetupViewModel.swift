import SwiftUI

@Observable
final class ServerSetupViewModel {

    var draft: ServerSetupDraft
    var showLivePreview = false
    var activeSection: EditorSection = .channels
    var newlyAddedChannelId: UUID? = nil

    private var history: [ServerSetupDraft] = []
    private var historyIdx: Int = -1

    enum EditorSection: String, CaseIterable {
        case channels    = "チャンネル"
        case roles       = "ロール"
        case onboarding  = "オンボーディング"
    }

    var canUndo: Bool { historyIdx > 0 }
    var canRedo: Bool { historyIdx < history.count - 1 }

    var totalChannels: Int { draft.categories.flatMap(\.channels).count }
    var totalCategories: Int { draft.categories.count }
    var totalRoles: Int { draft.roles.count }

    init(draft: ServerSetupDraft = ServerSetupDraft()) {
        self.draft = draft
        pushHistory()
    }

    // MARK: - Undo / Redo

    private func pushHistory() {
        if historyIdx < history.count - 1 {
            history = Array(history.prefix(historyIdx + 1))
        }
        history.append(draft)
        historyIdx = history.count - 1
    }

    func checkpoint() { pushHistory() }

    func undo() {
        guard canUndo else { return }
        historyIdx -= 1
        draft = history[historyIdx]
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func redo() {
        guard canRedo else { return }
        historyIdx += 1
        draft = history[historyIdx]
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Category

    func addCategory(name: String = "新しいカテゴリ") {
        draft.categories.append(SetupCategory(name: name))
        pushHistory()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func deleteCategory(id: UUID) {
        draft.categories.removeAll { $0.id == id }
        pushHistory()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    func toggleCategory(id: UUID) {
        guard let i = draft.categories.firstIndex(where: { $0.id == id }) else { return }
        draft.categories[i].isExpanded.toggle()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func renameCategory(id: UUID, name: String) {
        guard let i = draft.categories.firstIndex(where: { $0.id == id }),
              !name.isEmpty else { return }
        draft.categories[i].name = name
        pushHistory()
    }

    func moveCategory(from source: IndexSet, to dest: Int) {
        draft.categories.move(fromOffsets: source, toOffset: dest)
        pushHistory()
    }

    // MARK: - Channel

    @discardableResult
    func addChannel(to categoryId: UUID, name: String = "新しいチャンネル", type: SetupChannelType = .text) -> UUID {
        guard let ci = draft.categories.firstIndex(where: { $0.id == categoryId }) else { return UUID() }
        let ch = SetupChannel(name: name, type: type)
        draft.categories[ci].channels.append(ch)
        draft.categories[ci].isExpanded = true
        newlyAddedChannelId = ch.id
        pushHistory()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return ch.id
    }

    func deleteChannel(categoryId: UUID, channelId: UUID) {
        guard let ci = draft.categories.firstIndex(where: { $0.id == categoryId }) else { return }
        draft.categories[ci].channels.removeAll { $0.id == channelId }
        pushHistory()
    }

    func renameChannel(categoryId: UUID, channelId: UUID, name: String) {
        guard let ci = draft.categories.firstIndex(where: { $0.id == categoryId }),
              let chi = draft.categories[ci].channels.firstIndex(where: { $0.id == channelId }),
              !name.isEmpty else { return }
        draft.categories[ci].channels[chi].name = name
        pushHistory()
    }

    func cycleChannelType(categoryId: UUID, channelId: UUID) {
        guard let ci = draft.categories.firstIndex(where: { $0.id == categoryId }),
              let chi = draft.categories[ci].channels.firstIndex(where: { $0.id == channelId }) else { return }
        draft.categories[ci].channels[chi].type = draft.categories[ci].channels[chi].type.next()
        pushHistory()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func toggleChannelPrivacy(categoryId: UUID, channelId: UUID) {
        guard let ci = draft.categories.firstIndex(where: { $0.id == categoryId }),
              let chi = draft.categories[ci].channels.firstIndex(where: { $0.id == channelId }) else { return }
        draft.categories[ci].channels[chi].isPrivate.toggle()
        pushHistory()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func moveChannels(categoryId: UUID, from source: IndexSet, to dest: Int) {
        guard let ci = draft.categories.firstIndex(where: { $0.id == categoryId }) else { return }
        draft.categories[ci].channels.move(fromOffsets: source, toOffset: dest)
        pushHistory()
    }

    // MARK: - Role

    func addRole(name: String = "新しいロール") {
        draft.roles.append(SetupRole(name: name))
        pushHistory()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func deleteRole(id: UUID) {
        draft.roles.removeAll { $0.id == id }
        pushHistory()
    }

    func renameRole(id: UUID, name: String) {
        guard let i = draft.roles.firstIndex(where: { $0.id == id }),
              !name.isEmpty else { return }
        draft.roles[i].name = name
        pushHistory()
    }

    // MARK: - Smart suggestions

    var roleSuggestions: [String] {
        let existing = Set(draft.roles.map(\.name))
        return ["👑 管理者", "🛡 モデレーター", "⭐ VIP", "💬 メンバー", "🤖 Bot"]
            .filter { !existing.contains($0) }
    }
}
