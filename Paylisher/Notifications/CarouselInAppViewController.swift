//
//  CarouselInAppViewController.swift
//  Paylisher
//

import UIKit

class CarouselInAppViewController: UIViewController, UIScrollViewDelegate {

    // MARK: - Properties

    private let layouts: [CustomInAppPayload.Layout]
    private let defaultLang: String
    private let isFullscreen: Bool

    private var currentIndex: Int = 0

    // MARK: - UI

    private let overlayView    = UIView()
    private let containerView  = UIView()
    private let pageScrollView = UIScrollView()
    private let pageControl    = UIPageControl()
    private let closeButton    = UIButton(type: .system)
    private let prevArrow      = UIButton(type: .system)
    private let nextArrow      = UIButton(type: .system)

    // MARK: - Init

    init(layouts: [CustomInAppPayload.Layout], defaultLang: String, isFullscreen: Bool = false) {
        self.layouts      = layouts
        self.defaultLang  = defaultLang
        self.isFullscreen = isFullscreen
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        prevArrow.addTarget(self, action: #selector(didTapPrev), for: .touchUpInside)
        nextArrow.addTarget(self, action: #selector(didTapNext), for: .touchUpInside)
    }

    // MARK: - Setup

    private func setupUI() {
        // Overlay
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        // Container
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Horizontal paging scroll view
        pageScrollView.isPagingEnabled                = true
        pageScrollView.showsHorizontalScrollIndicator = false
        pageScrollView.showsVerticalScrollIndicator   = false
        pageScrollView.bounces                        = false
        pageScrollView.delegate                       = self
        pageScrollView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(pageScrollView)

        // Pages horizontal stack
        let pagesStack = UIStackView()
        pagesStack.axis         = .horizontal
        pagesStack.spacing      = 0
        pagesStack.distribution = .fillEqually
        pagesStack.translatesAutoresizingMaskIntoConstraints = false
        pageScrollView.addSubview(pagesStack)

        NSLayoutConstraint.activate([
            pagesStack.topAnchor.constraint(equalTo: pageScrollView.contentLayoutGuide.topAnchor),
            pagesStack.leadingAnchor.constraint(equalTo: pageScrollView.contentLayoutGuide.leadingAnchor),
            pagesStack.trailingAnchor.constraint(equalTo: pageScrollView.contentLayoutGuide.trailingAnchor),
            pagesStack.bottomAnchor.constraint(equalTo: pageScrollView.contentLayoutGuide.bottomAnchor),
            pagesStack.heightAnchor.constraint(equalTo: pageScrollView.frameLayoutGuide.heightAnchor),
        ])

        // Build each page — add to hierarchy FIRST, then activate the width constraint
        for layout in layouts {
            let page = buildPageView(layout)
            page.translatesAutoresizingMaskIntoConstraints = false
            pagesStack.addArrangedSubview(page)
            page.widthAnchor.constraint(equalTo: pageScrollView.frameLayoutGuide.widthAnchor).isActive = true
        }

        // Bottom navigation bar: [< prev]  [● ○ ○]  [next >]
        // Arrows and page dots live here — completely separate from content.
        let bottomBar = UIView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(bottomBar)

        prevArrow.translatesAutoresizingMaskIntoConstraints = false
        nextArrow.translatesAutoresizingMaskIntoConstraints = false
        prevArrow.setImage(UIImage(systemName: "chevron.left.circle.fill"), for: .normal)
        nextArrow.setImage(UIImage(systemName: "chevron.right.circle.fill"), for: .normal)
        prevArrow.tintColor = UIColor.systemGray
        nextArrow.tintColor = UIColor.systemGray
        bottomBar.addSubview(prevArrow)
        bottomBar.addSubview(nextArrow)

        pageControl.numberOfPages = layouts.count
        pageControl.currentPage   = 0
        pageControl.isHidden      = layouts.count <= 1
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(pageControl)

        NSLayoutConstraint.activate([
            prevArrow.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            prevArrow.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            prevArrow.widthAnchor.constraint(equalToConstant: 32),
            prevArrow.heightAnchor.constraint(equalToConstant: 32),

            nextArrow.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -16),
            nextArrow.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            nextArrow.widthAnchor.constraint(equalToConstant: 32),
            nextArrow.heightAnchor.constraint(equalToConstant: 32),

            pageControl.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
            pageControl.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
        ])

        // Close button (subview of view — can float outside containerView for outside-* positions)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.isHidden = true
        view.addSubview(closeButton)

        if isFullscreen {
            NSLayoutConstraint.activate([
                containerView.topAnchor.constraint(equalTo: view.topAnchor),
                containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

                pageScrollView.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor),
                pageScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                pageScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                pageScrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

                bottomBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                bottomBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                bottomBar.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor),
                bottomBar.heightAnchor.constraint(equalToConstant: 48),
            ])
        } else {
            // Modal carousel: centered, 350pt wide, height derived from first layout's blocks
            let contentH    = estimatedFirstPageHeight(for: 350)
            let bottomBarH: CGFloat = 48
            let topPad: CGFloat     = 8
            let naturalH    = contentH + bottomBarH + topPad
            let maxH        = UIScreen.main.bounds.height * 0.75
            let containerH  = min(naturalH, maxH)

            NSLayoutConstraint.activate([
                containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                containerView.widthAnchor.constraint(equalToConstant: 350),
                containerView.heightAnchor.constraint(equalToConstant: containerH),

                pageScrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
                pageScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                pageScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                pageScrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

                bottomBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                bottomBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                bottomBar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                bottomBar.heightAnchor.constraint(equalToConstant: 48),
            ])
        }

        applyStyleFromFirstLayout()
        applyCloseFromFirstLayout()
        applyOverlayFromFirstLayout()
        updateArrows()
    }

    // MARK: - Style / Close / Overlay

    private func applyStyleFromFirstLayout() {
        guard let style = layouts.first?.style else { return }

        if let hex = style.bgColor, let color = UIColor(hex: hex) {
            containerView.backgroundColor = color
        }

        if isFullscreen {
            containerView.layer.cornerRadius = 0
        } else {
            containerView.layer.cornerRadius = CGFloat(style.radius ?? 16)
        }
        containerView.clipsToBounds = true

        if let urlStr = style.bgImage, !urlStr.isEmpty, let url = URL(string: urlStr) {
            let bgView = UIImageView()
            bgView.contentMode = .scaleAspectFill
            bgView.clipsToBounds = true
            bgView.translatesAutoresizingMaskIntoConstraints = false
            containerView.insertSubview(bgView, at: 0)
            NSLayoutConstraint.activate([
                bgView.topAnchor.constraint(equalTo: containerView.topAnchor),
                bgView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                bgView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                bgView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            ])
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let img = UIImage(data: data) {
                    DispatchQueue.main.async { bgView.image = img }
                }
            }.resume()
        }
    }

    private func applyCloseFromFirstLayout() {
        guard let close = layouts.first?.close else { return }

        closeButton.isHidden = !(close.active ?? true)

        if let type = close.type {
            switch type {
            case "icon":
                var imgName = "xmark"
                if close.icon?.style == "outlined" { imgName = "xmark.circle" }
                else if close.icon?.style == "filled" { imgName = "xmark.circle.fill" }
                closeButton.setImage(UIImage(systemName: imgName), for: .normal)
                closeButton.tintColor = UIColor(hex: close.icon?.color ?? "") ?? .black
            case "text":
                let label = close.text?.label?[defaultLang] ?? close.text?.label?.values.first ?? "X"
                closeButton.setTitle(label, for: .normal)
            default:
                break
            }
        }

        // For fullscreen use safeArea; for modal, containerView.topAnchor is safe.
        let topAnchor: NSLayoutYAxisAnchor = isFullscreen
            ? view.safeAreaLayoutGuide.topAnchor
            : containerView.topAnchor

        // "outside-*" positions are only safe when there is room beside the container.
        // For modal carousel (350pt on ~393pt screen) they would overflow, so treat
        // them as "right"/"left" inside the container.
        let position = close.position ?? "right"
        let resolvedPosition: String
        if !isFullscreen && (position == "outside-left" || position == "outside-right") {
            resolvedPosition = position == "outside-left" ? "left" : "right"
        } else {
            resolvedPosition = position
        }

        switch resolvedPosition {
        case "left":
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
                closeButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            ])
        case "outside-left":
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
                closeButton.trailingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            ])
        case "outside-right":
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
                closeButton.leadingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            ])
        default: // "right"
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
                closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            ])
        }
    }

    private func applyOverlayFromFirstLayout() {
        guard let extra = layouts.first?.extra else { return }

        if let hex = extra.overlay?.color, let color = UIColor(hex: hex) {
            overlayView.backgroundColor = color.withAlphaComponent(0.5)
        }
        if extra.overlay?.action == "close" {
            overlayView.isUserInteractionEnabled = true
            overlayView.addGestureRecognizer(
                UITapGestureRecognizer(target: self, action: #selector(didTapClose))
            )
        }
    }

    // MARK: - Dynamic height estimation

    /// Computes the approximate pixel height of the first layout's block stack
    /// for a given container width. Used to size the modal height dynamically.
    private func estimatedFirstPageHeight(for width: CGFloat) -> CGFloat {
        guard let layout = layouts.first, let blocks = layout.blocks?.order else { return 350 }

        var height: CGFloat = 8 // top padding
        for block in blocks {
            switch block {
            case .image(let ib):
                let margin = CGFloat(ib.margin ?? 0) * 2
                height += 150 + margin

            case .text(let tb):
                let text  = tb.content?[defaultLang] ?? tb.content?.values.first ?? ""
                let size  = CGFloat(Double(tb.fontSize ?? "14") ?? 14)
                let hm    = CGFloat(tb.horizontalMargin ?? 0)
                let tw    = width - (hm > 0 ? hm * 2 : 32)
                let rect  = (text as NSString).boundingRect(
                    with: CGSize(width: tw, height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin,
                    attributes: [.font: UIFont.systemFont(ofSize: size)],
                    context: nil
                )
                height += ceil(rect.height) + 8

            case .spacer(let sb):
                height += CGFloat(sb.verticalSpacing ?? 8)

            case .button(let bb):
                let m: CGFloat = CGFloat(bb.margin ?? 8)
                let h: CGFloat = bb.verticalSize == "small" ? 32 : bb.verticalSize == "large" ? 56 : 44
                height += h + m * 2

            case .buttonGroup(let bg):
                let isH   = bg.buttonGroupType == "double-horizontal"
                let count = CGFloat(bg.buttons?.count ?? 1)
                let rows: CGFloat = isH ? 1 : count
                height += rows * 44 + 16

            case .unknown:
                break
            }
        }
        height += 8 // bottom padding
        return height
    }

    // MARK: - Page building

    private func buildPageView(_ layout: CustomInAppPayload.Layout) -> UIView {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator   = false
        scrollView.showsHorizontalScrollIndicator = false

        let stack = UIStackView()
        stack.axis         = .vertical
        stack.spacing      = 0
        stack.alignment    = .fill
        stack.distribution = .equalSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        if let blocks = layout.blocks?.order {
            for block in blocks {
                var blockView: UIView?
                switch block {
                case .text(let tb):        blockView = renderTextBlock(tb)
                case .image(let ib):       blockView = renderImageBlock(ib)
                case .spacer(let sb):      blockView = renderSpacerBlock(sb)
                case .button(let bb):      blockView = renderButtonBlock(bb)
                case .buttonGroup(let bg): blockView = renderButtonGroupBlock(bg)
                case .unknown:             continue
                }
                if let v = blockView { stack.addArrangedSubview(v) }
            }
        }

        return scrollView
    }

    // MARK: - Navigation

    @objc private func didTapPrev() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        scrollToCurrentIndex(animated: true)
    }

    @objc private func didTapNext() {
        guard currentIndex < layouts.count - 1 else { return }
        currentIndex += 1
        scrollToCurrentIndex(animated: true)
    }

    private func scrollToCurrentIndex(animated: Bool) {
        let offset = CGPoint(x: pageScrollView.bounds.width * CGFloat(currentIndex), y: 0)
        pageScrollView.setContentOffset(offset, animated: animated)
        pageControl.currentPage = currentIndex
        updateArrows()
    }

    private func updateArrows() {
        prevArrow.isHidden = currentIndex == 0
        nextArrow.isHidden = currentIndex == layouts.count - 1
    }

    // UIScrollViewDelegate
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === pageScrollView, pageScrollView.bounds.width > 0 else { return }
        currentIndex = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        pageControl.currentPage = currentIndex
        updateArrows()
    }

    @objc private func didTapClose() {
        dismiss(animated: true)
    }

    // MARK: - Block Rendering

    private func renderTextBlock(_ block: CustomInAppPayload.Layout.Blocks.TextBlock) -> UIView {
        let label = UILabel()
        label.text = block.content?[defaultLang] ?? block.content?.values.first ?? ""
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        let font = makeFont(family: block.fontFamily, weight: block.fontWeight, size: block.fontSize)
        label.font = (block.italic == true) ? UIFont.italicSystemFont(ofSize: font.pointSize) : font

        if block.underscore == true {
            label.attributedText = NSAttributedString(string: label.text ?? "", attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .font: label.font as Any,
                .foregroundColor: UIColor(hex: block.color ?? "#000000") ?? UIColor.black,
            ])
        } else if let hex = block.color, let color = UIColor(hex: hex) {
            label.textColor = color
        }

        switch block.textAlignment {
        case "center": label.textAlignment = .center
        case "right":  label.textAlignment = .right
        default:       label.textAlignment = .left
        }

        let leading = CGFloat(block.horizontalMargin ?? 0) > 0
            ? CGFloat(block.horizontalMargin!) : 16

        let wrapper = UIView()
        label.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -4),
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: leading),
            label.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -leading),
        ])
        return wrapper
    }

    private func renderImageBlock(_ block: CustomInAppPayload.Layout.Blocks.ImageBlock) -> UIView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        if let r = block.radius { imageView.layer.cornerRadius = CGFloat(r) }
        imageView.heightAnchor.constraint(equalToConstant: 150).isActive = true

        if let urlStr = block.url, let url = URL(string: urlStr) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let img = UIImage(data: data) {
                    DispatchQueue.main.async { imageView.image = img }
                }
            }.resume()
        }

        let margin = CGFloat(block.margin ?? 0)
        let wrapper = UIView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: margin),
            imageView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -margin),
            imageView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: margin),
            imageView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -margin),
        ])
        return wrapper
    }

    private func renderSpacerBlock(_ block: CustomInAppPayload.Layout.Blocks.SpacerBlock) -> UIView {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: CGFloat(block.verticalSpacing ?? 8)).isActive = true
        return spacer
    }

    private func renderButtonBlock(
        _ block: CustomInAppPayload.Layout.Blocks.ButtonGroupBlock.ButtonBlock
    ) -> UIView {
        let button = createStyledButton(block)
        let margin: CGFloat = CGFloat(block.margin ?? 8)
        let height: CGFloat = block.verticalSize == "small" ? 32 : block.verticalSize == "large" ? 56 : 44

        let wrapper = UIView()
        button.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(button)

        var constraints: [NSLayoutConstraint] = [
            button.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: margin),
            button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -margin),
            button.heightAnchor.constraint(equalToConstant: height),
        ]

        let hSize = (block.horizontalSize ?? "").isEmpty ? "auto" : block.horizontalSize!
        if hSize == "full" {
            constraints.append(button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16))
            constraints.append(button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -16))
        } else {
            if hSize == "half" {
                constraints.append(button.widthAnchor.constraint(equalTo: wrapper.widthAnchor, multiplier: 0.5))
            } else {
                constraints.append(button.leadingAnchor.constraint(greaterThanOrEqualTo: wrapper.leadingAnchor, constant: 16))
                constraints.append(button.trailingAnchor.constraint(lessThanOrEqualTo: wrapper.trailingAnchor, constant: -16))
                button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 24, bottom: 8, right: 24)
            }
            switch block.buttonPosition {
            case "left":
                constraints.append(button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16))
            case "right":
                constraints.append(button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -16))
            default:
                constraints.append(button.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor))
            }
        }
        NSLayoutConstraint.activate(constraints)
        return wrapper
    }

    private func renderButtonGroupBlock(
        _ block: CustomInAppPayload.Layout.Blocks.ButtonGroupBlock
    ) -> UIView {
        guard let buttons = block.buttons, !buttons.isEmpty else { return UIView() }

        let isHorizontal = block.buttonGroupType == "double-horizontal"
        let stack = UIStackView()
        stack.axis         = isHorizontal ? .horizontal : .vertical
        stack.spacing      = 8
        stack.alignment    = .fill
        stack.distribution = isHorizontal ? .fillEqually : .fill

        for btnData in buttons {
            let btn = createStyledButton(btnData)
            let h: CGFloat = btnData.verticalSize == "small" ? 32 : btnData.verticalSize == "large" ? 56 : 44
            btn.heightAnchor.constraint(equalToConstant: h).isActive = true
            stack.addArrangedSubview(btn)
        }

        let wrapper = UIView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -16),
        ])
        return wrapper
    }

    private func createStyledButton(
        _ block: CustomInAppPayload.Layout.Blocks.ButtonGroupBlock.ButtonBlock
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(block.label?[defaultLang] ?? block.label?.values.first ?? "", for: .normal)
        button.titleLabel?.font = makeFont(family: block.fontFamily, weight: block.fontWeight, size: block.fontSize)

        if let hex = block.textColor, let c = UIColor(hex: hex) {
            button.setTitleColor(c, for: .normal)
        } else {
            button.setTitleColor(.white, for: .normal)
        }
        if let hex = block.backgroundColor, let c = UIColor(hex: hex) { button.backgroundColor = c }
        if let hex = block.borderColor, let c = UIColor(hex: hex) {
            button.layer.borderColor = c.cgColor
            button.layer.borderWidth = 1
        }
        button.layer.cornerRadius = CGFloat(block.borderRadius ?? 8)
        button.clipsToBounds = true
        button.accessibilityIdentifier = block.action ?? ""
        button.addTarget(self, action: #selector(handleButtonTap(_:)), for: .touchUpInside)
        return button
    }

    private func makeFont(family: String?, weight: String?, size: String?) -> UIFont {
        let sz: CGFloat = CGFloat(Double(size ?? "16") ?? 16)
        let w: UIFont.Weight = weight == "bold" ? .bold : .regular
        if family == "monospace" { return .monospacedSystemFont(ofSize: sz, weight: w) }
        return .systemFont(ofSize: sz, weight: w)
    }

    @objc private func handleButtonTap(_ sender: UIButton) {
        let action = sender.accessibilityIdentifier ?? ""
        if action.isEmpty || action == "close" { didTapClose(); return }
        if let url = URL(string: action) { UIApplication.shared.open(url) }
        didTapClose()
    }
}
