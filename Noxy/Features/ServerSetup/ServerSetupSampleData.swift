import SwiftUI

extension ServerTemplate {
    static let all: [ServerTemplate] = [community, gaming, streamer, devTeam, studyGroup]

    static let gaming = ServerTemplate(
        id: "gaming",
        icon: "gamecontroller.fill",
        iconColor: .accentGreen,
        name: "ゲーミング",
        description: "FPS・RPG・雑談チャンネルを完備したゲームコミュニティの定番構成",
        tags: ["FPS", "RPG", "雑談"],
        usageCount: 12_400,
        draft: ServerSetupDraft(
            serverName: "ゲーミングサーバー",
            templateId: "gaming",
            categories: [
                SetupCategory(name: "📢 お知らせ", channels: [
                    SetupChannel(name: "📢│お知らせ", type: .announcement),
                    SetupChannel(name: "📋│ルール"),
                ]),
                SetupCategory(name: "🎮 ゲーム", channels: [
                    SetupChannel(name: "🎮│雑談"),
                    SetupChannel(name: "🎯│fps"),
                    SetupChannel(name: "🗺️│rpg"),
                    SetupChannel(name: "🎤│ゲームVC", type: .voice),
                ]),
                SetupCategory(name: "💬 コミュニティ", channels: [
                    SetupChannel(name: "💬│general"),
                    SetupChannel(name: "🖼️│スクショ投稿"),
                    SetupChannel(name: "🎤│雑談VC", type: .voice),
                ]),
                SetupCategory(name: "🛠️ 運営", channels: [
                    SetupChannel(name: "🔒│スタッフ", isPrivate: true),
                    SetupChannel(name: "🎤│スタッフVC", type: .voice, isPrivate: true),
                ]),
            ],
            roles: [
                SetupRole(name: "👑 オーナー", colorHex: 0xF59E0B,
                          permissions: RolePermissions(sendMessages: true, manageMessages: true, manageChannels: true,
                                                        manageRoles: true, kickMembers: true, banMembers: true,
                                                        mentionEveryone: true, viewAuditLog: true)),
                SetupRole(name: "🛡 モデレーター", colorHex: 0x5865F2,
                          permissions: RolePermissions(sendMessages: true, manageMessages: true,
                                                        kickMembers: true, banMembers: true)),
                SetupRole(name: "🎮 メンバー", colorHex: 0x23A55A,
                          permissions: RolePermissions(sendMessages: true), isAutoAssigned: true),
            ],
            onboarding: OnboardingSetup(rulesEnabled: true, welcomeEnabled: true,
                                         autoRoleEnabled: true, autoRoleName: "🎮 メンバー")
        )
    )

    static let studyGroup = ServerTemplate(
        id: "study",
        icon: "book.fill",
        iconColor: .accentPurple,
        name: "勉強会",
        description: "もくもく会・LT発表・学習コミュニティ向けのスッキリ構成",
        tags: ["学習", "LT", "もくもく"],
        usageCount: 5_800,
        draft: ServerSetupDraft(
            serverName: "勉強会サーバー",
            templateId: "study",
            categories: [
                SetupCategory(name: "📢 インフォ", channels: [
                    SetupChannel(name: "📢│お知らせ", type: .announcement),
                    SetupChannel(name: "📋│ルール"),
                    SetupChannel(name: "👋│自己紹介"),
                ]),
                SetupCategory(name: "📚 学習", channels: [
                    SetupChannel(name: "💬│雑談"),
                    SetupChannel(name: "💡│質問"),
                    SetupChannel(name: "📝│アウトプット"),
                    SetupChannel(name: "🗣️│LT資料シェア", type: .forum),
                ]),
                SetupCategory(name: "🎤 もくもく部屋", channels: [
                    SetupChannel(name: "🎤│作業VC①", type: .voice),
                    SetupChannel(name: "🎤│作業VC②", type: .voice),
                    SetupChannel(name: "🎤│LT練習", type: .voice),
                ]),
            ],
            roles: [
                SetupRole(name: "📚 オーガナイザー", colorHex: 0x7C3AED,
                          permissions: RolePermissions(sendMessages: true, manageMessages: true,
                                                        manageChannels: true, mentionEveryone: true)),
                SetupRole(name: "✏️ 参加者", colorHex: 0x99AAB5,
                          permissions: RolePermissions(sendMessages: true), isAutoAssigned: true),
            ],
            onboarding: OnboardingSetup(rulesEnabled: true, welcomeEnabled: true,
                                         autoRoleEnabled: true, autoRoleName: "✏️ 参加者")
        )
    )

    static let devTeam = ServerTemplate(
        id: "dev",
        icon: "laptopcomputer",
        iconColor: Color(uiColor: UIColor(hex: 0x06B6D4)),
        name: "開発チーム",
        description: "エンジニア・デザイナー・PdMが揃うプロダクト開発チーム向け実用構成",
        tags: ["エンジニア", "デザイン", "PdM"],
        usageCount: 9_200,
        draft: ServerSetupDraft(
            serverName: "開発チームサーバー",
            templateId: "dev",
            categories: [
                SetupCategory(name: "📢 全体", channels: [
                    SetupChannel(name: "📢│アナウンス", type: .announcement),
                    SetupChannel(name: "💬│general"),
                    SetupChannel(name: "🎉│お祝い"),
                ]),
                SetupCategory(name: "🛠️ 開発", channels: [
                    SetupChannel(name: "🐛│バグ報告", type: .forum),
                    SetupChannel(name: "💡│アイデア", type: .forum),
                    SetupChannel(name: "📝│PR・レビュー"),
                    SetupChannel(name: "🤖│CI-CD"),
                ]),
                SetupCategory(name: "🎨 デザイン", channels: [
                    SetupChannel(name: "🎨│デザインレビュー"),
                    SetupChannel(name: "🖼️│アセット共有"),
                ]),
                SetupCategory(name: "📅 MTG", channels: [
                    SetupChannel(name: "🎤│デイリー", type: .voice),
                    SetupChannel(name: "🎤│スプリントレビュー", type: .voice),
                    SetupChannel(name: "🎤│1on1", type: .voice, isPrivate: true),
                ]),
                SetupCategory(name: "🔒 チームのみ", channels: [
                    SetupChannel(name: "🔒│採用", isPrivate: true),
                    SetupChannel(name: "🔒│給与", isPrivate: true),
                ]),
            ],
            roles: [
                SetupRole(name: "🚀 リード", colorHex: 0xF59E0B,
                          permissions: RolePermissions(sendMessages: true, manageMessages: true, manageChannels: true,
                                                        manageRoles: true, kickMembers: true, mentionEveryone: true,
                                                        viewAuditLog: true)),
                SetupRole(name: "⚙️ エンジニア", colorHex: 0x06B6D4,
                          permissions: RolePermissions(sendMessages: true, manageMessages: true)),
                SetupRole(name: "🎨 デザイナー", colorHex: 0xEC4899,
                          permissions: RolePermissions(sendMessages: true, manageMessages: true)),
                SetupRole(name: "📊 PdM", colorHex: 0x7C3AED,
                          permissions: RolePermissions(sendMessages: true, manageMessages: true, mentionEveryone: true)),
            ],
            onboarding: OnboardingSetup(welcomeEnabled: true)
        )
    )

    static let streamer = ServerTemplate(
        id: "streamer",
        icon: "play.rectangle.fill",
        iconColor: .accentPink,
        name: "配信者",
        description: "VTuber・配信者のファンコミュニティ。サポーター限定チャンネル完備",
        tags: ["VTuber", "配信", "ファン"],
        usageCount: 18_600,
        draft: ServerSetupDraft(
            serverName: "ファンサーバー",
            templateId: "streamer",
            categories: [
                SetupCategory(name: "📢 インフォ", channels: [
                    SetupChannel(name: "📢│お知らせ", type: .announcement),
                    SetupChannel(name: "📋│ルール"),
                    SetupChannel(name: "🔔│配信通知", type: .announcement),
                ]),
                SetupCategory(name: "💬 おしゃべり", channels: [
                    SetupChannel(name: "💬│雑談"),
                    SetupChannel(name: "🎨│ファンアート"),
                    SetupChannel(name: "💌│応援メッセージ"),
                ]),
                SetupCategory(name: "🎤 VC", channels: [
                    SetupChannel(name: "🎤│配信同時視聴", type: .voice),
                    SetupChannel(name: "🎤│雑談部屋", type: .voice),
                ]),
                SetupCategory(name: "🌟 サポーター限定", channels: [
                    SetupChannel(name: "⭐│限定チャット", isPrivate: true),
                    SetupChannel(name: "🎤│限定VC", type: .voice, isPrivate: true),
                ]),
            ],
            roles: [
                SetupRole(name: "🌟 配信者", colorHex: 0xF59E0B,
                          permissions: RolePermissions(sendMessages: true, manageMessages: true, manageChannels: true,
                                                        manageRoles: true, kickMembers: true, banMembers: true,
                                                        mentionEveryone: true, viewAuditLog: true)),
                SetupRole(name: "🛡 モデレーター", colorHex: 0x5865F2,
                          permissions: RolePermissions(sendMessages: true, manageMessages: true,
                                                        kickMembers: true, banMembers: true)),
                SetupRole(name: "⭐ サポーター", colorHex: 0xEC4899,
                          permissions: RolePermissions(sendMessages: true)),
                SetupRole(name: "💬 ファン", colorHex: 0x99AAB5,
                          permissions: RolePermissions(sendMessages: true), isAutoAssigned: true),
            ],
            onboarding: OnboardingSetup(rulesEnabled: true, welcomeEnabled: true,
                                         verifyEnabled: true, autoRoleEnabled: true, autoRoleName: "💬 ファン")
        )
    )

    static let community = ServerTemplate(
        id: "community",
        icon: "person.3.fill",
        iconColor: .accentOrange,
        name: "コミュニティ",
        description: "シンプルで誰でも使いやすい汎用コミュニティのスタンダード構成",
        tags: ["汎用", "趣味", "交流"],
        usageCount: 31_000,
        draft: ServerSetupDraft(
            serverName: "コミュニティサーバー",
            templateId: "community",
            categories: [
                SetupCategory(name: "📢 インフォ", channels: [
                    SetupChannel(name: "📢│お知らせ", type: .announcement),
                    SetupChannel(name: "📋│ルール"),
                    SetupChannel(name: "👋│自己紹介"),
                ]),
                SetupCategory(name: "💬 チャット", channels: [
                    SetupChannel(name: "💬│general"),
                    SetupChannel(name: "😄│ネタ・雑談"),
                    SetupChannel(name: "🖼️│画像・動画"),
                ]),
                SetupCategory(name: "🎤 VC", channels: [
                    SetupChannel(name: "🎤│雑談", type: .voice),
                    SetupChannel(name: "🎤│作業", type: .voice),
                ]),
            ],
            roles: [
                SetupRole(name: "👑 管理者", colorHex: 0xF59E0B,
                          permissions: RolePermissions(sendMessages: true, manageMessages: true, manageChannels: true,
                                                        manageRoles: true, kickMembers: true, banMembers: true,
                                                        mentionEveryone: true, viewAuditLog: true)),
                SetupRole(name: "🛡 モデレーター", colorHex: 0x5865F2,
                          permissions: RolePermissions(sendMessages: true, manageMessages: true,
                                                        kickMembers: true, banMembers: true)),
                SetupRole(name: "💬 メンバー", colorHex: 0x99AAB5,
                          permissions: RolePermissions(sendMessages: true), isAutoAssigned: true),
            ],
            onboarding: OnboardingSetup(rulesEnabled: true, welcomeEnabled: true,
                                         autoRoleEnabled: true, autoRoleName: "💬 メンバー")
        )
    )
}

// MARK: - Channel Name Suggestions (context-aware)

extension SetupCategory {
    var channelSuggestions: [String] {
        let existing = Set(channels.map { $0.name.lowercased() })
        let pool: [String]
        switch name.lowercased() {
        case let n where n.contains("お知らせ") || n.contains("info"):
            pool = ["📢│お知らせ", "📋│ルール", "👋│自己紹介", "🔔│更新情報"]
        case let n where n.contains("vc") || n.contains("ボイス"):
            pool = ["🎤│雑談VC", "🎤│作業VC", "🎤│配信VC", "🎤│AFK"]
        case let n where n.contains("ゲーム") || n.contains("game"):
            pool = ["🎮│雑談", "🎯│fps", "🗺️│rpg", "🃏│カードゲーム"]
        default:
            pool = ["💬│general", "🖼️│画像・動画", "💡│質問", "🎉│イベント", "🤖│bot-commands"]
        }
        return pool.filter { !existing.contains($0.lowercased()) }.prefix(4).map { $0 }
    }
}
