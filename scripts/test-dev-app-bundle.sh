#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-dist/Brotypist.app}"
INFO_PLIST="${APP_PATH}/Contents/Info.plist"
EXECUTABLE="${APP_PATH}/Contents/MacOS/Brotypist"
LLAMA_FRAMEWORK="${APP_PATH}/Contents/Frameworks/llama.framework"

[[ -d "${APP_PATH}" ]] || { echo "Missing ${APP_PATH}" >&2; exit 1; }
[[ -f "${INFO_PLIST}" ]] || { echo "Missing ${INFO_PLIST}" >&2; exit 1; }
[[ -x "${EXECUTABLE}" ]] || { echo "Missing executable ${EXECUTABLE}" >&2; exit 1; }
[[ -d "${LLAMA_FRAMEWORK}" ]] || { echo "Missing ${LLAMA_FRAMEWORK}" >&2; exit 1; }

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${INFO_PLIST}")"
[[ "${BUNDLE_ID}" == "com.ezraapple.brotypist" ]] || {
  echo "Unexpected bundle id: ${BUNDLE_ID}" >&2
  exit 1
}

EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${INFO_PLIST}")"
[[ "${EXECUTABLE_NAME}" == "Brotypist" ]] || {
  echo "Unexpected executable name: ${EXECUTABLE_NAME}" >&2
  exit 1
}

otool -l "${EXECUTABLE}" | grep -q '@executable_path/../Frameworks' || {
  echo "Executable is missing Frameworks rpath." >&2
  exit 1
}

codesign --verify --deep --strict "${APP_PATH}"

echo "Verified ${APP_PATH}"
