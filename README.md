# Dexmond Arctic Cyan theme

A dark navy and cyan theme for the GNOME desktop, tested on Ubuntu 24.04 LTS. It covers GTK 3 and GTK 4/libadwaita apps, the terminal, code editors, and procedurally generated wallpapers. Optional parts cover the GNOME Shell top bar, VS Code, Qt apps, Chrome and Firefox.

![Rhythmbox with the theme](screenshots/v1.1.0/rhythmbox.png)

![Circuit wallpaper](wallpapers/dexmond-circuit-1920x1080.png)

Also included: the **Neural** and **Horizon** wallpapers.

## What it changes
| Part | What you get | Where it goes | Default |
|---|---|---|---|
| GTK 3 | Navy windows, lists, sidebars, tabs, buttons, entries, menus and scrollbars, with cyan selection (Rhythmbox, gedit, file choosers and other GTK 3 apps). | `~/.config/gtk-3.0/gtk.css` | on |
| GTK 4 / libadwaita | Every libadwaita named colour, including sidebars, dialogs, cards, accent, and the error, warning and success colours (Files, Settings, Text Editor and other GNOME apps). | `~/.config/gtk-4.0/gtk.css` | on |
| Base theme | Yaru-blue-dark (ships with Ubuntu; not included or modified) and dark style. | gsettings | on |
| Wallpaper | Circuit, Neural or Horizon at your screen size. | `~/.local/share/backgrounds/dexmond/` | on |
| GNOME Terminal | A new **Dexmond** profile, set as the default. Your profiles are kept. | dconf | on, if installed |
| Ptyxis | A **Dexmond Arctic Cyan** palette and a **Dexmond** profile. | `~/.local/share/org.gnome.Ptyxis/palettes/` | on, if installed |
| Text editors | A **Dexmond Arctic Cyan** style scheme, selected in GNOME Text Editor and gedit. Other GtkSourceView editors list it too. | `~/.local/share/gtksourceview-*/styles/`, `~/.local/share/libgedit-gtksourceview-300/styles/` | on |
| GNOME Shell | Top bar, menus, quick settings, calendar, notifications, dash and search. | `~/.local/share/themes/Dexmond-Arctic-Cyan/` | on, only if the User Themes extension is already enabled |
| VS Code / VSCodium | A **Dexmond Arctic Cyan** colour theme (UI, syntax and terminal colours). | `~/.vscode/extensions/`, `~/.vscode-oss/extensions/` | on, if installed |
| Qt (qt5ct / qt6ct) | A **Dexmond-Arctic-Cyan** colour scheme. | `~/.config/qt5ct/colors/`, `~/.config/qt6ct/colors/` | on, if installed |
| Chrome / Chromium | An unpacked theme folder. | `~/.local/share/dexmond-theme/chrome-theme/` | on, if installed |
| Firefox | `userChrome.css` styling of the toolbar, tabs and menus. | your default Firefox profile | **off** (`--firefox`) |
| Flatpak apps | Lets Flatpak apps read the two GTK files (read-only). | `flatpak override --user` | **off** (`--flatpak`) |

Errors and destructive buttons use pink, warnings use yellow and success uses mint. The theme has no red or orange accents. In the terminal, the ANSI red slots stay red, because programs use them to mean errors and deletions.

## Install
```bash
tar xzf dexmond-arctic-cyan-1.1.0.tar.gz
cd dexmond-arctic-cyan-1.1.0
./install.sh                          # everything that applies, circuit wallpaper
./install.sh --wallpaper neural       # or: horizon
./install.sh --no-wallpaper --no-terminal   # leave those alone
./install.sh --firefox --flatpak      # add the two parts that are off by default
./install.sh --help                   # all options (--no-editor, --no-shell, --no-vscode, --no-qt, --no-chrome)
```
Apps that are already open keep their old colours until you restart them. To see the change everywhere, log out and back in.

### The steps you do by hand
- **VS Code:** File > Preferences > Theme > Color Theme > *Dexmond Arctic Cyan*.
- **Qt apps:** open qt5ct or qt6ct, pick the *Dexmond-Arctic-Cyan* colour scheme, and make sure `QT_QPA_PLATFORMTHEME=qt5ct` (or `qt6ct`) is set for your session. The installer does not change your environment variables.
- **Chrome / Chromium / Brave:** open `chrome://extensions`, turn on *Developer mode*, click *Load unpacked* and choose `~/.local/share/dexmond-theme/chrome-theme`. To go back, choose *Reset to default* under Settings > Appearance.
- **GNOME Shell top bar:** install and enable the *User Themes* extension yourself (for example with the Extension Manager app, or `sudo apt install gnome-shell-extensions` and then log out and back in), then run `./uninstall.sh && ./install.sh`. The installer never installs or enables extensions.
- **Firefox:** run `./install.sh --firefox`, then restart Firefox.

## Uninstall
```bash
./uninstall.sh
```
Before it changes anything, the installer saves the following in `~/.local/share/dexmond-theme/backup-<date>/`:
- your `gtk.css` files;
- every setting it changes;
- every file it replaces or edits.

`uninstall.sh` puts all of that back, removes what the theme added (the profiles, schemes, theme folders and wallpapers) and removes the folders the installer created once they are empty. It also reads backups made by version 1.0.0.

## What cannot be themed this way
- **Snap apps** (Firefox, Thunderbird and Brave on Ubuntu, App Center) run with their own home folder, so they do not read `~/.config/gtk-3.0` or `gtk-4.0`. Their window contents keep their own colours. The Chrome theme and Firefox `userChrome.css` still work inside the browsers.
- **Flatpak apps** read the GTK files only after `./install.sh --flatpak`. Some Flatpak apps (Electron apps such as Obsidian) draw their own UI and ignore GTK colours entirely.
- **Electron and other non-GTK apps** (VS Code's window, Obsidian, Discord) need their own theme. This package ships one for VS Code.
- **Qt apps** follow the theme only through qt5ct/qt6ct, as described above. Kvantum is not supported.
- **GNOME Shell** (top bar, quick settings) needs the User Themes extension.

## Tested on
Ubuntu 24.04.5 LTS: GNOME Shell 46, GTK 3.24.41, GTK 4.14.5, libadwaita 1.5.0, Rhythmbox 3.4.7, gedit 46.2, GNOME Text Editor 46.3. `TESTING.md` lists what was tested and what was not, and the contrast ratio of every colour pair (all of them pass WCAG AA). `python3 tools/contrast.py` recomputes the ratios.

## Wallpapers
`wallpapers/` has three designs: Circuit (the default), Neural and Horizon, at 3840×2160, 2560×1440, 1920×1080 and 1080×1920 (phone). They are drawn entirely in code by `tools/make_wallpapers.py`. To regenerate them, run `python3 tools/make_wallpapers.py --all` (needs pycairo, numpy and Pillow).

## Changelog
### 1.1.0 (19 November 2026)
- **Fixed:** GTK 3 apps (Rhythmbox, gedit, file choosers) kept Yaru's grey lists, sidebars, panes and buttons; only header bars changed. Yaru's GTK 3 stylesheet uses fixed colours, not named ones. `gtk-3.0/gtk.css` now sets every GTK 3 colour name and has explicit rules, covering every widget state, for:
  - lists, tree views, icon views, column headers, sidebars, panes and tabs;
  - toolbars, buttons, entries, spin buttons and combo boxes;
  - scales, progress and level bars, switches, check boxes and radio buttons;
  - menus, popovers, tooltips, info bars, status bars, scrollbars and selections, including windows in the background.
- **Fixed:** the terminal palette had yellow in the bright-blue and bright-white slots and rose in bright magenta. Bold text was yellow; it now uses the normal text colour.
- **Fixed:** the header-bar title of a window in the background was close to the contrast limit (`#557d96`); it is now `#7fa6bd` (7.3:1).
- **New:** complete libadwaita colours: sidebars, secondary sidebars, dialogs, thumbnails, shades, borders, and the destructive, success, warning and error colours.
- **New:** a Ptyxis palette and profile, a GtkSourceView style scheme (Text Editor, gedit), a GNOME Shell theme, a VS Code theme, a qt5ct/qt6ct colour scheme, a Chrome theme, a Firefox `userChrome.css` and a Flatpak option.
- **New:** the installer backs up and restores every file it places or edits. A setting that was at its default is reset, not pinned. The desktop-icons (DING) layer stays transparent.
- **New:** `tools/contrast.py` measures WCAG contrast for every colour pair.

### 1.0.0 (10 November 2026)
First release: GTK colour overrides, the Dexmond GNOME Terminal profile and the three wallpapers.

## Licence
- Code, scripts, CSS and the editor, terminal, VS Code, Qt, Chrome and Firefox themes: MIT (`LICENSE`).
- Wallpapers and other artwork: CC BY 4.0 (`LICENSE-ARTWORK`). Credit "Dexmond Technologies".
- The Dexmond name and mark are excluded from both licences (copyright and trademark). You may keep the mark in unmodified copies of the wallpapers; remove it from modified versions.

Ubuntu is a registered trademark of Canonical Ltd. GNOME is a trademark of the GNOME Foundation. Visual Studio Code is a trademark of Microsoft Corporation. Chrome is a trademark of Google LLC. Firefox is a trademark of the Mozilla Foundation. This project is not affiliated with, sponsored or endorsed by any of them.
