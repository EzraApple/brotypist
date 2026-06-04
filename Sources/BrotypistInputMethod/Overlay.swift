import AppKit
import BrotypistCore
import Foundation

final class SuggestionOverlayWindow: NSPanel {
    private let textView = SuggestionOverlayView()

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        hasShadow = false
        backgroundColor = .clear
        level = .popUpMenu
        animationBehavior = .none
        ignoresMouseEvents = true
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
        contentView = textView
    }

    func update(text: String, font: NSFont, caretRect: CGRect) {
        guard !text.isEmpty else {
            hide()
            return
        }

        let caretCenter = CGPoint(x: caretRect.midX, y: caretRect.midY)
        let visible = NSScreen.screens.first(where: { $0.frame.contains(caretCenter) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
        let availableWidth: CGFloat = {
            guard let visible else { return .greatestFiniteMagnitude }
            return max(120, visible.maxX - caretRect.maxX - 16)
        }()

        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        let bounds = attributed.boundingRect(
            with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let size = CGSize(width: bounds.width, height: bounds.height)

        let frame = OverlayLayout.frame(caretRect: caretRect, suggestionSize: size, visibleFrame: visible)

        let sameText = textView.text == text
        let sameFont = textView.font.fontName == font.fontName && abs(textView.font.pointSize - font.pointSize) < 0.1
        if isVisible, sameText, sameFont, self.frame.integral == frame.integral {
            return
        }

        textView.update(text: text, font: font)
        setFrame(frame, display: false)
        textView.frame = CGRect(origin: .zero, size: frame.size)
        textView.needsDisplay = true
        if isVisible {
            displayIfNeeded()
        } else {
            orderFrontRegardless()
        }
    }

    func hide() {
        orderOut(nil)
    }
}

private final class SuggestionOverlayView: NSView {
    private(set) var text = ""
    private(set) var font = NSFont.systemFont(ofSize: NSFont.systemFontSize)

    override var isFlipped: Bool { true }

    func update(text: String, font: NSFont) {
        self.text = text
        self.font = font
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !text.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        attributed.draw(with: bounds, options: [.usesLineFragmentOrigin, .usesFontLeading])
    }
}

enum OverlayTypography {
    static func displayFont(reportedFont: NSFont?, caretHeight: CGFloat) -> NSFont {
        guard caretHeight.isFinite, caretHeight > 4 else {
            return reportedFont ?? .systemFont(ofSize: NSFont.systemFontSize)
        }

        let fallbackSize = max(10, min(24, caretHeight * 0.72))
        let baseFont = reportedFont ?? .systemFont(ofSize: fallbackSize)
        let lineHeight = max(1, baseFont.ascender - baseFont.descender + baseFont.leading)
        let targetSize = max(10, min(28, baseFont.pointSize * (caretHeight / lineHeight)))

        guard abs(targetSize - baseFont.pointSize) > 1 else {
            return baseFont
        }

        return NSFont(descriptor: baseFont.fontDescriptor, size: targetSize) ?? .systemFont(ofSize: targetSize)
    }
}
