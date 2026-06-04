# Brotypist

Brotypist is a macOS-local autocomplete that ships as a system **Input Method (IMK)**. When enabled, it sees every keystroke before the focused text field does, asks a local GGUF model for a short continuation, draws ghost text next to your caret, and inserts the suggestion when you press Tab or Right Arrow. Because IMK is the same channel non-Latin IMEs use, it works in every text field that supports IME — including Electron apps like Slack, Cursor, Discord, and VS Code — using the **same** caret position and insertion path those apps already wire up for IMEs. No Accessibility permission, no Input Monitoring, no clipboard tricks.

A legacy menu-bar build (`Brotypist.app`) is also retained for reference but is being phased out.

## MVP Plan

- [x] macOS app shell with a lightweight menu bar presence.
- [x] Global key handling for accepting or dismissing a completion.
- [x] Local model loading from `Models/qwen3-0.6b-base-q4_k_m.gguf`.
- [x] Prompt builder tuned for short, low-latency autocomplete suggestions.
- [x] Suggestion UI that can be accepted, dismissed, or ignored quickly.
- [ ] Basic settings for enabling the app, model path, and completion length.
- [ ] Privacy-first defaults: local inference, no telemetry, no remote prompt upload.
- [ ] Signed release build and a simple download page.

## Progress

- [x] Repository docs scaffolded.
- [x] Model download helper added.
- [x] macOS CI workflow added.
- [x] Swift package and app implementation.
- [x] Model runtime integration.
- [x] CLI model smoke test.
- [x] Basic focused-field autocomplete flow.
- [x] Stable local dev signing identity for repeatable macOS permission testing.
- [ ] Manual compatibility pass across Safari, Notes, Mail, Slack, and TextEdit.
- [ ] Runtime latency tuning and KV-cache reuse.

## First-Time Setup

Fresh clone path:

```sh
# 1. Fetch the local model (~400 MB) into Models/.
./scripts/download-model.sh

# 2. Create the stable local code signing identity (one time per machine).
./scripts/create-dev-codesign-cert.sh

# 3. Optional but recommended: stop codesign from prompting for the keychain
#    password on every rebuild. Run from an interactive terminal.
./scripts/allow-dev-codesign-key.sh

# 4. Build the Input Method bundle under dist/.
./scripts/build-dev-im.sh

# 5. Optional experimental registration:
# INSTALL_INPUT_METHOD=1 ./scripts/build-dev-im.sh
```

The IMK registration path is still under investigation. The default build does not install into `~/Library/Input Methods` or open System Settings.

## Daily Dev Loop

Iterate cycle for a rebuild:

```sh
# Rebuild the IMK input method bundle under dist/.
./scripts/build-dev-im.sh
```

The `Brotypist Local Development` identity keeps the bundle's code identity stable across rebuilds. If the input source registry gets stuck while testing explicit installation, remove the installed copy and restart the text-input agents:

```sh
./scripts/uninstall-dev-im.sh
killall TextInputMenuAgent TextInputSwitcher imklaunchagent 2>/dev/null
```

For logic-only iteration that skips the input method bundle:

```sh
swift run brotypistctl --stub Can you send   # cheap, no model load
swift run brotypistctl Can you send          # real local-model completion
swift test                                   # unit tests
```

`swift run brotypist` launches the deprecated Accessibility-driven menu bar app. Use `./scripts/build-dev-im.sh` when testing the current Input Method path.

## Dev Commands

```sh
# Download the default local model into Models/
./scripts/download-model.sh

# Build the Swift package
swift build

# Run tests
swift test

# Run a cheap CLI smoke test without loading a model
swift run brotypistctl --stub Can you send

# Run a real local-model completion
swift run brotypistctl Can you send

# Launch the legacy menu bar app from source (deprecated, AX-driven)
swift run brotypist

# Create a stable local signing identity for dev builds
./scripts/create-dev-codesign-cert.sh

# Stop repeated keychain prompts when signing dev builds
./scripts/allow-dev-codesign-key.sh

# Build the IMK bundle under dist/ without installing it
./scripts/build-dev-im.sh

# Experimental: install the IMK bundle to ~/Library/Input Methods/
INSTALL_INPUT_METHOD=1 ./scripts/build-dev-im.sh

# Remove the installed IMK bundle
./scripts/uninstall-dev-im.sh

# Build the legacy menu-bar dev bundle (deprecated)
./scripts/build-dev-app.sh
```

## Enabling the Input Method

The IMK registration flow is currently experimental. `./scripts/build-dev-im.sh` only builds `dist/BrotypistInputMethod.app` by default; it does not install into `~/Library/Input Methods`.

To test registration explicitly:

```sh
INSTALL_INPUT_METHOD=1 ./scripts/build-dev-im.sh
```

If registration succeeds:

1. Open **System Settings → Keyboard → Input Sources → "+"**.
2. Pick **English** in the left list, then **BrotypistInputMethod** on the right, and click **Add**.
3. From the input-source menu in your menu bar (top right), switch to **BrotypistInputMethod**.
4. Start typing in any app — TextEdit, Slack, Cursor, Notes, Mail, Safari, etc.

Press **Tab** or **Right Arrow** to accept the next word. Press **Escape** to dismiss.

To turn brotypist off, switch back to a different input source (e.g. **U.S.**) from the same menu.

### Resetting

If the input source acts up after a rebuild:

```sh
./scripts/uninstall-dev-im.sh
killall TextInputMenuAgent TextInputSwitcher imklaunchagent 2>/dev/null
```

If System Settings hangs while opening the input-source picker, remove the installed bundle with `./scripts/uninstall-dev-im.sh`, quit System Settings, and restart the text-input agents with the `killall` command above. Do not rely on rebooting as the normal dev loop.

## Model Setup

Brotypist expects the default model at:

```text
Models/qwen3-0.6b-base-q4_k_m.gguf
```

This is the **base** (non-instruct) Qwen3-0.6B at Q4_K_M. The base model is used because a system-wide autocomplete is pure next-token continuation — the instruct variant treats the prefix as a dialogue turn and produces conversational replies instead of completions.

Download it with:

```sh
./scripts/download-model.sh
```

The script creates `Models/`, skips the download when the file already exists, and fails if the resulting file is empty. If you previously downloaded the old instruct model, delete `Models/Qwen3-0.6B-Q4_K_M.gguf` before re-running.

## App Usage

The current MVP flow (IMK):

1. Build the IM bundle with `./scripts/build-dev-im.sh`.
2. Install and enable **BrotypistInputMethod** only while testing the experimental registration path (see [Enabling the Input Method](#enabling-the-input-method)).
3. Switch to it from the input-source menu in your menu bar.
4. Type in any supported text field. Brotypist generates after a short debounce once there is enough text.
5. Gray ghost text appears next to the caret — using the same caret position the focused app would use for IME composition.
6. Press `Tab` or `Right Arrow` to accept the next word. Press `Esc` to dismiss.

The first implementation is intentionally small: no OCR, no settings pane, no polished installer, and no prompt personalization yet.

See [First-Time Setup](#first-time-setup) for the build sequence and [Troubleshooting](#troubleshooting) if signing misbehaves.

## Troubleshooting

**`codesign` keeps prompting for the keychain password.** Run `./scripts/allow-dev-codesign-key.sh` once from an interactive terminal. It adds `/usr/bin/codesign` to the key's partition list so future signing is silent.

**`BrotypistInputMethod` does not appear under Keyboard → Input Sources.** The registration path is still experimental. First remove the installed bundle and restart the text-input agents:

```sh
./scripts/uninstall-dev-im.sh
killall TextInputMenuAgent TextInputSwitcher imklaunchagent 2>/dev/null
```

Then rebuild without installing via `./scripts/build-dev-im.sh` until the bundle metadata/signing issue is fixed.

**`build-dev-im.sh` reports the model is missing.** The script can still build the input method, but completions will fail until the model exists. Run `./scripts/download-model.sh`, then rebuild.

**`codesign --verify` fails after a rebuild.** Usually the dev identity is missing — run `./scripts/create-dev-codesign-cert.sh`. The build script falls back to ad-hoc signing (`-`) when the identity is absent.

**Want a one-off ad-hoc build (no cert).** `CODESIGN_IDENTITY=- ./scripts/build-dev-im.sh`. Useful only for throwaway bundle-shape tests; do not install ad-hoc builds into Input Methods.

**Want to watch what the app is doing.** Tail the unified log:

```sh
log stream --predicate 'process == "BrotypistInputMethod"' --level debug
```

## Next Planned Steps

- Add a tiny settings window for enable/disable, model path, max words, and launch-at-login.
- Tune prompt and sampling against real typing examples.
- Add prompt KV reuse so repeated requests do not rebuild context every time.
- Add app/domain disable lists.
- Add optional visual/OCR context after the basic flow feels reliable.
- Package a signed app and generate a public download page.

## Download Page Notes

The eventual public download page should include:

- A direct signed `.dmg` or `.zip` download.
- Minimum supported macOS version.
- A short privacy statement explaining that completions run locally.
- Model size and first-run setup expectations.
- Checksums for release assets.
- A brief note that the app is installed as a macOS Input Method.
