import Foundation
import SwiftUI

struct EmbedFieldModel: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var value: String
    var inline: Bool
}

struct EmbedModel: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var guildId: String?

    // メッセージ本文（埋め込みの外＝通常テキスト。メンション/変数が機能する）
    var messageContent: String?

    // Content
    var title: String?
    var embedUrl: String?
    var description: String?
    var colorHex: UInt32

    // Fields
    var fields: [EmbedFieldModel]

    // Media
    var imageUrl: String?
    var thumbnailUrl: String?

    // Footer
    var footerText: String?
    var footerIconUrl: String?
    var showTimestamp: Bool

    var createdAt: Date
    var updatedAt: Date

    // MARK: - CodingKeys
    enum CodingKeys: String, CodingKey {
        case id, name, guildId, messageContent, title, embedUrl, description, colorHex
        case fields, imageUrl, thumbnailUrl
        case footerText, footerIconUrl, showTimestamp
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        guildId = try container.decodeIfPresent(String.self, forKey: .guildId)
        messageContent = try container.decodeIfPresent(String.self, forKey: .messageContent)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        embedUrl = try container.decodeIfPresent(String.self, forKey: .embedUrl)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        colorHex = try container.decodeIfPresent(UInt32.self, forKey: .colorHex) ?? 0x5865F2
        // fields: JSONB から配列、または文字列化された JSON 配列の両方に対応
        if let fieldArray = try? container.decodeIfPresent([EmbedFieldModel].self, forKey: .fields) {
            fields = fieldArray
        } else if let fieldString = try? container.decodeIfPresent(String.self, forKey: .fields),
                  let fieldData = fieldString.data(using: .utf8),
                  let fieldArray = try? JSONDecoder().decode([EmbedFieldModel].self, from: fieldData) {
            fields = fieldArray
        } else {
            fields = []
        }
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        footerText = try container.decodeIfPresent(String.self, forKey: .footerText)
        footerIconUrl = try container.decodeIfPresent(String.self, forKey: .footerIconUrl)
        showTimestamp = try container.decodeIfPresent(Bool.self, forKey: .showTimestamp) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
    }

    // Required for Hashable when custom CodingKeys are defined
    init(id: String, name: String, guildId: String? = nil,
         messageContent: String? = nil,
         title: String?, embedUrl: String?, description: String?,
         colorHex: UInt32, fields: [EmbedFieldModel],
         imageUrl: String?, thumbnailUrl: String?,
         footerText: String?, footerIconUrl: String?, showTimestamp: Bool,
         createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.guildId = guildId
        self.messageContent = messageContent
        self.title = title
        self.embedUrl = embedUrl
        self.description = description
        self.colorHex = colorHex
        self.fields = fields
        self.imageUrl = imageUrl
        self.thumbnailUrl = thumbnailUrl
        self.footerText = footerText
        self.footerIconUrl = footerIconUrl
        self.showTimestamp = showTimestamp
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var totalCharCount: Int {
        let parts: [String?] = [title, description, footerText]
            + fields.flatMap { [$0.name, $0.value] }
        return parts.compactMap(\.self).reduce(0) { $0 + $1.count }
    }

    // MARK: - Discord Limits
    static let limitTitle = 256
    static let limitDescription = 4096
    static let limitFieldName = 256
    static let limitFieldValue = 1024
    static let limitFooter = 2048
    static let maxFields = 25

    func isOverLimit(for path: KeyPath<EmbedModel, String?>) -> Bool {
        switch path {
        case \.title: return (self[keyPath: path] ?? "").count > Self.limitTitle
        case \.description: return (self[keyPath: path] ?? "").count > Self.limitDescription
        case \.footerText: return (self[keyPath: path] ?? "").count > Self.limitFooter
        default: return false
        }
    }

    func isFieldOverLimit(index: Int, isName: Bool) -> Bool {
        guard fields.indices.contains(index) else { return false }
        let text = isName ? fields[index].name : fields[index].value
        let limit = isName ? Self.limitFieldName : Self.limitFieldValue
        return text.count > limit
    }

    var hasAnyLimitViolation: Bool {
        isOverLimit(for: \.title) ||
        isOverLimit(for: \.description) ||
        isOverLimit(for: \.footerText) ||
        fields.count > Self.maxFields ||
        fields.enumerated().contains { idx, f in
            f.name.count > Self.limitFieldName || f.value.count > Self.limitFieldValue
        }
    }

    static func blank() -> EmbedModel {
        EmbedModel(
            id: UUID().uuidString,
            name: "",
            title: nil, embedUrl: nil, description: nil,
            colorHex: 0x5865F2,
            fields: [],
            imageUrl: nil, thumbnailUrl: nil,
            footerText: nil, footerIconUrl: nil,
            showTimestamp: false,
            createdAt: .now, updatedAt: .now
        )
    }

    // MARK: - Discord Payload

    var asDiscordPayload: [String: Any] {
        var payload: [String: Any] = ["type": "rich"]
        if let title { payload["title"] = title }
        if let description { payload["description"] = description }
        if let embedUrl { payload["url"] = embedUrl }
        payload["color"] = Int(colorHex)
        if !fields.isEmpty {
            payload["fields"] = fields.map { [
                "name": $0.name,
                "value": $0.value,
                "inline": $0.inline
            ] }
        }
        if let imageUrl { payload["image"] = ["url": imageUrl] }
        if let thumbnailUrl { payload["thumbnail"] = ["url": thumbnailUrl] }
        if footerText != nil || showTimestamp {
            var footer: [String: Any] = [:]
            if let footerText { footer["text"] = footerText }
            if let footerIconUrl { footer["icon_url"] = footerIconUrl }
            payload["footer"] = footer
        }
        if showTimestamp {
            payload["timestamp"] = ISO8601DateFormatter().string(from: Date())
        }
        return payload
    }
}
