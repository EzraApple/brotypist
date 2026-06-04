import CoreGraphics
import Foundation

public enum OverlayLayout {
    /// Synthetic caret used when AX won't return per-range bounds (Electron text
    /// views such as Slack and Cursor). Vertically centers a zero-width caret
    /// inside the element and offsets X by the measured prefix text width.
    public static func fallbackCaret(
        elementFrame: CGRect,
        cursorTextWidth: CGFloat,
        lineHeight: CGFloat = 18,
        leftPadding: CGFloat = 12,
        rightInset: CGFloat = 8
    ) -> CGRect {
        let cursorX = min(
            elementFrame.maxX - rightInset,
            elementFrame.minX + leftPadding + cursorTextWidth
        )
        let cursorY = elementFrame.minY + max(0, (elementFrame.height - lineHeight) / 2)
        return CGRect(x: cursorX, y: cursorY, width: 0, height: lineHeight)
    }

    /// Frame for the suggestion overlay. Top-anchored to the caret so multi-line
    /// suggestions (when `suggestionSize.height` exceeds the caret height) expand
    /// downward with the first line aligned to the caret's baseline.
    public static func frame(
        caretRect: CGRect,
        suggestionSize: CGSize,
        visibleFrame: CGRect? = nil
    ) -> CGRect {
        let frameHeight = max(ceil(caretRect.height), ceil(suggestionSize.height))
        var frame = CGRect(
            x: caretRect.maxX,
            y: caretRect.maxY - frameHeight,
            width: ceil(suggestionSize.width) + 2,
            height: frameHeight
        )

        if let visible = visibleFrame {
            if frame.maxX > visible.maxX { frame.origin.x = visible.maxX - frame.width }
            if frame.minX < visible.minX { frame.origin.x = visible.minX }
            if frame.maxY > visible.maxY { frame.origin.y = visible.maxY - frame.height }
            if frame.minY < visible.minY { frame.origin.y = visible.minY }
        }

        return CGRect(
            x: frame.origin.x.rounded(.toNearestOrAwayFromZero),
            y: frame.origin.y.rounded(.toNearestOrAwayFromZero),
            width: frame.width.rounded(.up),
            height: frame.height.rounded(.up)
        )
    }
}
