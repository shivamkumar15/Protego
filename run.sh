#!/usr/bin/env bash
set -euo pipefail

flutter_bin="${FLUTTER_BIN:-flutter}"

if ! command -v "$flutter_bin" >/dev/null 2>&1; then
  if [ -x "$HOME/flutter/bin/flutter" ]; then
    flutter_bin="$HOME/flutter/bin/flutter"
  fi
fi

if ! command -v "$flutter_bin" >/dev/null 2>&1; then
  echo "Error: Flutter is not installed or not on PATH."
  echo "Install Flutter and try again: https://docs.flutter.dev/get-started/install"
  exit 1
fi

"$flutter_bin" pub get
"$flutter_bin" run "$@"
