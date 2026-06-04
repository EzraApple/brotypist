import AppKit
import BrotypistInputMethodSupport
import Foundation
import InputMethodKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var server: IMKServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let bundle = Bundle.main
        let connectionName = (bundle.infoDictionary?["InputMethodConnectionName"] as? String)
            ?? "BrotypistInputMethod_Connection"
        let bundleId = bundle.bundleIdentifier ?? "com.ezraapple.brotypist.inputmethod"

        InputMethodRuntime.logger.info(
            "Brotypist IM starting connection=\(connectionName, privacy: .public) bundle=\(bundleId, privacy: .public)"
        )

        server = IMKServer(name: connectionName, bundleIdentifier: bundleId)
        MainActor.assumeIsolated {
            InputMethodRuntime.configureSuggestionDriver()
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
