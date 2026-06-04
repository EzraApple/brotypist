#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${CONFIGURATION:-debug}"
APP_NAME="BrotypistInputMethod"
EXECUTABLE_NAME="brotypistim"
BUNDLE_ID="com.ezraapple.brotypist.inputmethod"
CONNECTION_NAME="BrotypistInputMethod_Connection"
INSTALL_DIR="${HOME}/Library/Input Methods"
APP_PATH="${INSTALL_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_PATH}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
MODEL_FILE="qwen3-0.6b-base-q4_k_m.gguf"
DEFAULT_CODESIGN_IDENTITY="Brotypist Local Development"

swift build --product "${EXECUTABLE_NAME}" -c "${CONFIGURATION}"
BIN_DIR="$(swift build -c "${CONFIGURATION}" --show-bin-path)"

mkdir -p "${INSTALL_DIR}"
rm -rf "${APP_PATH}"
mkdir -p "${MACOS_DIR}" "${FRAMEWORKS_DIR}" "${RESOURCES_DIR}"

cp "${BIN_DIR}/${EXECUTABLE_NAME}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

if [[ -d "${BIN_DIR}/llama.framework" ]]; then
  ditto "${BIN_DIR}/llama.framework" "${FRAMEWORKS_DIR}/llama.framework"
else
  echo "Missing ${BIN_DIR}/llama.framework" >&2
  exit 1
fi

if ! otool -l "${MACOS_DIR}/${APP_NAME}" | grep -q '@executable_path/../Frameworks'; then
  install_name_tool -add_rpath '@executable_path/../Frameworks' "${MACOS_DIR}/${APP_NAME}"
fi

if [[ -s "Models/${MODEL_FILE}" ]]; then
  mkdir -p "${RESOURCES_DIR}/Models"
  cp "Models/${MODEL_FILE}" "${RESOURCES_DIR}/Models/${MODEL_FILE}"
else
  echo "Model not copied; run ./scripts/download-model.sh first." >&2
fi

cat > "${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>InputMethodConnectionName</key>
  <string>${CONNECTION_NAME}</string>
  <key>InputMethodServerControllerClass</key>
  <string>BrotypistInputMethod.InputController</string>
  <key>tsInputMethodCharacterRepertoireKey</key>
  <array>
    <string>en</string>
  </array>
  <key>ComponentInputModeDict</key>
  <dict>
    <key>tsInputModeListKey</key>
    <dict>
      <key>com.ezraapple.brotypist.inputmethod.default</key>
      <dict>
        <key>TISInputSourceID</key>
        <string>com.ezraapple.brotypist.inputmethod.default</string>
        <key>TISIntendedLanguage</key>
        <string>en</string>
        <key>tsInputModeAlternateMenuIconFileKey</key>
        <string></string>
        <key>tsInputModeCharacterRepertoireKey</key>
        <array>
          <string>en</string>
        </array>
        <key>tsInputModeDefaultStateKey</key>
        <string>on</string>
        <key>tsInputModeIsVisibleKey</key>
        <true/>
        <key>tsInputModeKeyEquivalentKey</key>
        <string></string>
        <key>tsInputModeKeyEquivalentModifiersKey</key>
        <integer>0</integer>
        <key>tsInputModeMenuIconFileKey</key>
        <string></string>
        <key>tsInputModePaletteIconFileKey</key>
        <string></string>
        <key>tsInputModePrimaryInScriptKey</key>
        <true/>
        <key>tsInputModeScriptKey</key>
        <string>smRoman</string>
      </dict>
    </dict>
  </dict>
</dict>
</plist>
PLIST

if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
  if security find-identity -v -p codesigning | grep -Fq "\"${DEFAULT_CODESIGN_IDENTITY}\""; then
    CODESIGN_IDENTITY="${DEFAULT_CODESIGN_IDENTITY}"
  else
    CODESIGN_IDENTITY="-"
  fi
fi

codesign --force --deep --sign "${CODESIGN_IDENTITY}" "${APP_PATH}"

echo "Built ${APP_PATH}"
echo "Signed with: ${CODESIGN_IDENTITY}"
echo
echo "Activating input source..."
swift run brotypistctl install-input-source 2>&1 | sed 's/^/  /' || true
echo
echo "If you don't see ghost text after this, switch to '${APP_NAME}'"
echo "from the input-source menu in your menu bar (top right)."
