#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_PATH="$ROOT_DIR/.githooks/pre-push"

if [[ ! -f "$HOOK_PATH" ]]; then
	echo "Missing hook: .githooks/pre-push"
	exit 1
fi

chmod +x "$HOOK_PATH"
git -C "$ROOT_DIR" config core.hooksPath .githooks

echo "Installed Git hooks."
echo "core.hooksPath=$(git -C "$ROOT_DIR" config --get core.hooksPath)"
