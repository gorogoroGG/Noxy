import SwiftUI

struct TemplatePickerView: View {
    @Binding var path: NavigationPath
    @State private var selectedTag: String? = nil

    private var allTags: [String] {
        let tags = ServerTemplate.all.flatMap(\.tags)
        return Array(NSOrderedSet(array: tags).array as! [String])
    }

    private var filtered: [ServerTemplate] {
        guard let tag = selectedTag else { return ServerTemplate.all }
        return ServerTemplate.all.filter { $0.tags.contains(tag) }
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: .spacing20) {
                    tagFilterRow
                    templateList
                    Spacer(minLength: .spacing32)
                }
                .padding(.horizontal, .spacing16)
                .padding(.top, .spacing8)
            }
        }
        .navigationTitle("テンプレートを選ぶ")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Tag Filter

    private var tagFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .spacing8) {
                TagChip(label: "すべて", isSelected: selectedTag == nil) {
                    selectedTag = nil
                }
                ForEach(allTags, id: \.self) { tag in
                    TagChip(label: tag, isSelected: selectedTag == tag) {
                        selectedTag = selectedTag == tag ? nil : tag
                    }
                }
            }
        }
    }

    // MARK: - Template List

    private var templateList: some View {
        LazyVStack(spacing: .spacing12) {
            ForEach(filtered) { template in
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    path.append(SetupDestination.editor(template.draft))
                } label: {
                    TemplateCard(template: template)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Tag Chip

private struct TagChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.captionRegular)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : Color.textSecondary)
                .padding(.horizontal, .spacing12)
                .padding(.vertical, .spacing6)
                .background(isSelected ? Color.accentIndigo : Color.bgSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Template Card

private struct TemplateCard: View {
    let template: ServerTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            // Header
            HStack(spacing: .spacing12) {
                Image(systemName: template.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(template.iconColor)
                    .frame(width: 52, height: 52)
                    .background(template.iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: .spacing4) {
                    Text(template.name)
                        .font(.titleMedium)
                        .foregroundStyle(Color.textPrimary)
                    Text(template.description)
                        .font(.captionRegular)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            // Stats row
            HStack(spacing: .spacing16) {
                StatPill(icon: "folder", value: "\(template.draft.categories.count)カテゴリ")
                StatPill(icon: "number", value: "\(template.draft.categories.flatMap(\.channels).count)ch")
                StatPill(icon: "shield", value: "\(template.draft.roles.count)ロール")
                Spacer()
            }

            // Tags
            HStack(spacing: .spacing6) {
                ForEach(template.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.captionSmall)
                        .foregroundStyle(template.iconColor)
                        .padding(.horizontal, .spacing8)
                        .padding(.vertical, 3)
                        .background(template.iconColor.opacity(0.1))
                        .clipShape(Capsule())
                }
                Spacer()
                Text(usageLabel)
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
            }

            // CTA
            HStack {
                Spacer()
                Label("このテンプレートで始める", systemImage: "arrow.right")
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(template.iconColor)
            }
        }
        .padding(.spacing16)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    private var usageLabel: String {
        let n = template.usageCount
        return n >= 1000 ? "\(n / 1000)k 件使用" : "\(n) 件使用"
    }
}

private struct StatPill: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.captionSmall)
            Text(value)
                .font(.captionSmall)
        }
        .foregroundStyle(Color.textTertiary)
    }
}

#Preview {
    NavigationStack {
        TemplatePickerView(path: .constant(NavigationPath()))
    }
    .preferredColorScheme(.dark)
}
