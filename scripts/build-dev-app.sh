#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${CONFIGURATION:-debug}"
APP_NAME="Brotypist"
BUNDLE_ID="com.ezraapple.brotypist"
DIST_DIR="dist"
APP_PATH="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_PATH}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
MODEL_FILE="Qwen3-0.6B-Q4_K_M.gguf"
DEFAULT_CODESIGN_IDENTITY="Brotypist Local Development"

swift build --product brotypist -c "${CONFIGURATION}"
BIN_DIR="$(swift build -c "${CONFIGURATION}" --show-bin-path)"

rm -rf "${APP_PATH}"
mkdir -p "${MACOS_DIR}" "${FRAMEWORKS_DIR}" "${RESOURCES_DIR}"

cp "${BIN_DIR}/brotypist" "${MACOS_DIR}/${APP_NAME}"
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
  echo "Model not copied; run ./scripts/download-model.sh to include it in the dev app bundle." >&2
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
echo "Open with: open ${APP_PATH}"
