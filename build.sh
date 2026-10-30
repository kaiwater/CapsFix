#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/CapsFix.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Compiling..."
swiftc -O "$ROOT/Sources/main.swift" -o "$APP/Contents/MacOS/CapsFix"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

echo "Signing (ad-hoc)..."
codesign --force --deep --sign - "$APP"

echo "Built: $APP"
