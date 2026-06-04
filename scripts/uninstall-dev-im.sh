#!/usr/bin/env bash
set -euo pipefail

APP_NAME="BrotypistInputMethod"
INSTALL_DIR="${HOME}/Library/Input Methods"
APP_PATH="${INSTALL_DIR}/${APP_NAME}.app"
EXTENSION_PATH="${APP_PATH}/Contents/PlugIns/${APP_NAME}Extension.appex"
BUNDLE_ID="com.ezraapple.inputmethod.Brotypist"

osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true
pkill -f '/System/Library/ExtensionKit/Extensions/KeyboardSettings.appex' 2>/dev/null || true

if [[ -d "${APP_PATH}" ]]; then
  if [[ -d "${EXTENSION_PATH}" ]]; then
    pluginkit -r "${EXTENSION_PATH}" 2>/dev/null || true
  fi
  rm -rf "${APP_PATH}"
  echo "Removed ${APP_PATH}"
else
  echo "${APP_PATH} not installed."
fi

pluginkit -e ignore -i "${BUNDLE_ID}" 2>/dev/null || true
killall TextInputMenuAgent TextInputSwitcher imklaunchagent cfprefsd 2>/dev/null || true

echo
echo "If the input source still appears in System Settings, remove it via:"
echo "  System Settings → Keyboard → Input Sources → select '${APP_NAME}' → '-'"
echo "Open System Settings from the normal UI before checking the '+' picker again."
echo "If KeyboardSettings processes remain stuck in an exiting state, log out and back in so launchd reaps them."
