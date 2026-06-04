import AppKit
import BrotypistCore
import BrotypistRuntime
import Carbon.HIToolbox
import CoreGraphics
import Foundation

let allArgs = Array(CommandLine.arguments.dropFirst())

switch allArgs.first {
case "overlay-frame":
    runOverlayFrame(args: Array(allArgs.dropFirst()))
case "quartz-to-appkit":
    runQuartzToAppKit(args: Array(allArgs.dropFirst()))
case "fallback-caret":
    runFallbackCaret(args: Array(allArgs.dropFirst()))
case "trigger":
    runTrigger(args: Array(allArgs.dropFirst()))
case "current-line":
    runCurrentLine(args: Array(allArgs.dropFirst()))
case "app-policy":
    runAppPolicy(args: Array(allArgs.dropFirst()))
case "normalize":
    runNormalize(args: Array(allArgs.dropFirst()))
case "install-input-source":
    runInstallInputSource(args: Array(allArgs.dropFirst()))
case "complete":
    try await runComplete(args: Array(allArgs.dropFirst()))
default:
    try await runComplete(args: allArgs)
}

func runComplete(args: [String]) async throws {
    let useStub = args.contains("--stub")
    let prefixParts = args.filter { $0 != "--stub" && $0 != "--model" }
    let prefix = prefixParts.isEmpty ? "Can you send" : prefixParts.joined(separator: " ")
    let request = SuggestionRequest(prefix: prefix, appName: "brotypistctl", maxPredictionWords: 6)

    let engine: any TextCompletionEngine
    let llamaEngine: LlamaCompletionEngine?
    if useStub {
        engine = StaticCompletionEngine()
        llamaEngine = nil
    } else {
        let modelURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Models/qwen3-0.6b-base-q4_k_m.gguf")
        let runtime = LlamaCompletionEngine(modelURL: modelURL)
        engine = runtime
        llamaEngine = runtime
    }

    let suggestion = try await engine.complete(request: request)
    await llamaEngine?.shutdown()
    print(suggestion)
}

func runOverlayFrame(args: [String]) {
    guard let caret = rectFlag("--caret", args: args) else {
        fail("overlay-frame requires --caret X,Y,W,H")
    }
    guard let suggestionWidth = doubleFlag("--text-width", args: args) else {
        fail("overlay-frame requires --text-width N")
    }
    let suggestionHeight = doubleFlag("--text-height", args: args) ?? Double(caret.height)
    let visible = rectFlag("--visible", args: args)

    let frame = OverlayLayout.frame(
        caretRect: caret,
        suggestionSize: CGSize(width: suggestionWidth, height: suggestionHeight),
        visibleFrame: visible
    )
    print("\(frame.origin.x),\(frame.origin.y),\(frame.size.width),\(frame.size.height)")
}

func runFallbackCaret(args: [String]) {
    guard let frame = rectFlag("--frame", args: args) else {
        fail("fallback-caret requires --frame X,Y,W,H")
    }
    let width = doubleFlag("--text-width", args: args) ?? 0
    let caret = OverlayLayout.fallbackCaret(elementFrame: frame, cursorTextWidth: width)
    print("\(caret.origin.x),\(caret.origin.y),\(caret.size.width),\(caret.size.height)")
}

func runQuartzToAppKit(args: [String]) {
    guard let rect = rectFlag("--rect", args: args) else {
        fail("quartz-to-appkit requires --rect X,Y,W,H")
    }
    guard let screensRaw = stringFlag("--screens", args: args) else {
        fail("quartz-to-appkit requires --screens 'qx,qy,qw,qh:ax,ay,aw,ah[;...]'")
    }
    let screens = screensRaw.split(separator: ";").compactMap { spec -> ScreenSpace? in
        let parts = spec.split(separator: ":")
        guard parts.count == 2,
              let quartz = parseRect(String(parts[0])),
              let appkit = parseRect(String(parts[1])) else {
            return nil
        }
        return ScreenSpace(displayBoundsInQuartz: quartz, appKitFrame: appkit)
    }
    let converted = CoordinateSpace.quartzToAppKit(rect, screens: screens)
    print("\(converted.origin.x),\(converted.origin.y),\(converted.size.width),\(converted.size.height)")
}

func runTrigger(args: [String]) {
    guard let text = args.first else {
        fail("trigger requires a text argument")
    }
    print(TriggerRules.shouldTrigger(text) ? "true" : "false")
}

func runCurrentLine(args: [String]) {
    guard let text = args.first else {
        fail("current-line requires a text argument")
    }
    print(TriggerRules.currentLine(from: text))
}

func runAppPolicy(args: [String]) {
    guard let appName = args.first else {
        fail("app-policy requires an app name argument")
    }
    print(AppPolicy.isDenied(appName: appName) ? "denied" : "allowed")
}

func runNormalize(args: [String]) {
    guard let raw = args.first else {
        fail("normalize requires a raw suggestion as the first argument")
    }
    let input = stringFlag("--input", args: args) ?? ""
    let maxWords = intFlag("--max-words", args: args) ?? 6
    let output = SuggestionTextNormalizer.normalize(raw, input: input, maxWords: maxWords)
    print(output)
}

func intFlag(_ name: String, args: [String]) -> Int? {
    stringFlag(name, args: args).flatMap(Int.init)
}

func runInstallInputSource(args: [String]) {
    let bundleID = stringFlag("--bundle-id", args: args) ?? "com.ezraapple.inputmethod.Brotypist"
    let modeID = stringFlag("--mode-id", args: args) ?? "com.ezraapple.inputmethod.Brotypist.Roman"
    let bundlePath = stringFlag("--bundle-path", args: args)
        ?? "\(NSHomeDirectory())/Library/Input Methods/BrotypistInputMethod.app"
    let timeout = doubleFlag("--timeout", args: args) ?? 3.0
    let shouldSelect = !args.contains("--no-select")
    let openSettingsOnFailure = args.contains("--open-settings") && !args.contains("--no-open-settings")

    let bundleURL = URL(fileURLWithPath: bundlePath)
    guard FileManager.default.fileExists(atPath: bundlePath) else {
        fail("bundle not found at \(bundlePath) — run scripts/build-dev-im.sh first")
    }

    var source = findInputSource(bundleID: bundleID, modeID: modeID)
    if source == nil {
        // Hint to the registry that there's a new bundle here. This can also
        // churn TIS' cache, so avoid calling it once the source is already
        // visible after the PlugInKit scan.
        let registerURLs = inputSourceBundleURLs(root: bundleURL)
        for registerURL in registerURLs {
            let registerStatus = TISRegisterInputSource(registerURL as CFURL)
            if registerStatus != noErr && registerStatus != paramErr {
                print("warn: TISRegisterInputSource \(registerURL.path) status=\(registerStatus)")
            }
        }

        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            source = findInputSource(bundleID: bundleID, modeID: modeID)
            if source != nil { break }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
    }

    guard let source else {
        print("Brotypist is not visible to the TIS input-source list yet.")
        print("The dev install now registers the PlugInKit extension and restarts the text-input agents.")
        print("If it still does not appear, open System Settings from the normal UI and check Keyboard → Input Sources → '+'.")
        if openSettingsOnFailure {
            if let settingsURL = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?InputSources") {
                NSWorkspace.shared.open(settingsURL)
                print("Opened System Settings to the Input Sources pane.")
            }
        }
        exit(2)
    }

    let enableStatus = TISEnableInputSource(source)
    if enableStatus != noErr {
        fail("TISEnableInputSource failed: status=\(enableStatus)")
    }
    print("enabled \(modeID)")

    if shouldSelect {
        let selectStatus = TISSelectInputSource(source)
        if selectStatus != noErr {
            fail("TISSelectInputSource failed: status=\(selectStatus)")
        }
        print("selected \(modeID)")
    }
}

func findInputSource(bundleID: String, modeID: String) -> TISInputSource? {
    guard let unmanaged = TISCreateInputSourceList(nil, true) else { return nil }
    let cfList = unmanaged.takeRetainedValue()
    let count = CFArrayGetCount(cfList)
    var bundleFallback: TISInputSource?
    for index in 0 ..< count {
        guard let raw = CFArrayGetValueAtIndex(cfList, index) else { continue }
        let source = Unmanaged<TISInputSource>.fromOpaque(raw).takeUnretainedValue()
        guard let rawProp = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { continue }
        let returned = Unmanaged<CFString>.fromOpaque(rawProp).takeUnretainedValue() as String
        if returned == modeID {
            return source
        }
        if returned == bundleID {
            bundleFallback = source
        }
    }
    return bundleFallback
}

func inputSourceBundleURLs(root: URL) -> [URL] {
    let plugInsURL = root.appendingPathComponent("Contents/PlugIns", isDirectory: true)
    let appexURLs = (try? FileManager.default.contentsOfDirectory(
        at: plugInsURL,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ))?
        .filter { $0.pathExtension == "appex" }
        ?? []
    return [root] + appexURLs
}

func stringFlag(_ name: String, args: [String]) -> String? {
    guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
    return args[index + 1]
}

func doubleFlag(_ name: String, args: [String]) -> Double? {
    stringFlag(name, args: args).flatMap(Double.init)
}

func rectFlag(_ name: String, args: [String]) -> CGRect? {
    stringFlag(name, args: args).flatMap(parseRect)
}

func parseRect(_ raw: String) -> CGRect? {
    let parts = raw.split(separator: ",").compactMap { Double($0) }
    guard parts.count == 4 else { return nil }
    return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(64)
}
