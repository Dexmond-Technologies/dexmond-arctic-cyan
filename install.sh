#!/usr/bin/env bash
# Dexmond Arctic Cyan theme 1.1.0: installer.
# Everything it changes is backed up first; ./uninstall.sh puts it all back.
#
#   ./install.sh                       # everything that applies to this computer
#   ./install.sh --wallpaper neural    # circuit (default) | neural | horizon
#   ./install.sh --no-wallpaper --no-terminal --no-editor --no-shell --no-vscode --no-qt --no-chrome
#   ./install.sh --firefox             # also style Firefox (off by default)
#   ./install.sh --flatpak             # also let Flatpak apps read the GTK colours (off by default)
#
# Parts (each one is skipped when its program is not installed):
#   gtk       GTK 3 + GTK 4/libadwaita colours (always)
#   wallpaper a Dexmond wallpaper at your screen size
#   terminal  "Dexmond" profile for GNOME Terminal and for Ptyxis
#   editor    style scheme for GNOME Text Editor, gedit and other GtkSourceView editors
#   shell     top bar, menus and quick settings (needs the User Themes extension, already enabled)
#   vscode    VS Code / VSCodium colour theme (you pick it in VS Code afterwards)
#   qt        qt5ct / qt6ct colour scheme (you pick it in qt5ct / qt6ct afterwards)
#   chrome    Chrome / Chromium theme folder (you load it once by hand, see README)
set -euo pipefail

VERSION=1.1.0
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE="$DATA/dexmond-theme"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
WALL="circuit"
DO_WALL=1; DO_TERM=1; DO_EDIT=1; DO_SHELL=1; DO_CODE=1; DO_QT=1; DO_CHROME=1; DO_FF=0; DO_FLAT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --wallpaper) WALL="${2:?}"; shift 2 ;;
    --no-wallpaper) DO_WALL=0; shift ;;
    --no-terminal) DO_TERM=0; shift ;;
    --no-editor) DO_EDIT=0; shift ;;
    --no-shell) DO_SHELL=0; shift ;;
    --no-vscode) DO_CODE=0; shift ;;
    --no-qt) DO_QT=0; shift ;;
    --no-chrome) DO_CHROME=0; shift ;;
    --firefox) DO_FF=1; shift ;;
    --flatpak) DO_FLAT=1; shift ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
case "$WALL" in circuit|neural|horizon) ;; *) echo "Wallpaper must be circuit, neural or horizon." >&2; exit 2 ;; esac

if [ -e "$STATE/current" ]; then
  echo "The Dexmond theme is already installed. Run ./uninstall.sh first." >&2; exit 1
fi

have() { command -v "$1" >/dev/null 2>&1; }
has_schema() { gsettings list-schemas 2>/dev/null | grep -x "$1" >/dev/null; }   # no grep -q: with pipefail an early exit reads as failure

BK="$STATE/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BK/files"
echo "$VERSION" > "$BK/version"
echo "Backing up your current settings to $BK"

# Settings we change, saved as "schema key value" lines and restored by uninstall.sh.
# A key still at its default is recorded as @reset, so uninstall.sh resets it instead of pinning the value.
save() {
  local now def
  now="$(gsettings get "$1" "$2")"
  def="$(GSETTINGS_BACKEND=memory gsettings get "$1" "$2" 2>/dev/null || true)"
  if [ "$now" = "$def" ] && [ -z "$(dconf read "$(keypath "$1" "$2")" 2>/dev/null || true)" ]; then now="@reset"; fi
  printf '%s %s %s\n' "$1" "$2" "$now" >> "$BK/gsettings.txt"
}
# keypath SCHEMA KEY: the dconf path of a key in a schema with a fixed path.
keypath() { local p; p="$(gsettings list-schemas --print-paths 2>/dev/null | awk -v s="$1" '$1==s{print $2}')"; printf '%s%s' "${p:-/nonexistent/}" "$2"; }
# Folders we create are recorded so uninstall.sh can remove them again once empty.
newdirs() {
  local d="$1" top=""
  while [ ! -e "$d" ]; do top="$d"; d="$(dirname "$d")"; done
  [ -n "$top" ] && printf '%s\n' "$top" >> "$BK/dirs.txt"
  return 0
}

# put SRC DEST: copy a file or folder into place. Whatever was at DEST before is
# saved in the backup (or noted as absent) and listed in files.txt for uninstall.sh.
N=0
put() {
  local src="$1" dest="$2"
  N=$((N + 1))
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    cp -a "$dest" "$BK/files/$N"
    printf '%s\tsaved\t%s\n' "$N" "$dest" >> "$BK/files.txt"
    rm -rf "$dest"
  else
    printf '%s\tabsent\t%s\n' "$N" "$dest" >> "$BK/files.txt"
  fi
  newdirs "$(dirname "$dest")"; mkdir -p "$(dirname "$dest")"
  cp -r "$src" "$dest"
}
# keep DEST: back up DEST before we edit it in place (same records as put).
keep() {
  local dest="$1"
  N=$((N + 1))
  if [ -e "$dest" ]; then
    cp -a "$dest" "$BK/files/$N"; printf '%s\tsaved\t%s\n' "$N" "$dest" >> "$BK/files.txt"
  else
    printf '%s\tabsent\t%s\n' "$N" "$dest" >> "$BK/files.txt"
    newdirs "$(dirname "$dest")"
  fi
}

DONE=(); SKIPPED=()

# ------------------------------------------------------------------ 1. GTK
# (1.0.0 backup format, kept so either uninstaller can read it.)
for v in gtk-3.0 gtk-4.0; do
  if [ -f "$CONF/$v/gtk.css" ]; then
    mkdir -p "$BK/$v"; cp -p "$CONF/$v/gtk.css" "$BK/$v/gtk.css"
  else
    touch "$BK/$v.absent"
  fi
done
save org.gnome.desktop.interface gtk-theme
save org.gnome.desktop.interface color-scheme
[ "$DO_WALL" = 1 ] && { save org.gnome.desktop.background picture-uri; save org.gnome.desktop.background picture-uri-dark; save org.gnome.desktop.background picture-options; }
echo "$BK" > "$STATE/current"

for v in gtk-3.0 gtk-4.0; do
  newdirs "$CONF/$v"; mkdir -p "$CONF/$v"; cp "$HERE/$v/gtk.css" "$CONF/$v/gtk.css"
done
if [ -d /usr/share/themes/Yaru-blue-dark ]; then
  gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-blue-dark'
else
  echo "Note: the Yaru-blue-dark theme is not installed; the overrides apply on top of your current theme."
fi
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
DONE+=("GTK 3 and GTK 4 colours")

# ------------------------------------------------------------ 2. Wallpaper
if [ "$DO_WALL" = 1 ]; then
  WD="$DATA/backgrounds/dexmond"
  newdirs "$DATA/backgrounds"; mkdir -p "$WD"
  W=$(xrandr 2>/dev/null | awk '/\*/{split($1,a,"x"); print a[1]; exit}' || true)
  SIZE=3840x2160
  if [ -n "${W:-}" ] && [ "$W" -le 1920 ]; then SIZE=1920x1080; elif [ -n "${W:-}" ] && [ "$W" -le 2560 ]; then SIZE=2560x1440; fi
  cp "$HERE/wallpapers/dexmond-$WALL-$SIZE.png" "$WD/"
  touch "$BK/wallpaper-installed"
  URI="file://$WD/dexmond-$WALL-$SIZE.png"
  gsettings set org.gnome.desktop.background picture-uri "$URI"
  gsettings set org.gnome.desktop.background picture-uri-dark "$URI"
  gsettings set org.gnome.desktop.background picture-options 'zoom'
  DONE+=("wallpaper ($WALL, $SIZE)")
fi

# ------------------------------------------------------------- 3. Terminals
if [ "$DO_TERM" = 1 ]; then
  if has_schema org.gnome.Terminal.ProfilesList; then
    save org.gnome.Terminal.ProfilesList default
    save org.gnome.Terminal.ProfilesList list
    ID=$(cat /proc/sys/kernel/random/uuid)
    P="/org/gnome/terminal/legacy/profiles:/:$ID/"
    dconf write "${P}visible-name" "'Dexmond'"
    dconf write "${P}use-theme-colors" "false"
    dconf write "${P}background-color" "'#070812'"
    dconf write "${P}foreground-color" "'#e6f1ff'"
    dconf write "${P}cursor-colors-set" "true"
    dconf write "${P}cursor-background-color" "'#00f5ff'"
    dconf write "${P}cursor-foreground-color" "'#070812'"
    dconf write "${P}highlight-colors-set" "true"
    dconf write "${P}highlight-background-color" "'#00c8d4'"
    dconf write "${P}highlight-foreground-color" "'#03121a'"
    dconf write "${P}bold-color-same-as-fg" "true"
    dconf write "${P}palette" "$(cat "$HERE/terminal/palette.txt")"
    OLD=$(gsettings get org.gnome.Terminal.ProfilesList list)
    if [ "$OLD" = "@as []" ] || [ "$OLD" = "[]" ]; then NEW="['$ID']"; else NEW="${OLD%]}, '$ID']"; fi
    gsettings set org.gnome.Terminal.ProfilesList list "$NEW"
    gsettings set org.gnome.Terminal.ProfilesList default "'$ID'"
    echo "$ID" > "$BK/terminal-profile-id"
    DONE+=("GNOME Terminal profile")
  else
    SKIPPED+=("GNOME Terminal (not installed)")
  fi
  if have ptyxis && has_schema org.gnome.Ptyxis; then
    put "$HERE/terminal/dexmond-arctic-cyan.palette" "$DATA/org.gnome.Ptyxis/palettes/dexmond-arctic-cyan.palette"
    save org.gnome.Ptyxis profile-uuids
    save org.gnome.Ptyxis default-profile-uuid
    PID=$(cat /proc/sys/kernel/random/uuid | tr -d -)
    PP="/org/gnome/Ptyxis/Profiles/$PID/"
    dconf write "${PP}label" "'Dexmond'"
    dconf write "${PP}palette" "'dexmond-arctic-cyan'"
    OLD=$(gsettings get org.gnome.Ptyxis profile-uuids)
    if [ "$OLD" = "@as []" ] || [ "$OLD" = "[]" ]; then NEW="['$PID']"; else NEW="${OLD%]}, '$PID']"; fi
    gsettings set org.gnome.Ptyxis profile-uuids "$NEW"
    gsettings set org.gnome.Ptyxis default-profile-uuid "'$PID'"
    echo "$PID" > "$BK/ptyxis-profile-id"
    DONE+=("Ptyxis profile")
  else
    SKIPPED+=("Ptyxis (not installed)")
  fi
fi

# ------------------------------------------------------- 4. Editor schemes
if [ "$DO_EDIT" = 1 ]; then
  XML="$HERE/gtksourceview/dexmond-arctic-cyan.xml"
  OLDXML="$BK/dexmond-arctic-cyan-gsv4.xml"
  sed '/^  <metadata>$/,/^  <\/metadata>$/d' "$XML" > "$OLDXML"   # GtkSourceView 3/4 and gedit do not know <metadata>
  put "$XML" "$DATA/gtksourceview-5/styles/dexmond-arctic-cyan.xml"
  put "$OLDXML" "$DATA/gtksourceview-4/styles/dexmond-arctic-cyan.xml"
  put "$OLDXML" "$DATA/gtksourceview-3.0/styles/dexmond-arctic-cyan.xml"
  put "$OLDXML" "$DATA/libgedit-gtksourceview-300/styles/dexmond-arctic-cyan.xml"
  if has_schema org.gnome.TextEditor; then
    save org.gnome.TextEditor style-scheme
    gsettings set org.gnome.TextEditor style-scheme 'dexmond-arctic-cyan'
    DONE+=("GNOME Text Editor scheme")
  fi
  if has_schema org.gnome.gedit.preferences.editor; then
    save org.gnome.gedit.preferences.editor scheme
    gsettings set org.gnome.gedit.preferences.editor scheme 'dexmond-arctic-cyan'
    DONE+=("gedit scheme")
  fi
  DONE+=("GtkSourceView style scheme files")
fi

# ------------------------------------------------------------ 5. GNOME Shell
if [ "$DO_SHELL" = 1 ]; then
  UT=user-theme@gnome-shell-extensions.gcampax.github.com
  if have gnome-extensions && gnome-extensions list --enabled 2>/dev/null | grep -x "$UT" >/dev/null && has_schema org.gnome.shell.extensions.user-theme; then
    put "$HERE/gnome-shell" "$DATA/themes/Dexmond-Arctic-Cyan/gnome-shell"
    save org.gnome.shell.extensions.user-theme name
    gsettings set org.gnome.shell.extensions.user-theme name 'Dexmond-Arctic-Cyan'
    DONE+=("GNOME Shell theme")
  else
    SKIPPED+=("GNOME Shell top bar (the User Themes extension is not installed and enabled; see README)")
  fi
fi

# ------------------------------------------------------------------ 6. VS Code
if [ "$DO_CODE" = 1 ]; then
  found=0
  for d in "$HOME/.vscode/extensions:code" "$HOME/.vscode-oss/extensions:codium"; do
    dir="${d%%:*}"; cmd="${d##*:}"
    if [ -d "$dir" ] || have "$cmd"; then
      put "$HERE/vscode" "$dir/dexmond.dexmond-arctic-cyan-$VERSION"
      found=1
    fi
  done
  if [ "$found" = 1 ]; then DONE+=("VS Code theme (choose it under File > Preferences > Theme > Color Theme)"); else SKIPPED+=("VS Code (not installed)"); fi
fi

# ---------------------------------------------------------------------- 7. Qt
if [ "$DO_QT" = 1 ]; then
  found=0
  for q in qt5ct qt6ct; do
    if have "$q"; then put "$HERE/qt/Dexmond-Arctic-Cyan.conf" "$CONF/$q/colors/Dexmond-Arctic-Cyan.conf"; found=1; fi
  done
  if [ "$found" = 1 ]; then DONE+=("Qt colour scheme (choose it in qt5ct / qt6ct)"); else SKIPPED+=("Qt (qt5ct / qt6ct not installed)"); fi
fi

# ------------------------------------------------------------------ 8. Chrome
if [ "$DO_CHROME" = 1 ]; then
  if have google-chrome || have google-chrome-stable || have chromium || have chromium-browser || have brave-browser; then
    put "$HERE/chrome" "$STATE/chrome-theme"
    DONE+=("Chrome theme folder $STATE/chrome-theme (load it once: chrome://extensions > Developer mode > Load unpacked)")
  else
    SKIPPED+=("Chrome / Chromium (not installed)")
  fi
fi

# --------------------------------------------------------- 9. Firefox (opt-in)
if [ "$DO_FF" = 1 ]; then
  PROF=""
  for base in "$HOME/.mozilla/firefox" "$HOME/snap/firefox/common/.mozilla/firefox"; do
    if [ -f "$base/profiles.ini" ]; then
      rel=$(awk -F= '/^\[Install/{i=1} i&&/^Default=/{print $2; exit}' "$base/profiles.ini")
      [ -z "$rel" ] && rel=$(awk -F= '/^Path=/{p=$2} /^Default=1/{print p; exit}' "$base/profiles.ini")
      if [ -n "$rel" ]; then case "$rel" in /*) PROF="$rel" ;; *) PROF="$base/$rel" ;; esac; break; fi
    fi
  done
  if [ -n "$PROF" ] && [ -d "$PROF" ]; then
    put "$HERE/firefox/userChrome.css" "$PROF/chrome/userChrome.css"
    keep "$PROF/user.js"
    echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true); // added by Dexmond Arctic Cyan' >> "$PROF/user.js"
    DONE+=("Firefox userChrome.css in $PROF (restart Firefox)")
  else
    SKIPPED+=("Firefox (no profile found)")
  fi
fi

# --------------------------------------------------------- 10. Flatpak (opt-in)
if [ "$DO_FLAT" = 1 ]; then
  if have flatpak; then
    keep "$DATA/flatpak/overrides/global"
    flatpak override --user --filesystem=xdg-config/gtk-3.0:ro --filesystem=xdg-config/gtk-4.0:ro
    DONE+=("Flatpak apps may read the GTK colours")
  else
    SKIPPED+=("Flatpak (not installed)")
  fi
fi

echo
echo "Installed:"; for d in "${DONE[@]}"; do echo "  - $d"; done
if [ "${#SKIPPED[@]}" -gt 0 ]; then echo "Skipped:"; for s in "${SKIPPED[@]}"; do echo "  - $s"; done; fi
echo
echo "Apps that are already open keep the old colours until you restart them (or log out and back in)."
echo "To undo: ./uninstall.sh"
