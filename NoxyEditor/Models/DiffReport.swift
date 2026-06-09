import Foundation

struct DiffReport {
    let changes: [ChangeRecord]
    let generatedAt: Date

    func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(changes) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    func toMarkdown() -> String {
        var lines: [String] = []
        lines.append("# UI Edit Diff Report")
        lines.append("")
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        lines.append("Generated: \(formatter.string(from: generatedAt))")
        lines.append("")
        lines.append("---")
        lines.append("")

        if changes.isEmpty {
            lines.append("No changes detected.")
            return lines.joined(separator: "\n")
        }

        lines.append("## Summary")
        lines.append("")
        lines.append("- **Total changes:** \(changes.count)")
        lines.append("- **Components affected:** \(Set(changes.map(\.componentPath)).count)")
        lines.append("")
        lines.append("---")
        lines.append("")

        let grouped = Dictionary(grouping: changes, by: \.componentPath)

        for (path, pathChanges) in grouped.sorted(by: { $0.key < $1.key }) {
            lines.append("### `\(path)`")
            lines.append("")
            for change in pathChanges {
                lines.append("- **\(change.propertyName):**")
                lines.append("  - Before: `\(change.oldValue)`")
                lines.append("  - After: `\(change.newValue)`")
            }
            lines.append("")
        }

        lines.append("---")
        lines.append("")
        lines.append("## AI Prompt Template")
        lines.append("")
        lines.append("```")
        lines.append("以下のUI変更を行ってください：")
        lines.append("")
        for change in changes {
            lines.append("- \(change.componentPath)の\(change.propertyName)を「\(change.oldValue)」から「\(change.newValue)」に変更")
        }
        lines.append("```")

        return lines.joined(separator: "\n")
    }
}
