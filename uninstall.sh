#!/bin/bash
set -euo pipefail

launchctl bootout "gui/$(id -u)/com.local.capsfix" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.local.capsfix.plist"
rm -rf "$HOME/Applications/CapsFix.app"
echo "Uninstalled."
