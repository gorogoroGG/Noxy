import SwiftUI
import Foundation

// MARK: - Channel

enum SetupChannelType: String, Codable, CaseIterable {
    case text, voice, forum, announcement

    var icon: String {
        switch self {
        case .text:         "number"
        case .voice:        "speaker.wave.2.fill"
        case .forum:        "bubble.left.and.bubble.right.fill"
        case .announcement: "megaphone.fill"
        }
    }

    var label: String {
        switch self {
        case .text:         "テキスト"
        case .voice:        "ボイス"
        case .forum:        "フォーラム"
        case .announcement: "アナウンス"
        }
    }

    func next() -> SetupChannelType {
        let all = SetupChannelType.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

struct SetupChannel: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var type: SetupChannelType = .text
    var isPrivate: Bool = false
}

// MARK: - Category

struct SetupCategory: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var channels: [SetupChannel] = []
    var isExpanded: Bool = true
}

// MARK: - Role

struct RolePermissions: Codable {
    var sendMessages:    Bool = true
    var manageMessages:  Bool = false
    var manageChannels:  Bool = false
    var manageRoles:     Bool = false
    var kickMembers:     Bool = false
    var banMembers:      Bool = false
    var mentionEveryone: Bool = false
    var viewAuditLog:    Bool = false
}

struct SetupRole: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var colorHex: UInt32 = 0x99AAB5
    var permissions: RolePermissions = .init()
    var isAutoAssigned: Bool = false

    var swiftUIColor: Color { Color(uiColor: UIColor(hex: colorHex)) }
}

// MARK: - Onboarding

struct OnboardingSetup: Codable {
    var rulesEnabled:       Bool   = false
    var rulesChannelName:   String = "📜│ルール"
    var welcomeEnabled:     Bool   = false
    var welcomeChannelName: String = "👋│ようこそ"
    var verifyEnabled:      Bool   = false
    var autoRoleEnabled:    Bool   = false
    var autoRoleName:       String = "メンバー"
}

// MARK: - Draft

struct ServerSetupDraft: Identifiable, Codable {
    var id: UUID = UUID()
    var serverName: String = ""
    var templateId: String? = nil
    var categories: [SetupCategory] = []
    var roles: [SetupRole] = []
    var onboarding: OnboardingSetup = .init()
}

// MARK: - Template

struct ServerTemplate: Identifiable {
    let id: String
    let icon: String
    let iconColor: Color
    let name: String
    let description: String
    let tags: [String]
    let usageCount: Int
    let draft: ServerSetupDraft
}
