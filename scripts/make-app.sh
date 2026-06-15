#!/bin/bash
# Baut ein echtes, doppelklickbares macOS-App-Bundle aus dem SwiftPM-Executable.
# Verwendung:  scripts/make-app.sh [debug|release]   (Standard: release)
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "› swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/BaufiApp"
APP="$ROOT/BaufiApp.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/BaufiApp"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
[ -f "$ROOT/scripts/AppIcon.icns" ] && cp "$ROOT/scripts/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc-Signatur, damit Gatekeeper das lokale Bundle ohne Warnung startet.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "✓ $APP"
echo "  Starten:  open \"$APP\"     (oder im Finder doppelklicken)"
