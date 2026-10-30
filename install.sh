#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
"$ROOT/build.sh"

DEST="$HOME/Applications/CapsFix.app"
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
cp -R "$ROOT/build/CapsFix.app" "$DEST"

PLIST="$HOME/Library/LaunchAgents/com.local.capsfix.plist"
mkdir -p "$(dirname "$PLIST")"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.local.capsfix</string>
    <key>ProgramArguments</key>
    <array>
        <string>$DEST/Contents/MacOS/CapsFix</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ThrottleInterval</key>
    <integer>10</integer>
    <key>ProcessType</key>
    <string>Background</string>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/capsfix.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/capsfix.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/com.local.capsfix" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo
echo "Installed."
echo "If it does not work yet, grant Accessibility to:"
echo "    $DEST"
echo "System Settings > Privacy & Security > Accessibility"
echo
echo "Log: $HOME/Library/Logs/capsfix.log"
