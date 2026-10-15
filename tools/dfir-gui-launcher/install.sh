#!/usr/bin/env bash
# Install/reinstall identical GNOME/Pop!_OS desktop + application menu shortcuts.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"
LIBEXEC="$HOME/.local/libexec"
APPS="$HOME/.local/share/applications"
ICONS="$HOME/.local/share/icons"
DESKTOP="$HOME/Desktop"

if [[ ! -f "$HOME/.ssh/config" ]] || ! grep -Eq '^[[:space:]]*Host[[:space:]]+dfir-gui([[:space:]]|$)' "$HOME/.ssh/config"; then
  printf 'SSH alias dfir-gui not found in ~/.ssh/config; configure it first.\n' >&2
  exit 1
fi
mkdir -p "$BIN" "$LIBEXEC" "$APPS" "$ICONS"
install -m 0755 "$ROOT/cyberblue-dfir" "$BIN/cyberblue-dfir"
install -m 0755 "$ROOT/cyberblue-dfir-start-tunnel" "$LIBEXEC/cyberblue-dfir-start-tunnel"
install -m 0644 "$ROOT/cyberblue-raptor-dfir.png" "$ICONS/cyberblue-raptor-dfir.png"

# A SINGLE desktop-entry definition is installed into both entry points.
cat > "$APPS/cyberblue-dfir.desktop" <<DESKTOP_FILE
[Desktop Entry]
Version=1.0
Type=Application
Name=CyberBlue Raptor - DFIR Console
GenericName=Velociraptor DFIR Console
Comment=Establish secure DFIR-01 SSH tunnel then open GUI
Exec=$BIN/cyberblue-dfir
Icon=$ICONS/cyberblue-raptor-dfir.png
Terminal=false
Categories=System;Network;
StartupNotify=false
DESKTOP_FILE
chmod 644 "$APPS/cyberblue-dfir.desktop"

if [[ -d "$DESKTOP" ]]; then
  cp -f "$APPS/cyberblue-dfir.desktop" "$DESKTOP/cyberblue-dfir.desktop"
  chmod 755 "$DESKTOP/cyberblue-dfir.desktop"
  # GNOME/GIO desktop security requires the user to trust the shortcut.
  if command -v gio >/dev/null 2>&1; then
    gio set "$DESKTOP/cyberblue-dfir.desktop" metadata::trusted true 2>/dev/null || true
  fi
  printf 'Desktop shortcut updated (right-click > Allow Launching if requested).\n'
fi
printf '\nUpdated CyberBlue DFIR launcher v2.\n'
printf 'Start-menu and desktop icons now invoke the exact same launcher:\n  %s/cyberblue-dfir\n' "$BIN"
printf 'Debug log: %s/.cache/cyberblue-dfir/launcher.log\n' "$HOME"
printf 'Existing authorized SSH tunnels are reused; none are terminated by this installer.\n'
