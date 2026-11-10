#!/usr/bin/env bash
# Dexmond Arctic Cyan theme: uninstaller. Restores everything install.sh backed up.
set -euo pipefail

STATE="${XDG_DATA_HOME:-$HOME/.local/share}/dexmond-theme"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"

if [ ! -f "$STATE/current" ]; then
  echo "The Dexmond theme is not installed (no backup record in $STATE)." >&2; exit 1
fi
BK="$(cat "$STATE/current")"
[ -d "$BK" ] || { echo "Backup folder $BK is missing; nothing restored." >&2; exit 1; }
echo "Restoring your settings from $BK"

# 1. GTK overrides: put the user's files back, or remove ours if there were none.
for v in gtk-3.0 gtk-4.0; do
  if [ -f "$BK/$v/gtk.css" ]; then
    mkdir -p "$CONF/$v"; cp -p "$BK/$v/gtk.css" "$CONF/$v/gtk.css"
  elif [ -f "$BK/$v.absent" ]; then
    rm -f "$CONF/$v/gtk.css"
  fi
done

# 2. Terminal profile: remove ours (the saved list and default are restored below).
if [ -f "$BK/terminal-profile-id" ]; then
  ID="$(cat "$BK/terminal-profile-id")"
  dconf reset -f "/org/gnome/terminal/legacy/profiles:/:$ID/"
fi

# 3. Settings, exactly as they were.
while read -r schema key value; do
  gsettings set "$schema" "$key" "$value"
done < "$BK/gsettings.txt"

# 4. Our wallpapers.
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/backgrounds/dexmond"

rm -f "$STATE/current"
echo "Done. Your previous settings are back. The backup stays in $BK; you can delete it."
