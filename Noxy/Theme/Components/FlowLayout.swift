import SwiftUI

/// Wrapping flow layout (chips, tags)
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let w = proposal.width ?? 300
        var h: CGFloat = 0; var x: CGFloat = 0; var rh: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > w && x > 0 { h += rh + spacing; x = 0; rh = 0 }
            x += s.width + spacing; rh = max(rh, s.height)
        }
        return CGSize(width: w, height: h + rh)
    }

    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = b.minX; var y = b.minY; var rh: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > b.maxX && x > b.minX { y += rh + spacing; x = b.minX; rh = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; rh = max(rh, s.height)
        }
    }
}
