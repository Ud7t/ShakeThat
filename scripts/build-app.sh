#!/usr/bin/env bash
# Builds ShakeThat.app into ./build using SwiftPM (no Xcode project needed).
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

APP="build/ShakeThat.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/ShakeThat" "$APP/Contents/MacOS/ShakeThat"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature so macOS will launch it locally.
codesign --force --sign - "$APP"

echo "Built $APP"
