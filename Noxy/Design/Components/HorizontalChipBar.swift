import SwiftUI
import UIKit

// MARK: - HorizontalChipBar
// UIKit の UIScrollView を使って横方向のみスクロール可能なチップバーを実現する。
// SwiftUI の ScrollView(.horizontal) は sheet+NavigationStack コンテキストで縦ジェスチャーが
// 親ビューに伝播する問題があるため、UIViewRepresentable で完全にコントロールする。

struct HorizontalChipBar: UIViewRepresentable {
    let chips: [(label: String, value: String)]
    let accentColor: Color
    let doneTitle: String
    let onChipTap: (String) -> Void
    let onDone: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> ChipContainerView {
        let container = ChipContainerView()
        container.backgroundColor = .clear

        // ─── UIScrollView（横専用） ───
        let scroll = HorizontalOnlyScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator   = false
        scroll.alwaysBounceHorizontal = true
        scroll.alwaysBounceVertical   = false
        scroll.delegate               = context.coordinator
        scroll.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scroll)

        // ─── チップ用StackView ───
        let stack = UIStackView()
        stack.axis    = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -8),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])

        // ─── 完了ボタン ───
        let doneBtn = UIButton(type: .system)
        doneBtn.setTitle(doneTitle, for: .normal)
        doneBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        doneBtn.setTitleColor(UIColor(accentColor), for: .normal)
        doneBtn.addTarget(context.coordinator, action: #selector(Coordinator.doneTapped), for: .touchUpInside)
        doneBtn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(doneBtn)

        NSLayoutConstraint.activate([
            doneBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            doneBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            doneBtn.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),

            scroll.topAnchor.constraint(equalTo: container.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: doneBtn.leadingAnchor, constant: -8),
        ])

        context.coordinator.stackView  = stack
        context.coordinator.scrollView = scroll

        buildChips(in: stack, coordinator: context.coordinator)

        return container
    }

    func updateUIView(_ uiView: ChipContainerView, context: Context) {
        guard let stack = context.coordinator.stackView else { return }
        // チップが変わったときのみ再構築
        if stack.arrangedSubviews.count != chips.count {
            buildChips(in: stack, coordinator: context.coordinator)
        }
        // カラー更新
        context.coordinator.updateColor(UIColor(accentColor))
    }

    // MARK: - chip 構築

    private func buildChips(in stack: UIStackView, coordinator: Coordinator) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let uiColor = UIColor(accentColor)
        for (i, chip) in chips.enumerated() {
            let btn = makeChipButton(title: chip.label, tag: i, color: uiColor, coordinator: coordinator)
            stack.addArrangedSubview(btn)
        }
    }

    private func makeChipButton(title: String, tag: Int, color: UIColor, coordinator: Coordinator) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.setTitle(title, for: .normal)
        btn.tag = tag
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        btn.setTitleColor(color, for: .normal)
        btn.backgroundColor = color.withAlphaComponent(0.1)
        btn.layer.cornerRadius = 12
        btn.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        btn.addTarget(coordinator, action: #selector(Coordinator.chipTapped(_:)), for: .touchUpInside)
        return btn
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: HorizontalChipBar
        var stackView: UIStackView?
        var scrollView: UIScrollView?

        init(parent: HorizontalChipBar) {
            self.parent = parent
        }

        // y オフセットを常に 0 に固定（ダブルガード）
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if scrollView.contentOffset.y != 0 {
                scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: 0)
            }
        }

        @objc func chipTapped(_ sender: UIButton) {
            guard sender.tag < parent.chips.count else { return }
            parent.onChipTap(parent.chips[sender.tag].value)
        }

        @objc func doneTapped() {
            parent.onDone()
        }

        func updateColor(_ color: UIColor) {
            guard let stack = stackView else { return }
            for case let btn as UIButton in stack.arrangedSubviews {
                btn.setTitleColor(color, for: .normal)
                btn.backgroundColor = color.withAlphaComponent(0.1)
            }
        }
    }
}

// MARK: - HorizontalOnlyScrollView
// 縦ジェスチャーを完全に拒否する UIScrollView サブクラス。

final class HorizontalOnlyScrollView: UIScrollView {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        let v = pan.velocity(in: self)
        // 横速度が縦速度より大きい場合のみジェスチャーを開始（縦は完全拒否）
        return abs(v.x) > abs(v.y)
    }
}

// MARK: - BlockerGestureDelegate
// UIView と UIGestureRecognizerDelegate のメソッド名衝突を避けるため別クラスに分離。

private final class BlockerGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
              let view = gestureRecognizer.view else { return true }
        let v = pan.velocity(in: view)
        // 縦優位のジェスチャーにのみ反応する（横は UIScrollView に委ねる）
        return abs(v.y) > abs(v.x)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        return true  // UIScrollView の横スクロールと同時認識を許可
    }
}

// MARK: - ChipContainerView
// 縦ジェスチャーを UIKit レベルで吸収し、親の SwiftUI ScrollView へ伝播させない。

final class ChipContainerView: UIView {
    private var blocker: UIPanGestureRecognizer!
    private var blockerDelegate: BlockerGestureDelegate!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        blockerDelegate = BlockerGestureDelegate()
        blocker = UIPanGestureRecognizer(target: self, action: #selector(absorb))
        blocker.cancelsTouchesInView = false  // ボタンタップを妨げない
        blocker.delegate = blockerDelegate
        addGestureRecognizer(blocker)
    }

    @objc private func absorb(_ gesture: UIPanGestureRecognizer) {
        // 縦ジェスチャーをここで消費・何もしない
    }
}
