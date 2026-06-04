#!/usr/bin/env bash
set -euo pipefail

APP_NAME="BrotypistInputMethod"
INSTALL_DIR="${HOME}/Library/Input Methods"
APP_PATH="${INSTALL_DIR}/${APP_NAME}.app"
EXTENSION_PATH="${APP_PATH}/Contents/PlugIns/${APP_NAME}Extension.appex"

if [[ -d "${APP_PATH}" ]]; then
  if [[ -d "${EXTENSION_PATH}" ]]; then
    pluginkit -r "${EXTENSION_PATH}" 2>/dev/null || true
  fi
  rm -rf "${APP_PATH}"
  echo "Removed ${APP_PATH}"
else
  echo "${APP_PATH} not installed."
fi

killall TextInputMenuAgent TextInputSwitcher imklaunchagent 2>/dev/null || true

echo
echo "If the input source still appears in System Settings, remove it via:"
echo "  System Settings → Keyboard → Input Sources → select '${APP_NAME}' → '-'"
echo "Then log out and back in (or restart) so the registry rescans."
