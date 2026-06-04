import AppKit
import BrotypistCore
@preconcurrency import InputMethodKit
import OSLog

private let icLogger = Logger(subsystem: "com.ezraapple.brotypist.inputmethod", category: "controller")

final class InputController: IMKInputController {
    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        guard let client = sender as? IMKTextInput else { return }
        let appName = Self.frontmostAppName()
        icLogger.debug("activate app=\(appName, privacy: .public)")
        MainActor.assumeIsolated {
            SuggestionDriver.shared.activate(client: client, appName: appName)
        }
    }

    override func deactivateServer(_ sender: Any!) {
        icLogger.debug("deactivate")
        MainActor.assumeIsolated {
            SuggestionDriver.shared.deactivate()
        }
        super.deactivateServer(sender)
    }

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        guard let string, let client = sender as? IMKTextInput else { return false }
        let appName = Self.frontmostAppName()
        client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: 0))
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                SuggestionDriver.shared.refresh(client: client, appName: appName)
            }
        }
        return true
    }

    override func didCommand(by aSelector: Selector!, client sender: Any!) -> Bool {
        guard let client = sender as? IMKTextInput else { return false }
        switch aSelector {
        case #selector(NSResponder.insertTab(_:)),
             #selector(NSResponder.moveRight(_:)):
            let accepted = MainActor.assumeIsolated {
                SuggestionDriver.shared.tryAccept(client: client)
            }
            if accepted { return true }
        case #selector(NSResponder.cancelOperation(_:)):
            MainActor.assumeIsolated {
                SuggestionDriver.shared.dismiss()
            }
        case #selector(NSResponder.deleteBackward(_:)),
             #selector(NSResponder.deleteForward(_:)):
            let appName = Self.frontmostAppName()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    SuggestionDriver.shared.refresh(client: client, appName: appName)
                }
            }
        default:
            break
        }
        return false
    }

    private static func frontmostAppName() -> String {
        NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
    }
}
