#!/usr/bin/env bash
# Dexmond Arctic Cyan theme: installer.
# Adds the Arctic Cyan GTK overrides, a "Dexmond" GNOME Terminal profile and a wallpaper.
# Everything it changes is backed up first; ./uninstall.sh puts it all back.
#
#   ./install.sh                       # circuit wallpaper, terminal profile, GTK overrides
#   ./install.sh --wallpaper neural    # or: circuit | neural | horizon
#   ./install.sh --no-wallpaper --no-terminal
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="${XDG_DATA_HOME:-$HOME/.local/share}/dexmond-theme"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
WALL="circuit"; DO_WALL=1; DO_TERM=1

while [ $# -gt 0 ]; do
  case "$1" in
    --wallpaper) WALL="${2:?}"; shift 2 ;;
    --no-wallpaper) DO_WALL=0; shift ;;
    --no-terminal) DO_TERM=0; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
case "$WALL" in circuit|neural|horizon) ;; *) echo "Wallpaper must be circuit, neural or horizon." >&2; exit 2 ;; esac

if [ -e "$STATE/current" ]; then
  echo "The Dexmond theme is already installed. Run ./uninstall.sh first." >&2; exit 1
fi

BK="$STATE/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BK"
echo "Backing up your current settings to $BK"

# 1. GTK overrides: keep the user's own gtk.css files (or note that there were none).
for v in gtk-3.0 gtk-4.0; do
  if [ -f "$CONF/$v/gtk.css" ]; then
    mkdir -p "$BK/$v"; cp -p "$CONF/$v/gtk.css" "$BK/$v/gtk.css"
  else
    touch "$BK/$v.absent"
  fi
done

# 2. Settings we may change, saved as "schema key value" lines.
save() { printf '%s %s %s\n' "$1" "$2" "$(gsettings get "$1" "$2")" >> "$BK/gsettings.txt"; }
save org.gnome.desktop.interface gtk-theme
save org.gnome.desktop.interface color-scheme
save org.gnome.desktop.background picture-uri
save org.gnome.desktop.background picture-uri-dark
save org.gnome.desktop.background picture-options
if [ "$DO_TERM" = 1 ]; then
  save org.gnome.Terminal.ProfilesList default
  save org.gnome.Terminal.ProfilesList list
fi
echo "$BK" > "$STATE/current"

# 3. Apply.
for v in gtk-3.0 gtk-4.0; do
  mkdir -p "$CONF/$v"; cp "$HERE/$v/gtk.css" "$CONF/$v/gtk.css"
done
if [ -d /usr/share/themes/Yaru-blue-dark ]; then
  gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-blue-dark'
else
  echo "Note: the Yaru-blue-dark theme is not installed; the overrides apply on top of your current theme."
fi
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

if [ "$DO_WALL" = 1 ]; then
  WD="${XDG_DATA_HOME:-$HOME/.local/share}/backgrounds/dexmond"
  mkdir -p "$WD"
  W=$(xrandr 2>/dev/null | awk '/\*/{split($1,a,"x"); print a[1]; exit}' || true)
  SIZE=3840x2160
  if [ -n "${W:-}" ] && [ "$W" -le 1920 ]; then SIZE=1920x1080; elif [ -n "${W:-}" ] && [ "$W" -le 2560 ]; then SIZE=2560x1440; fi
  cp "$HERE/wallpapers/dexmond-$WALL-$SIZE.png" "$WD/"
  URI="file://$WD/dexmond-$WALL-$SIZE.png"
  gsettings set org.gnome.desktop.background picture-uri "$URI"
  gsettings set org.gnome.desktop.background picture-uri-dark "$URI"
  gsettings set org.gnome.desktop.background picture-options 'zoom'
fi

if [ "$DO_TERM" = 1 ]; then
  ID=$(cat /proc/sys/kernel/random/uuid)
  P="/org/gnome/terminal/legacy/profiles:/:$ID/"
  dconf write "${P}visible-name" "'Dexmond'"
  dconf write "${P}use-theme-colors" "false"
  dconf write "${P}background-color" "'#070812'"
  dconf write "${P}foreground-color" "'#e6f1ff'"
  dconf write "${P}cursor-colors-set" "true"
  dconf write "${P}cursor-background-color" "'#00f5ff'"
  dconf write "${P}cursor-foreground-color" "'#070812'"
  dconf write "${P}bold-color-same-as-fg" "false"
  dconf write "${P}bold-color" "'#ffee00'"
  dconf write "${P}palette" "$(cat "$HERE/terminal/palette.txt")"
  OLD=$(gsettings get org.gnome.Terminal.ProfilesList list)
  if [ "$OLD" = "@as []" ] || [ "$OLD" = "[]" ]; then NEW="['$ID']"; else NEW="${OLD%]}, '$ID']"; fi
  gsettings set org.gnome.Terminal.ProfilesList list "$NEW"
  gsettings set org.gnome.Terminal.ProfilesList default "'$ID'"
  echo "$ID" > "$BK/terminal-profile-id"
fi

echo "Done. Log out and back in (or restart the apps) to see the GTK changes everywhere."
echo "To undo: ./uninstall.sh"
