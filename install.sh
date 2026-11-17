#!/usr/bin/env bash
# Wheel Hover Launcher — first-run setup.
# Creates the config + log dirs, seeds apps.json from apps.json.example
# (never overwrites an existing one), and prints the compositor setup steps.
# Safe to re-run. No sudo needed.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/wheel-hover-launcher"
LOG_DIR="$HOME/magnus/wheel-hover-launcher/logs"

echo "== Wheel Hover Launcher setup =="

# --- dependency check ---
if command -v quickshell >/dev/null 2>&1; then
    echo "OK: quickshell found ($(quickshell --version 2>/dev/null || echo 'unknown version'))"
else
    echo "WARNING: quickshell is not installed."
    echo "  Arch:   pacman -S quickshell"
    echo "  Other:  https://quickshell.outfoxxed.me/docs/v0.3.0/type/Quickshell/quickshell/"
fi

# --- directories ---
mkdir -p "$CONFIG_DIR" "$LOG_DIR"
echo "OK: created $CONFIG_DIR"
echo "OK: created $LOG_DIR"

# --- seed apps.json ---
if [ -f "$CONFIG_DIR/apps.json" ]; then
    echo "OK: $CONFIG_DIR/apps.json already exists, leaving it untouched."
else
    cp "$REPO_DIR/apps.json.example" "$CONFIG_DIR/apps.json"
    echo "OK: seeded $CONFIG_DIR/apps.json (edit freely — it hot-reloads)."
fi

# --- next steps: compositor wiring ---
echo
echo "Next steps (pick your compositor):"
echo
echo "Hyprland (Wayland) — in ~/.config/hypr/hyprland.lua, in the startup block:"
echo '    hl.exec_cmd("quickshell -p '"$REPO_DIR"'")'
echo '    hl.bind(mainMod .. " + X", hl.dsp.global("quickshell:wheel-hover-launcher"))'
echo "  (classic hyprland.conf: bind = SUPER, X, global, quickshell:wheel-hover-launcher)"
echo "  Verify: hyprctl globalshortcuts"
echo
echo "i3 (X11) — in ~/.config/i3/config:"
echo "    exec --no-startup-id quickshell -p $REPO_DIR"
echo "    bindsym \$mod+X exec --no-startup-id quickshell -p $REPO_DIR ipc call wheel-hover-launcher toggle"
echo '    for_window [title="^quickshell$"] floating enable, fullscreen enable'
echo "  Transparency needs a compositor (picom)."
echo
echo "Then reload / re-login and press Super+X to open the wheel."
echo "Usage: homerow keys launch, Esc or click outside closes, Ctrl/Alt+click launches."
echo "Full docs: $REPO_DIR/README.org"
