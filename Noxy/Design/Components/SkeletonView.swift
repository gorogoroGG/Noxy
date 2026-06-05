import SwiftUI

struct SkeletonView: View {
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        GeometryReader { geo in
            Color.bgElevated
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.white.opacity(0.05), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 200)
                        .offset(x: shimmerOffset)
                        .onAppear {
                            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                shimmerOffset = geo.size.width + 200
                            }
                        }
                }
        }
        .clipped()
    }
}

struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: .spacing12) {
            SkeletonView()
                .frame(width: 40, height: 40)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: .spacing8) {
                SkeletonView()
                    .frame(width: 120, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                SkeletonView()
                    .frame(width: 200, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Spacer()
        }
        .padding(.vertical, .spacing8)
    }
}

struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            SkeletonView()
                .frame(height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            SkeletonView()
                .frame(height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.spacing16)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }
}

struct SkeletonListView: View {
    let count: Int

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonRow()
                    .padding(.horizontal)
                Divider().background(Color.border).padding(.leading, .spacing64)
            }
        }
    }
}

#Preview {
    VStack(spacing: .spacing16) {
        SkeletonListView(count: 5)
        SkeletonCard()
            .padding(.horizontal)
    }
    .padding(.vertical)
    .background(Color.bgPrimary)
}
