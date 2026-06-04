import AppKit
import Foundation

@MainActor
final class WelcomeWindow {
    static let shared = WelcomeWindow()

    private let defaultsKey = "com.ezraapple.brotypist.inputmethod.welcomeShown"
    private var window: NSWindow?

    func showIfFirstActivation() {
        guard !UserDefaults.standard.bool(forKey: defaultsKey) else { return }
        guard window == nil else { return }
        present()
    }

    private func present() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Brotypist"
        window.center()
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .ignoresCycle]

        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]

        let title = NSTextField(labelWithString: "You're using Brotypist.")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.frame = NSRect(x: 24, y: 200, width: 412, height: 24)
        container.addSubview(title)

        let body = NSTextField(wrappingLabelWithString:
            "Type as normal — gray ghost text will suggest the next few words.\n\n" +
            "Press Tab or Right Arrow to accept the next word. Press Escape to dismiss.\n\n" +
            "To turn Brotypist off, switch back to another input source from the menu bar (top right)."
        )
        body.font = .systemFont(ofSize: 13)
        body.textColor = .secondaryLabelColor
        body.frame = NSRect(x: 24, y: 64, width: 412, height: 130)
        container.addSubview(body)

        let gotIt = NSButton(title: "Got it", target: self, action: #selector(handleGotIt(_:)))
        gotIt.bezelStyle = .rounded
        gotIt.keyEquivalent = "\r"
        gotIt.frame = NSRect(x: 360, y: 20, width: 80, height: 28)
        gotIt.autoresizingMask = [.minXMargin]
        container.addSubview(gotIt)

        window.contentView = container
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    @objc private func handleGotIt(_ sender: Any?) {
        UserDefaults.standard.set(true, forKey: defaultsKey)
        window?.close()
        window = nil
    }
}
