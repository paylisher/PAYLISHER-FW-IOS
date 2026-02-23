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

        // Page control dots
        pageControl.numberOfPages = layouts.count
        pageControl.currentPage   = 0
        pageControl.isHidden      = layouts.count <= 1
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(pageControl)

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

        // Build each page
        for layout in layouts {
            let page = buildPageView(layout)
            page.translatesAutoresizingMaskIntoConstraints = false
            page.widthAnchor.constraint(equalTo: pageScrollView.frameLayoutGuide.widthAnchor).isActive = true
            pagesStack.addArrangedSubview(page)
        }

        // Close button (subview of view — can float outside containerView for outside-* positions)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.isHidden = true
        view.addSubview(closeButton)

        // Prev / Next arrows
        prevArrow.translatesAutoresizingMaskIntoConstraints = false
        nextArrow.translatesAutoresizingMaskIntoConstraints = false
        prevArrow.setImage(UIImage(systemName: "chevron.left.circle.fill"), for: .normal)
        nextArrow.setImage(UIImage(systemName: "chevron.right.circle.fill"), for: .normal)
        prevArrow.tintColor = UIColor.systemGray
        nextArrow.tintColor = UIColor.systemGray
        view.addSubview(prevArrow)
        view.addSubview(nextArrow)

        // Container positioning
        if isFullscreen {
            NSLayoutConstraint.activate([
                containerView.topAnchor.constraint(equalTo: view.topAnchor),
                containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

                pageScrollView.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor),
                pageScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                pageScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                pageScrollView.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -4),

                pageControl.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -8),
                pageControl.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                pageControl.heightAnchor.constraint(equalToConstant: 24),
            ])
            NSLayoutConstraint.activate([
                prevArrow.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                prevArrow.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
                prevArrow.widthAnchor.constraint(equalToConstant: 36),
                prevArrow.heightAnchor.constraint(equalToConstant: 36),

                nextArrow.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                nextArrow.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                nextArrow.widthAnchor.constraint(equalToConstant: 36),
                nextArrow.heightAnchor.constraint(equalToConstant: 36),
            ])
        } else {
            // Modal carousel: centered, 350pt wide, 65% of screen height
            NSLayoutConstraint.activate([
                containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                containerView.widthAnchor.constraint(equalToConstant: 350),
                containerView.heightAnchor.constraint(equalToConstant: UIScreen.main.bounds.height * 0.65),

                pageScrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
                pageScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                pageScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                pageScrollView.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -4),

                pageControl.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
                pageControl.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                pageControl.heightAnchor.constraint(equalToConstant: 24),
            ])
            // Arrows outside the containerView
            NSLayoutConstraint.activate([
                prevArrow.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                prevArrow.trailingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: -4),
                prevArrow.widthAnchor.constraint(equalToConstant: 36),
                prevArrow.heightAnchor.constraint(equalToConstant: 36),

                nextArrow.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                nextArrow.leadingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: 4),
                nextArrow.widthAnchor.constraint(equalToConstant: 36),
                nextArrow.heightAnchor.constraint(equalToConstant: 36),
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

        let position = close.position ?? "right"
        // For fullscreen use safeArea, for modal containerView.topAnchor is already safe
        let topAnchor: NSLayoutYAxisAnchor = isFullscreen
            ? view.safeAreaLayoutGuide.topAnchor
            : containerView.topAnchor

        switch position {
        case "left":
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
                closeButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            ])
        case "outside-left":
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: topAnchor, constant: isFullscreen ? 8 : -28),
                closeButton.trailingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            ])
        case "outside-right":
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: topAnchor, constant: isFullscreen ? 8 : -28),
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
