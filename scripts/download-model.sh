#!/usr/bin/env bash
set -euo pipefail

MODEL_DIR="Models"
MODEL_FILE="qwen3-0.6b-base-q4_k_m.gguf"
MODEL_PATH="${MODEL_DIR}/${MODEL_FILE}"
MODEL_URL="https://huggingface.co/Antigma/Qwen3-0.6B-Base-GGUF/resolve/main/${MODEL_FILE}"

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
