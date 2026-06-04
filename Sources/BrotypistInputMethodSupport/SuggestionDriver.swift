import AppKit
import BrotypistCore
import BrotypistRuntime
import Foundation
import InputMethodKit
import OSLog

private let driverLogger = Logger(subsystem: "com.ezraapple.brotypist.inputmethod", category: "driver")
private let completionDebounceNanoseconds: UInt64 = 220_000_000

@MainActor
final class SuggestionDriver {
    static let shared = SuggestionDriver()

    private var engine: (any TextCompletionEngine)?
    private let overlay = SuggestionOverlayWindow()
    private var generationTask: Task<Void, Never>?
    private var currentText = ""
    private var activeSession: SuggestionSession?
    private var lastRequestedText = ""
    private var isGenerating = false

    private weak var currentClient: AnyObject?
    private var currentAppName = "Unknown"

    private init() {}

    func configure(engine: any TextCompletionEngine) {
        self.engine = engine
    }

    func activate(client: IMKTextInput, appName: String) {
        currentClient = client as? AnyObject
        currentAppName = appName
        currentText = readClientText(client)
        clearSuggestion()
        driverLogger.debug("activate app=\(appName, privacy: .public) length=\(self.currentText.count)")
        WelcomeWindow.shared.showIfFirstActivation()
    }

    func deactivate() {
        currentClient = nil
        clearSuggestion()
    }

    func refresh(client: IMKTextInput, appName: String) {
        currentClient = client as? AnyObject
        currentAppName = appName

        if AppPolicy.isDenied(appName: appName) {
            clearSuggestion()
            return
        }

        let value = readClientText(client)
        let caretRect = readCaretRect(client)

        if let session = activeSession {
            if let reconciled = session.reconcile(currentText: value) {
                activeSession = reconciled
                showSuggestion(reconciled.suggestion, caretRect: caretRect)
            } else if value != currentText {
                clearSuggestion()
            }
        }

        guard value != currentText else {
            if let session = activeSession {
                showSuggestion(session.suggestion, caretRect: caretRect)
            }
            return
        }

        currentText = value
        maybeGenerate(for: value)
    }

    func tryAccept(client: IMKTextInput) -> Bool {
        guard let session = activeSession else {
            driverLogger.debug("accept skipped: no session")
            return false
        }
        let acceptance = session.acceptNextWord()
        guard !acceptance.accepted.isEmpty else {
            driverLogger.debug("accept skipped: empty acceptance")
            return false
        }

        client.insertText(acceptance.accepted, replacementRange: NSRange(location: NSNotFound, length: 0))
        currentText += acceptance.accepted
        driverLogger.info("accepted length=\(acceptance.accepted.count) app=\(self.currentAppName, privacy: .public)")

        activeSession = acceptance.remaining
        if let remaining = acceptance.remaining {
            let caretRect = readCaretRect(client)
            showSuggestion(remaining.suggestion, caretRect: caretRect)
        } else {
            overlay.hide()
        }
        return true
    }

    func dismiss() {
        if activeSession != nil {
            clearSuggestion()
            driverLogger.debug("dismissed by escape")
        }
    }

    // MARK: - Internal

    private func maybeGenerate(for text: String) {
        guard let engine else { return }
        guard TriggerRules.shouldTrigger(text) else {
            clearSuggestion()
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
            }

            let request = SuggestionRequest(
                prefix: TriggerRules.currentLine(from: text),
                appName: self.currentAppName,
                maxPredictionWords: 12
            )

            do {
                let suggestion = try await engine.complete(request: request)
                try Task.checkCancellation()
                await MainActor.run {
                    self.isGenerating = false
                    guard self.currentText == text else {
                        driverLogger.debug("generation discarded: text changed")
                        return
                    }
                    guard !suggestion.isEmpty else { return }
                    self.activeSession = SuggestionSession(anchor: text, suggestion: suggestion)
                    if let client = self.currentClient as? IMKTextInput {
                        let caretRect = self.readCaretRect(client)
                        self.showSuggestion(suggestion, caretRect: caretRect)
                    }
                }
            } catch is CancellationError {
                await MainActor.run { self.isGenerating = false }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    self.overlay.hide()
                    driverLogger.error("generation failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func showSuggestion(_ suggestion: String, caretRect: CGRect) {
        guard !suggestion.isEmpty else {
            overlay.hide()
            return
        }
        guard caretRect.width >= 0, caretRect.height > 2 else {
            // Caret rect not yet available — wait for next refresh tick.
            return
        }
        let font = OverlayTypography.displayFont(reportedFont: hintedFont(), caretHeight: caretRect.height)
        overlay.update(text: suggestion, font: font, caretRect: caretRect)
    }

    private func clearSuggestion() {
        generationTask?.cancel()
        activeSession = nil
        lastRequestedText = ""
        isGenerating = false
        overlay.hide()
    }

    private func hintedFont() -> NSFont? {
        guard let spec = AppFontHints.hint(for: currentAppName) else { return nil }
        return NSFont(name: spec.name, size: spec.pointSize)
            ?? NSFont.systemFont(ofSize: spec.pointSize)
    }

    // MARK: - Client reads

    private func readClientText(_ client: IMKTextInput) -> String {
        let length = client.length()
        guard length > 0 else { return "" }
        let attributed = client.attributedSubstring(from: NSRange(location: 0, length: length))
        return attributed?.string ?? ""
    }

    private func readCaretRect(_ client: IMKTextInput) -> CGRect {
        let selectedRange = client.selectedRange()
        var actualRange = NSRange(location: NSNotFound, length: 0)
        let rect = client.firstRect(
            forCharacterRange: NSRange(location: selectedRange.location, length: 0),
            actualRange: &actualRange
        )
        return rect
    }
}
