#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/CapsFix.app"

mkdir -p "$BUILD"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Compiling x86_64 (macOS 10.15+)..."
swiftc -O -target x86_64-apple-macos10.15 "$ROOT/Sources/main.swift" -o "$BUILD/CapsFix-x86_64"

echo "Compiling arm64 (macOS 11.0+)..."
swiftc -O -target arm64-apple-macos11.0 "$ROOT/Sources/main.swift" -o "$BUILD/CapsFix-arm64"

echo "Creating universal binary..."
lipo -create "$BUILD/CapsFix-x86_64" "$BUILD/CapsFix-arm64" -output "$APP/Contents/MacOS/CapsFix"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

echo "Signing (ad-hoc)..."
codesign --force --deep --sign - "$APP"

echo "Built: $APP"
lipo -info "$APP/Contents/MacOS/CapsFix"
