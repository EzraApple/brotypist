#!/usr/bin/env bash
set -euo pipefail

APP_NAME="BrotypistInputMethod"
INSTALL_DIR="${HOME}/Library/Input Methods"
APP_PATH="${INSTALL_DIR}/${APP_NAME}.app"

if [[ -d "${APP_PATH}" ]]; then
  rm -rf "${APP_PATH}"
  echo "Removed ${APP_PATH}"
else
  echo "${APP_PATH} not installed."
fi

echo
echo "If the input source still appears in System Settings, remove it via:"
echo "  System Settings → Keyboard → Input Sources → select '${APP_NAME}' → '-'"
echo "Then log out and back in (or restart) so the registry rescans."
