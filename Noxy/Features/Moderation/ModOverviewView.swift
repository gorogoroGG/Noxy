import SwiftUI

struct ModOverviewView: View {
    private let bans     = BannedUser.mock
    private let timeouts = TimedOutMember.mock
    private let warnings = ModWarning.mock.filter { !$0.isRevoked }
    private let log      = ModerationLogEntry.mock

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing16) {
                statsRow
                autoModCard
                recentLog
                Spacer(minLength: 32)
            }
            .padding(.spacing16)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: .spacing12) {
            ModStatCard(
                icon: "hand.raised.slash.fill",
                color: Color(uiColor: UIColor(hex: 0xEF4444)),
                value: "\(bans.count)",
                label: "BAN中"
            )
            ModStatCard(
                icon: "timer",
                color: .accentPurple,
                value: "\(timeouts.count)",
                label: "タイムアウト中"
            )
            ModStatCard(
                icon: "exclamationmark.triangle.fill",
                color: .accentOrange,
                value: "\(warnings.count)",
                label: "有効な警告"
            )
        }
    }

    // MARK: - AutoMod Card

    private var autoModCard: some View {
        NavigationLink(destination: AutoModRulesView()) {
            HStack(spacing: .spacing12) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.accentIndigo)
                    .frame(width: 48, height: 48)
                    .background(Color.accentIndigo.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text("AutoMod 設定")
                        .font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                    Text("スパム・不適切コンテンツの自動フィルタリング設定")
                        .font(.captionRegular).foregroundStyle(Color.textSecondary).lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.captionSmall).foregroundStyle(Color.textTertiary)
            }
            .padding(.spacing16)
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            .overlay(RoundedRectangle(cornerRadius: .cornerRadiusMedium).stroke(Color.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent Log

    private var recentLog: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            Text("最近のアクション")
                .font(.titleMedium).foregroundStyle(Color.textPrimary)

            ForEach(log) { entry in
                LogRow(entry: entry)
            }
        }
    }
}

// MARK: - LogRow

private struct LogRow: View {
    let entry: ModerationLogEntry

    var body: some View {
        HStack(spacing: .spacing12) {
            Image(systemName: entry.type.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(entry.type.color)
                .frame(width: 36, height: 36)
                .background(entry.type.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: .spacing6) {
                    Text(entry.type.label)
                        .font(.captionSmall).fontWeight(.bold)
                        .foregroundStyle(entry.type.color)
                    Text(entry.targetName)
                        .font(.bodySmall).fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                }
                HStack(spacing: .spacing6) {
                    Text(entry.staffName)
                        .font(.captionSmall).foregroundStyle(Color.textTertiary)
                    if let reason = entry.reason {
                        Text("· \(reason)")
                            .font(.captionSmall).foregroundStyle(Color.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Text(entry.timestamp.formatted(.relative(presentation: .named)))
                .font(.captionSmall).foregroundStyle(Color.textTertiary)
        }
        .padding(.spacing12)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }
}
