import AppKit
import ApplicationServices
import BrotypistCore
import BrotypistRuntime
import Carbon.HIToolbox
import CoreText
import OSLog

private let appLogger = Logger(subsystem: "com.ezraapple.brotypist", category: "app")
private let suggestionLogger = Logger(subsystem: "com.ezraapple.brotypist", category: "suggestion")
private let focusLogger = Logger(subsystem: "com.ezraapple.brotypist", category: "focus")
private let completionDebounceNanoseconds: UInt64 = 220_000_000

@main
@MainActor
final class BrotypistApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var controller: SuggestionController?

    static func main() {
        let app = NSApplication.shared
        let delegate = BrotypistApp()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let modelURL = Self.defaultModelURL()
        appLogger.info("Launching Brotypist modelPath=\(modelURL.path, privacy: .public)")
        let engine = LlamaCompletionEngine(modelURL: modelURL)
        let controller = SuggestionController(engine: engine)
        self.controller = controller
        controller.start()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "text.cursor", accessibilityDescription: "Brotypist")
        item.button?.title = " Brotypist"
        item.menu = makeMenu(controller: controller)
        statusItem = item
        appLogger.info("Menu bar item installed")
    }

    private static func defaultModelURL() -> URL {
        let modelPath = "Models/Qwen3-0.6B-Q4_K_M.gguf"
        if let resourceURL = Bundle.main.resourceURL {
            let bundledModel = resourceURL.appendingPathComponent(modelPath)
            if FileManager.default.fileExists(atPath: bundledModel.path) {
                return bundledModel
            }
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(modelPath)
    }

    private func makeMenu(controller: SuggestionController) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Brotypist running", action: nil, keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            withTitle: "Open Accessibility Settings",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        ).target = self
        menu.addItem(
            withTitle: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        ).target = self
        return menu
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

@MainActor
private final class SuggestionController {
    private let engine: any TextCompletionEngine
    private let overlay = SuggestionOverlayWindow()
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var pollTimer: Timer?
    private var generationTask: Task<Void, Never>?
    private var focusedContext: FocusedTextContext?
    private var currentText = ""
    private var activeSession: SuggestionSession?
    private var lastRequestedText = ""
    private var isGenerating = false
    private var lastAccessibilityTrusted: Bool?
    private var lastEventTapAttempt: Date?
    private var lastOverlayDiagnosticKey: String?

    init(engine: any TextCompletionEngine) {
        self.engine = engine
    }

    func start() {
        requestAccessibilityIfNeeded()
        startEventTap()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.14, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshFocusedText()
            }
        }
        suggestionLogger.info("Suggestion controller started")
    }

    private func requestAccessibilityIfNeeded() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        lastAccessibilityTrusted = trusted
        appLogger.info("Accessibility trusted=\(trusted)")
    }

    private func startEventTap() {
        guard eventTap == nil else { return }
        let now = Date()
        if let lastEventTapAttempt, now.timeIntervalSince(lastEventTapAttempt) < 2 {
            return
        }
        lastEventTapAttempt = now

        let mask = 1 << CGEventType.keyDown.rawValue
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<SuggestionController>.fromOpaque(userInfo).takeUnretainedValue()
            return controller.handleEvent(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            appLogger.error("Failed to create event tap; Input Monitoring may be missing")
            return
        }

        eventTap = tap
        eventTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let eventTapSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            appLogger.info("Event tap installed")
        }
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        if keycode == kVK_Tab, acceptSuggestion() {
            suggestionLogger.info("Tab accepted suggestion")
            return nil
        }

        if keycode == kVK_Escape, activeSession != nil {
            suggestionLogger.info("Escape dismissed suggestion")
            clearSuggestion()
            return nil
        }

        if keycode == kVK_Delete {
            clearSuggestion()
        } else if event.unicodeString?.isEmpty == false {
            overlay.hide()
            generationTask?.cancel()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
                self?.refreshFocusedText()
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func refreshFocusedText() {
        let trusted = AXIsProcessTrusted()
        if lastAccessibilityTrusted != trusted {
            appLogger.info("Accessibility trusted=\(trusted)")
            lastAccessibilityTrusted = trusted
        }
        if eventTap == nil {
            startEventTap()
        }

        guard trusted else {
            overlay.hide()
            return
        }

        guard let context = FocusedTextReader.read() else {
            focusedContext = nil
            clearSuggestion()
            focusLogger.debug("No focused editable context")
            return
        }

        focusedContext = context
        guard let value = context.value else {
            overlay.hide()
            focusLogger.debug("Focused context has no readable value app=\(context.appName, privacy: .public)")
            return
        }

        guard context.caretRect != nil else {
            if value != currentText {
                currentText = value
                focusLogger.info("Focused text changed app=\(context.appName, privacy: .public) length=\(value.count) hasCaret=false")
            }
            clearSuggestion()
            return
        }

        if let activeSession {
            if let reconciled = activeSession.reconcile(currentText: value) {
                self.activeSession = reconciled
                showSuggestion(reconciled.suggestion)
            } else if value != currentText {
                clearSuggestion()
            }
        }

        guard value != currentText else {
            updateOverlayPosition()
            return
        }

        currentText = value
        focusLogger.info("Focused text changed app=\(context.appName, privacy: .public) length=\(value.count) hasCaret=\(context.caretRect != nil)")
        maybeGenerate(for: value, context: context)
    }

    private func maybeGenerate(for text: String, context: FocusedTextContext) {
        guard shouldTriggerCompletion(text) else {
            clearSuggestion()
            suggestionLogger.debug("Generation skipped by trigger rules length=\(text.count)")
            return
        }
        guard text != lastRequestedText else { return }

        generationTask?.cancel()
        generationTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: completionDebounceNanoseconds)
                try Task.checkCancellation()
            } catch {
                return
            }
            guard let self else { return }
            await MainActor.run {
                self.isGenerating = true
                self.lastRequestedText = text
                suggestionLogger.info("Generation started app=\(context.appName, privacy: .public) length=\(text.count)")
            }

            let request = SuggestionRequest(
                prefix: currentLine(from: text),
                appName: context.appName,
                windowTitle: nil,
                visualContext: nil,
                maxPredictionWords: 6
            )

            do {
                let suggestion = try await engine.complete(request: request)
                try Task.checkCancellation()
                await MainActor.run {
                    self.isGenerating = false
                    guard self.currentText == text else {
                        suggestionLogger.info("Generation discarded because text changed")
                        return
                    }
                    guard !suggestion.isEmpty else {
                        suggestionLogger.info("Generation returned empty suggestion")
                        return
                    }
                    self.activeSession = SuggestionSession(anchor: text, suggestion: suggestion)
                    suggestionLogger.info("Generation ready suggestionLength=\(suggestion.count)")
                    self.showSuggestion(suggestion)
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.isGenerating = false
                    suggestionLogger.debug("Generation cancelled")
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    self.overlay.hide()
                    suggestionLogger.error("Generation failed error=\(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func shouldTriggerCompletion(_ text: String) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if text.last?.isWhitespace == true { return true }

        var currentWordLength = 0
        for character in text.reversed() {
            if character.isWhitespace { break }
            currentWordLength += 1
        }
        return currentWordLength >= 2
    }

    private func currentLine(from text: String) -> String {
        text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).last.map(String.init) ?? text
    }

    private func acceptSuggestion() -> Bool {
        guard let activeSession else { return false }
        let acceptance = activeSession.acceptNextWord()
        guard !acceptance.accepted.isEmpty else { return false }

        if let context = focusedContext, FocusedTextWriter.insert(acceptance.accepted, into: context) {
            currentText += acceptance.accepted
            suggestionLogger.info("Accepted via AX insertion length=\(acceptance.accepted.count)")
        } else {
            KeyboardTyper.type(acceptance.accepted)
            currentText += acceptance.accepted
            suggestionLogger.info("Accepted via keyboard fallback length=\(acceptance.accepted.count)")
        }

        self.activeSession = acceptance.remaining
        if let remaining = acceptance.remaining {
            showSuggestion(remaining.suggestion)
        } else {
            overlay.hide()
        }
        return true
    }

    private func showSuggestion(_ suggestion: String) {
        guard let context = focusedContext, let caret = context.caret else {
            suggestionLogger.debug("Could not show suggestion because caret rect is missing")
            return
        }
        let caretRect = caret.screenRect
        suggestionLogger.debug("Showing suggestion length=\(suggestion.count)")
        let font = OverlayTypography.displayFont(reportedFont: context.font, caretHeight: caretRect.height)
        logOverlayGeometryIfNeeded(context: context, caret: caret, font: font, suggestionLength: suggestion.count)
        overlay.update(text: suggestion, font: font, caretRect: caretRect)
    }

    private func logOverlayGeometryIfNeeded(
        context: FocusedTextContext,
        caret: CaretGeometry,
        font: NSFont,
        suggestionLength: Int
    ) {
        guard context.appName == "TextEdit" else { return }

        let caretRect = caret.screenRect
        let lineHeight = font.ascender - font.descender + font.leading
        let key = [
            caretRect.origin.x.rounded(.toNearestOrAwayFromZero),
            caretRect.origin.y.rounded(.toNearestOrAwayFromZero),
            caretRect.height.rounded(.toNearestOrAwayFromZero),
            font.pointSize.rounded(.toNearestOrAwayFromZero),
            CGFloat(suggestionLength)
        ].map { String(Int($0)) }.joined(separator: ":")

        guard key != lastOverlayDiagnosticKey else { return }
        lastOverlayDiagnosticKey = key

        suggestionLogger.info(
            "Overlay geometry app=\(context.appName, privacy: .public) source=\(caret.source, privacy: .public) caretX=\(caretRect.origin.x) caretY=\(caretRect.origin.y) caretHeight=\(caretRect.height) rawY=\(caret.rawRect.origin.y) convertedY=\(caret.convertedRect.origin.y) font=\(font.fontName, privacy: .public) fontSize=\(font.pointSize) lineHeight=\(lineHeight) suggestionLength=\(suggestionLength)"
        )
    }

    private func updateOverlayPosition() {
        guard let suggestion = activeSession?.suggestion else { return }
        showSuggestion(suggestion)
    }

    private func clearSuggestion() {
        generationTask?.cancel()
        activeSession = nil
        lastRequestedText = ""
        isGenerating = false
        lastOverlayDiagnosticKey = nil
        overlay.hide()
    }
}

private struct FocusedTextContext {
    let element: AXUIElement
    let value: String?
    let selectedRange: CFRange?
    let caret: CaretGeometry?
    let font: NSFont?
    let appName: String

    var caretRect: CGRect? {
        caret?.screenRect
    }
}

private struct CaretGeometry {
    let rawRect: CGRect
    let convertedRect: CGRect
    let screenRect: CGRect
    let source: String
}

private enum FocusedTextReader {
    static func read() -> FocusedTextContext? {
        let systemWide = AXUIElementCreateSystemWide()
        guard let focused = copyElement(systemWide, attribute: kAXFocusedUIElementAttribute as CFString)
            ?? focusedElementFromApplication(systemWide) else {
            return nil
        }

        let element = resolveEditableElement(from: focused) ?? focused
        let value = readString(element, attribute: kAXValueAttribute as CFString)
        let range = readSelectedRange(element)
        let caret = range.flatMap { selection in
            Self.caretGeometry(for: element, range: selection)
        }
        let font = readFont(element: element, value: value, range: range)
        return FocusedTextContext(
            element: element,
            value: value,
            selectedRange: range,
            caret: caret,
            font: font,
            appName: NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        )
    }

    private static func focusedElementFromApplication(_ systemWide: AXUIElement) -> AXUIElement? {
        guard let app = copyElement(systemWide, attribute: kAXFocusedApplicationAttribute as CFString) else {
            return nil
        }
        return copyElement(app, attribute: kAXFocusedUIElementAttribute as CFString)
    }

    private static func resolveEditableElement(from root: AXUIElement) -> AXUIElement? {
        if isEditable(root) { return root }
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var index = 0
        while index < queue.count, index < 300 {
            let (element, depth) = queue[index]
            index += 1
            if isEditable(element) { return element }
            guard depth < 5 else { continue }
            for child in children(of: element) {
                queue.append((child, depth + 1))
            }
        }
        return nil
    }

    private static func isEditable(_ element: AXUIElement) -> Bool {
        let role = readString(element, attribute: kAXRoleAttribute as CFString)
        if role == "AXSecureTextField" { return false }
        let editable = readBool(element, attribute: "AXEditable" as CFString) ?? false
        let textRoles: Set<String> = [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            "AXSearchField",
            "AXComboBox",
            "AXWebArea"
        ]
        return editable || role.map { textRoles.contains($0) } == true
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let value else {
            return []
        }
        if CFGetTypeID(value) == AXUIElementGetTypeID() {
            return [unsafeBitCast(value, to: AXUIElement.self)]
        }
        guard CFGetTypeID(value) == CFArrayGetTypeID() else { return [] }
        let array = value as! CFArray
        return (0 ..< CFArrayGetCount(array)).compactMap { index in
            let raw = CFArrayGetValueAtIndex(array, index)
            let ref = unsafeBitCast(raw, to: CFTypeRef.self)
            guard CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
            return unsafeBitCast(ref, to: AXUIElement.self)
        }
    }

    private static func copyElement(_ element: AXUIElement, attribute: CFString) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private static func readString(_ element: AXUIElement, attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value else {
            return nil
        }
        if let string = value as? String { return string }
        if let attributed = value as? NSAttributedString { return attributed.string }
        return nil
    }

    private static func readBool(_ element: AXUIElement, attribute: CFString) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let number = value as? NSNumber else {
            return nil
        }
        return number.boolValue
    }

    private static func readSelectedRange(_ element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
        return range
    }

    private static func caretGeometry(for element: AXUIElement, range: CFRange) -> CaretGeometry? {
        var caretRange = CFRange(location: range.location, length: 0)
        if let rect = bounds(for: element, range: caretRange), rect.height > 2 {
            return geometry(from: rect)
        }
        if range.location > 0 {
            caretRange = CFRange(location: range.location - 1, length: 1)
            if let rect = bounds(for: element, range: caretRange), rect.height > 2 {
                return geometry(from: CGRect(x: rect.maxX, y: rect.minY, width: 0, height: rect.height))
            }
        }
        return nil
    }

    private static func geometry(from rawRect: CGRect) -> CaretGeometry {
        let convertedRect = convertQuartzToAppKit(rawRect)
        let rawScreen = screen(containing: rawRect)
        let convertedScreen = screen(containing: convertedRect)

        if rawScreen != nil {
            return CaretGeometry(rawRect: rawRect, convertedRect: convertedRect, screenRect: rawRect, source: "raw")
        }
        if convertedScreen != nil {
            return CaretGeometry(rawRect: rawRect, convertedRect: convertedRect, screenRect: convertedRect, source: "converted")
        }
        return CaretGeometry(rawRect: rawRect, convertedRect: convertedRect, screenRect: rawRect, source: "raw-offscreen")
    }

    private static func bounds(for element: AXUIElement, range: CFRange) -> CGRect? {
        var mutableRange = range
        guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &value
        ) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        var rect = CGRect.zero
        guard AXValueGetValue(value as! AXValue, .cgRect, &rect) else { return nil }
        return rect
    }

    private static func readFont(element: AXUIElement, value: String?, range: CFRange?) -> NSFont? {
        guard let value, var range else { return nil }
        if range.length == 0 {
            let length = (value as NSString).length
            guard length > 0 else { return nil }
            range = CFRange(location: min(max(0, range.location), length - 1), length: 1)
        }
        guard let rangeValue = AXValueCreate(.cfRange, &range) else { return nil }
        var attributed: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXAttributedStringForRangeParameterizedAttribute as CFString,
            rangeValue,
            &attributed
        ) == .success,
              let attributedString = attributed as? NSAttributedString,
              attributedString.length > 0 else {
            return nil
        }
        let fontAttribute = attributedString.attribute(.font, at: 0, effectiveRange: nil)
        if let font = fontAttribute as? NSFont {
            return font
        }
        if let fontAttribute {
            let cfFont = fontAttribute as CFTypeRef
            guard CFGetTypeID(cfFont) == CTFontGetTypeID() else { return nil }
            let ctFont = unsafeBitCast(cfFont, to: CTFont.self)
            let name = CTFontCopyPostScriptName(ctFont) as String
            return NSFont(name: name, size: CTFontGetSize(ctFont))
        }
        return nil
    }

    private static func convertQuartzToAppKit(_ rect: CGRect) -> CGRect {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for screen in NSScreen.screens {
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                continue
            }
            let displayBounds = CGDisplayBounds(displayID)
            if displayBounds.contains(center) {
                return CGRect(
                    x: rect.origin.x - displayBounds.origin.x + screen.frame.origin.x,
                    y: (displayBounds.origin.y + displayBounds.height) - (rect.origin.y + rect.height) + screen.frame.origin.y,
                    width: rect.width,
                    height: rect.height
                )
            }
        }
        return rect
    }

    private static func screen(containing rect: CGRect) -> NSScreen? {
        let candidates = [
            CGPoint(x: rect.midX, y: rect.midY),
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ]
        return NSScreen.screens.first { screen in
            candidates.contains { screen.frame.insetBy(dx: -4, dy: -4).contains($0) }
        }
    }
}

private enum FocusedTextWriter {
    static func insert(_ text: String, into context: FocusedTextContext) -> Bool {
        AXUIElementSetAttributeValue(context.element, kAXSelectedTextAttribute as CFString, text as CFString) == .success
    }
}

private final class SuggestionOverlayWindow: NSPanel {
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

        let metrics = OverlayTypography.metrics(for: font, caretHeight: caretRect.height)
        let size = (text as NSString).size(withAttributes: [.font: font])
        let height = ceil(max(caretRect.height, metrics.lineHeight, size.height))
        var frame = CGRect(
            x: caretRect.maxX,
            y: caretRect.minY + ((caretRect.height - height) / 2),
            width: ceil(size.width) + 2,
            height: height
        )

        if let visible = NSScreen.screens.first(where: { $0.frame.contains(caretRect.center) })?.visibleFrame ?? NSScreen.main?.visibleFrame {
            if frame.maxX > visible.maxX { frame.origin.x = visible.maxX - frame.width }
            if frame.minX < visible.minX { frame.origin.x = visible.minX }
            if frame.maxY > visible.maxY { frame.origin.y = visible.maxY - frame.height }
            if frame.minY < visible.minY { frame.origin.y = visible.minY }
        }
        frame = frame.roundedForStableOverlay()

        let sameText = textView.text == text
        let sameFont = textView.font.fontName == font.fontName && abs(textView.font.pointSize - font.pointSize) < 0.1
        if isVisible, sameText, sameFont, self.frame.integral == frame.integral {
            return
        }

        textView.update(text: text, font: font, baselineOffset: metrics.baselineOffset)
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
    private var baselineOffset: CGFloat = 0

    override var isFlipped: Bool { true }

    func update(text: String, font: NSFont, baselineOffset: CGFloat) {
        self.text = text
        self.font = font
        self.baselineOffset = baselineOffset
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !text.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let y = max(0, floor((bounds.height - OverlayTypography.metrics(for: font, caretHeight: bounds.height).lineHeight) / 2 + baselineOffset))
        (text as NSString).draw(at: CGPoint(x: 0, y: y), withAttributes: attributes)
    }
}

private enum OverlayTypography {
    struct Metrics {
        let lineHeight: CGFloat
        let baselineOffset: CGFloat
    }

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

    static func metrics(for font: NSFont, caretHeight: CGFloat) -> Metrics {
        let lineHeight = ceil(max(1, font.ascender - font.descender + font.leading))
        let extraCaretSpace = max(0, caretHeight - lineHeight)
        return Metrics(lineHeight: lineHeight, baselineOffset: floor(extraCaretSpace / 2))
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    func roundedForStableOverlay() -> CGRect {
        CGRect(
            x: origin.x.rounded(.toNearestOrAwayFromZero),
            y: origin.y.rounded(.toNearestOrAwayFromZero),
            width: width.rounded(.up),
            height: height.rounded(.up)
        )
    }
}

private enum KeyboardTyper {
    static func type(_ text: String) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        for scalar in text.unicodeScalars {
            var value = UniChar(scalar.value)
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            down?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &value)
            down?.post(tap: .cghidEventTap)

            let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            up?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &value)
            up?.post(tap: .cghidEventTap)
        }
    }
}

private extension CGEvent {
    var unicodeString: String? {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 16)
        keyboardGetUnicodeString(maxStringLength: 16, actualStringLength: &length, unicodeString: &buffer)
        guard length > 0 else { return nil }
        return String(utf16CodeUnits: buffer, count: length)
    }
}
