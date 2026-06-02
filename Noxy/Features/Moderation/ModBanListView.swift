import SwiftUI

struct ModBanListView: View {
    @State private var bans: [BannedUser] = BannedUser.mock
    @State private var searchText = ""
    @State private var unbanTarget: BannedUser? = nil
    @State private var isUnbanning = false
    @State private var showSuccess: String? = nil

    private var filtered: [BannedUser] {
        guard !searchText.isEmpty else { return bans }
        return bans.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            if bans.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: .spacing8) {
                        countHeader
                        ForEach(filtered) { ban in
                            BanRow(ban: ban) {
                                unbanTarget = ban
                            }
                        }
                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, .spacing16)
                    .padding(.top, .spacing12)
                }
            }

            if let msg = showSuccess {
                VStack {
                    Spacer()
                    HStack(spacing: .spacing8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                        Text(msg).font(.bodySmall).fontWeight(.semibold).foregroundStyle(.white)
                    }
                    .padding(.horizontal, .spacing16)
                    .frame(height: 48)
                    .background(Color.accentGreen)
                    .clipShape(Capsule())
                    .shadow(radius: 8)
                    .padding(.bottom, .spacing32)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .searchable(text: $searchText, prompt: "ユーザー名で検索")
        .alert("アンBANしますか？", isPresented: Binding(
            get: { unbanTarget != nil },
            set: { if !$0 { unbanTarget = nil } }
        )) {
            Button("アンBAN", role: .destructive) {
                if let target = unbanTarget { performUnban(target) }
            }
            Button("キャンセル", role: .cancel) { unbanTarget = nil }
        } message: {
            Text("「\(unbanTarget?.displayName ?? "")」のBANを解除します。再参加が可能になります。")
        }
    }

    // MARK: - Sub Views

    private var countHeader: some View {
        HStack {
            Text("\(bans.count)人がBAN中")
                .font(.captionSmall).foregroundStyle(Color.textTertiary)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: .spacing16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48)).foregroundStyle(Color.accentGreen.opacity(0.6))
            Text("BANされたユーザーはいません")
                .font(.titleMedium).foregroundStyle(Color.textPrimary)
            Text("安全なサーバーが保たれています")
                .font(.bodySmall).foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Action

    private func performUnban(_ ban: BannedUser) {
        // 実際のAPI: DELETE /bot/bans/{userId}?guild_id=...
        withAnimation { bans.removeAll { $0.id == ban.id } }
        showSuccessToast("\(ban.displayName) のBANを解除しました")
        unbanTarget = nil
    }

    private func showSuccessToast(_ msg: String) {
        withAnimation(.spring()) { showSuccess = msg }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run {
                withAnimation { showSuccess = nil }
            }
        }
    }
}

// MARK: - BanRow

private struct BanRow: View {
    let ban: BannedUser
    let onUnban: () -> Void

    var body: some View {
        HStack(spacing: .spacing12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(uiColor: UIColor(hex: 0xEF4444)).opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(ban.displayName.prefix(1).uppercased())
                    .font(.titleMedium)
                    .foregroundStyle(Color(uiColor: UIColor(hex: 0xEF4444)))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(ban.displayName)
                    .font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                Text("@\(ban.username)")
                    .font(.captionSmall).foregroundStyle(Color.textTertiary)
                if let reason = ban.reason {
                    HStack(spacing: 4) {
                        Image(systemName: "text.bubble").font(.system(size: 10))
                        Text(reason).lineLimit(1)
                    }
                    .font(.captionSmall).foregroundStyle(Color.textSecondary)
                }
                if let date = ban.bannedAt {
                    Text(date.formatted(.relative(presentation: .named)))
                        .font(.captionSmall).foregroundStyle(Color.textTertiary)
                }
            }

            Spacer()

            Button("アンBAN", action: onUnban)
                .font(.captionRegular).fontWeight(.semibold)
                .foregroundStyle(Color.accentGreen)
                .padding(.horizontal, .spacing10).padding(.vertical, 5)
                .background(Color.accentGreen.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.spacing12)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .overlay(RoundedRectangle(cornerRadius: .cornerRadiusMedium).stroke(Color.border, lineWidth: 1))
    }
}
