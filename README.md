# Brotypist

Brotypist is a macOS-local autocomplete app in MVP development. It runs as a menu bar app, watches the focused text field through macOS Accessibility, asks a local GGUF model for short completions, and lets the user accept suggestions without sending typing context to a remote service.

## MVP Plan

- [x] macOS app shell with a lightweight menu bar presence.
- [x] Global key handling for accepting or dismissing a completion.
- [x] Local model loading from `Models/Qwen3-0.6B-Q4_K_M.gguf`.
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
- [ ] Manual compatibility pass across Safari, Notes, Mail, Slack, and TextEdit.
- [ ] Runtime latency tuning and KV-cache reuse.

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

# Launch the menu bar app from source
swift run brotypist

# Build a standalone dev app bundle
./scripts/build-dev-app.sh

# Verify the dev app bundle layout/signature
./scripts/test-dev-app-bundle.sh

# Launch the standalone dev app bundle
open dist/Brotypist.app
```

## Model Setup

Brotypist expects the default model at:

```text
Models/Qwen3-0.6B-Q4_K_M.gguf
```

Download it with:

```sh
./scripts/download-model.sh
```

The script creates `Models/`, skips the download when the file already exists, and fails if the resulting file is empty.

## App Usage

The current MVP flow:

1. Build and launch the dev app with `./scripts/build-dev-app.sh && open dist/Brotypist.app`.
2. Grant Accessibility permission when macOS prompts. Input Monitoring may also be required for the global Tab event tap.
3. Type in any supported text field.
4. Brotypist generates after a short debounce once there is enough text to continue.
5. Gray ghost text appears near the caret.
6. Press `Tab` to accept the next word, or `Esc` to dismiss.

The first implementation is intentionally small: no OCR, no settings pane, no bundled installer, and no prompt personalization yet.

If macOS permissions get stuck while testing the dev bundle, reset them with:

```sh
tccutil reset Accessibility com.ezraapple.brotypist
tccutil reset ListenEvent com.ezraapple.brotypist
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
- A brief note about required macOS permissions.
