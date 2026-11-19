#!/usr/bin/env bash
# Dexmond Arctic Cyan theme: uninstaller. Restores everything install.sh backed up.
# Works with backups made by the 1.0.0 and 1.1.0 installers.
set -euo pipefail

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE="$DATA/dexmond-theme"
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

# 2. Every other file or folder the installer placed or edited (1.1.0 and later).
#    Undo in reverse order so a path written twice ends up as it was first found.
if [ -f "$BK/files.txt" ]; then
  tac "$BK/files.txt" | while IFS=$'\t' read -r n state dest; do
    rm -rf "$dest"
    if [ "$state" = saved ]; then
      mkdir -p "$(dirname "$dest")"; cp -a "$BK/files/$n" "$dest"
    fi
  done
fi

# 3. Terminal profiles: remove ours (the saved lists and defaults are restored below).
if [ -f "$BK/terminal-profile-id" ]; then
  dconf reset -f "/org/gnome/terminal/legacy/profiles:/:$(cat "$BK/terminal-profile-id")/"
fi
if [ -f "$BK/ptyxis-profile-id" ]; then
  dconf reset -f "/org/gnome/Ptyxis/Profiles/$(cat "$BK/ptyxis-profile-id")/"
fi

# 4. Settings, exactly as they were.
if [ -f "$BK/gsettings.txt" ]; then
  while read -r schema key value; do
    if [ "$value" = "@reset" ]; then gsettings reset "$schema" "$key"; else gsettings set "$schema" "$key" "$value"; fi
  done < "$BK/gsettings.txt"
fi

# 5. Our wallpapers (1.0.0 always installed one; 1.1.0 records it).
if [ -f "$BK/wallpaper-installed" ] || [ ! -f "$BK/version" ]; then
  rm -rf "$DATA/backgrounds/dexmond"
fi

# 6. Folders the installer created, if they are empty again.
if [ -f "$BK/dirs.txt" ]; then
  sort -ru "$BK/dirs.txt" | while read -r d; do
    [ -d "$d" ] && find "$d" -depth -type d -empty -delete 2>/dev/null || true
  done
fi

rm -f "$STATE/current"
echo "Done. Your previous settings are back. The backup stays in $BK; you can delete it."
