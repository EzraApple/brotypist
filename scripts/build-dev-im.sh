#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${CONFIGURATION:-debug}"
APP_NAME="BrotypistInputMethod"
EXECUTABLE_NAME="brotypistim"
CONTAINER_BUNDLE_ID="com.ezraapple.BrotypistInputMethod"
BUNDLE_ID="com.ezraapple.inputmethod.Brotypist"
MODE_ID="${BUNDLE_ID}.Roman"
CONNECTION_NAME="${BUNDLE_ID}.IMK_Connection"
EXTENSION_NAME="${APP_NAME}Extension"
INSTALL_DIR="${HOME}/Library/Input Methods"
INSTALL_PATH="${INSTALL_DIR}/${APP_NAME}.app"
DIST_DIR="${DIST_DIR:-dist}"
APP_PATH="${DIST_DIR}/${APP_NAME}.app"
ENTITLEMENTS_PATH="${DIST_DIR}/${APP_NAME}.entitlements"
APP_CONTENTS_DIR="${APP_PATH}/Contents"
APP_MACOS_DIR="${APP_CONTENTS_DIR}/MacOS"
APP_FRAMEWORKS_DIR="${APP_CONTENTS_DIR}/Frameworks"
APP_PLUGINS_DIR="${APP_CONTENTS_DIR}/PlugIns"
EXTENSION_PATH="${APP_PLUGINS_DIR}/${EXTENSION_NAME}.appex"
EXTENSION_CONTENTS_DIR="${EXTENSION_PATH}/Contents"
EXTENSION_MACOS_DIR="${EXTENSION_CONTENTS_DIR}/MacOS"
EXTENSION_FRAMEWORKS_DIR="${EXTENSION_CONTENTS_DIR}/Frameworks"
EXTENSION_RESOURCES_DIR="${EXTENSION_CONTENTS_DIR}/Resources"
MODEL_FILE="qwen3-0.6b-base-q4_k_m.gguf"
DEFAULT_CODESIGN_IDENTITY="Brotypist Local Development"

swift build --product "${EXECUTABLE_NAME}" -c "${CONFIGURATION}"
BIN_DIR="$(swift build -c "${CONFIGURATION}" --show-bin-path)"

rm -rf "${APP_PATH}"
mkdir -p \
  "${APP_MACOS_DIR}" \
  "${APP_FRAMEWORKS_DIR}" \
  "${APP_PLUGINS_DIR}" \
  "${EXTENSION_MACOS_DIR}" \
  "${EXTENSION_FRAMEWORKS_DIR}" \
  "${EXTENSION_RESOURCES_DIR}"

cp "${BIN_DIR}/${EXECUTABLE_NAME}" "${APP_MACOS_DIR}/${APP_NAME}"
cp "${BIN_DIR}/${EXECUTABLE_NAME}" "${EXTENSION_MACOS_DIR}/${APP_NAME}"
chmod +x "${APP_MACOS_DIR}/${APP_NAME}" "${EXTENSION_MACOS_DIR}/${APP_NAME}"

if [[ -d "${BIN_DIR}/llama.framework" ]]; then
  ditto "${BIN_DIR}/llama.framework" "${APP_FRAMEWORKS_DIR}/llama.framework"
  ditto "${BIN_DIR}/llama.framework" "${EXTENSION_FRAMEWORKS_DIR}/llama.framework"
else
  echo "Missing ${BIN_DIR}/llama.framework" >&2
  exit 1
fi

for executable in "${APP_MACOS_DIR}/${APP_NAME}" "${EXTENSION_MACOS_DIR}/${APP_NAME}"; do
  if ! otool -l "${executable}" | grep -q '@executable_path/../Frameworks'; then
    install_name_tool -add_rpath '@executable_path/../Frameworks' "${executable}"
  fi
done

if [[ -s "Models/${MODEL_FILE}" ]]; then
  mkdir -p "${EXTENSION_RESOURCES_DIR}/Models"
  cp "Models/${MODEL_FILE}" "${EXTENSION_RESOURCES_DIR}/Models/${MODEL_FILE}"
else
  echo "Model not copied; run ./scripts/download-model.sh first." >&2
fi

cat > "${APP_CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${CONTAINER_BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>BrotypistInputMethod</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleSignature</key>
  <string>????</string>
  <key>CFBundleSupportedPlatforms</key>
  <array>
    <string>MacOSX</string>
  </array>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

cat > "${EXTENSION_CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>Brotypist</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Brotypist</string>
  <key>CFBundlePackageType</key>
  <string>XPC!</string>
  <key>CFBundleSignature</key>
  <string>????</string>
  <key>CFBundleSupportedPlatforms</key>
  <array>
    <string>MacOSX</string>
  </array>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.textinputmethod-services</string>
    <key>NSExtensionPrincipalClass</key>
    <string>IMKExtensionIM</string>
  </dict>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSSupportsSuddenTermination</key>
  <false/>
  <key>InputMethodConnectionName</key>
  <string>${CONNECTION_NAME}</string>
  <key>InputMethodServerControllerClass</key>
  <string>InputController</string>
  <key>InputMethodServerDelegateClass</key>
  <string>InputController</string>
  <key>TISInputSourceID</key>
  <string>${BUNDLE_ID}</string>
  <key>TISIntendedLanguage</key>
  <string>en</string>
  <key>tsInputMethodCharacterRepertoireKey</key>
  <array>
    <string>Latn</string>
  </array>
  <key>TISIconIsTemplate</key>
  <true/>
  <key>ComponentInputModeDict</key>
  <dict>
    <key>TISUnifiedUIForInputMethodEnabling</key>
    <true/>
    <key>tsInputModeListKey</key>
    <dict>
      <key>${MODE_ID}</key>
      <dict>
        <key>TISIconLabels</key>
        <dict>
          <key>Primary</key>
          <string>B</string>
        </dict>
        <key>TISInputSourceID</key>
        <string>${MODE_ID}</string>
        <key>TISIntendedLanguage</key>
        <string>en</string>
        <key>tsInputModeCharacterRepertoireKey</key>
        <array>
          <string>Latn</string>
        </array>
        <key>tsInputModeDefaultStateKey</key>
        <true/>
        <key>tsInputModeIsVisibleKey</key>
        <true/>
        <key>tsInputModePrimaryInScriptKey</key>
        <true/>
        <key>tsInputModeScriptKey</key>
        <string>smRoman</string>
      </dict>
    </dict>
    <key>tsVisibleInputModeOrderedArrayKey</key>
    <array>
      <string>${MODE_ID}</string>
    </array>
  </dict>
</dict>
</plist>
PLIST

cat > "${ENTITLEMENTS_PATH}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
  <key>com.apple.security.get-task-allow</key>
  <true/>
  <key>com.apple.security.temporary-exception.mach-register.global-name</key>
  <array>
    <string>${CONNECTION_NAME}</string>
  </array>
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

codesign --force --deep --sign "${CODESIGN_IDENTITY}" "${APP_FRAMEWORKS_DIR}/llama.framework"
codesign --force --deep --sign "${CODESIGN_IDENTITY}" "${EXTENSION_FRAMEWORKS_DIR}/llama.framework"
codesign --force --sign "${CODESIGN_IDENTITY}" --entitlements "${ENTITLEMENTS_PATH}" "${EXTENSION_PATH}"
codesign --force --sign "${CODESIGN_IDENTITY}" "${APP_PATH}"

echo "Built ${APP_PATH}"
echo "Signed with: ${CODESIGN_IDENTITY}"

if [[ "${INSTALL_INPUT_METHOD:-0}" == "1" ]]; then
  if [[ "${BROTYPIST_ALLOW_UNSAFE_INPUT_METHOD_INSTALL:-0}" != "1" ]]; then
    echo
    echo "Refusing to install: this package currently hangs the Keyboard Settings '+' picker on macOS 26.3.1."
    echo "Build output is still available at ${APP_PATH} for inspection."
    echo "To reproduce the unsafe registration probe anyway:"
    echo "  BROTYPIST_ALLOW_UNSAFE_INPUT_METHOD_INSTALL=1 INSTALL_INPUT_METHOD=1 ./scripts/build-dev-im.sh"
    exit 2
  fi

  mkdir -p "${INSTALL_DIR}"
  rm -rf "${INSTALL_PATH}"
  ditto "${APP_PATH}" "${INSTALL_PATH}"
  echo "Installed ${INSTALL_PATH}"
  sleep 1
  pluginkit -a -v "${INSTALL_PATH}/Contents/PlugIns/${EXTENSION_NAME}.appex" || true
  sleep 1
  pluginkit -e use -i "${BUNDLE_ID}" || true
  killall TextInputMenuAgent TextInputSwitcher imklaunchagent 2>/dev/null || true
  sleep 3
  echo
  echo "Registering input source..."
  swift run brotypistctl install-input-source --bundle-id "${BUNDLE_ID}" --mode-id "${MODE_ID}" --bundle-path "${INSTALL_PATH}" --no-select --no-open-settings 2>&1 | sed 's/^/  /' || true
else
  echo
  echo "Not installed. The IMK registration path is still experimental."
  echo "Unsafe install is gated behind BROTYPIST_ALLOW_UNSAFE_INPUT_METHOD_INSTALL=1."
fi
