#!/usr/bin/env bash
set -euo pipefail

MODEL_DIR="Models"
MODEL_FILE="Qwen3-0.6B-Q4_K_M.gguf"
MODEL_PATH="${MODEL_DIR}/${MODEL_FILE}"
MODEL_URL="https://huggingface.co/second-state/Qwen3-0.6B-GGUF/resolve/main/${MODEL_FILE}"

mkdir -p "${MODEL_DIR}"

if [[ -s "${MODEL_PATH}" ]]; then
  echo "Model already exists at ${MODEL_PATH}; skipping download."
  exit 0
fi

if [[ -e "${MODEL_PATH}" ]]; then
  echo "Existing model file is empty; re-downloading ${MODEL_PATH}."
  rm -f "${MODEL_PATH}"
fi

tmp_path="${MODEL_PATH}.tmp"
rm -f "${tmp_path}"

echo "Downloading ${MODEL_FILE}..."
curl -L "${MODEL_URL}" -o "${tmp_path}"

if [[ ! -s "${tmp_path}" ]]; then
  rm -f "${tmp_path}"
  echo "Downloaded model is empty." >&2
  exit 1
fi

mv "${tmp_path}" "${MODEL_PATH}"
echo "Model saved to ${MODEL_PATH}."
