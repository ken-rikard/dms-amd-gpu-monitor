#!/usr/bin/env bash
# install.sh — installs both the bar widget and the desktop widget
# Run from the repo root: ./install.sh

set -euo pipefail

PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/plugins"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BAR_DEST="$PLUGIN_DIR/AmdGpuMonitor"
DESKTOP_DEST="$PLUGIN_DIR/AmdGpuMonitorDesktop"

echo "→ Installing bar widget to $BAR_DEST"
mkdir -p "$BAR_DEST"
cp "$REPO_DIR/AmdGpuMonitorWidget.qml"    "$BAR_DEST/"
cp "$REPO_DIR/AmdGpuMonitorSettings.qml"  "$BAR_DEST/"
cp "$REPO_DIR/plugin.json"                "$BAR_DEST/"
cp -r "$REPO_DIR/components"              "$BAR_DEST/"

echo "→ Installing desktop widget to $DESKTOP_DEST"
mkdir -p "$DESKTOP_DEST"
cp "$REPO_DIR/AmdGpuMonitorDesktopWidget.qml"   "$DESKTOP_DEST/"
cp "$REPO_DIR/AmdGpuMonitorDesktopSettings.qml" "$DESKTOP_DEST/"
cp "$REPO_DIR/desktop-plugin.json"              "$DESKTOP_DEST/plugin.json"
cp -r "$REPO_DIR/components"                    "$DESKTOP_DEST/"

echo ""
echo "Done. Reload DMS to pick up both plugins:"
echo "  dms ipc call plugins reload amdGpuMonitor"
echo "  dms ipc call plugins reload amdGpuMonitorDesktop"
echo ""
echo "Or do a full restart:"
echo "  dms restart"
