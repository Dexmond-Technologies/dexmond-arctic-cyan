# Dexmond Arctic Cyan theme

A dark cyan theme designed for use with the GNOME desktop, tested on Ubuntu 24.04 LTS: GTK colour overrides, a GNOME Terminal profile and procedurally generated wallpapers.

![Circuit wallpaper](wallpapers/dexmond-circuit-1920x1080.png)

Also included: **Neural** and **Horizon**.

## What it changes
- `~/.config/gtk-3.0/gtk.css` and `~/.config/gtk-4.0/gtk.css`: cyan accent, dark windows and header bars. They apply on top of the **Yaru-blue-dark** theme that ships with Ubuntu, which the installer selects if it is installed. Yaru itself is not included or modified.
- Dark style (`color-scheme = prefer-dark`).
- A new GNOME Terminal profile named **Dexmond** (background `#070812`, text `#e6f1ff`, cursor `#00f5ff`), set as the default. Your existing profiles are kept.
- A wallpaper, at the size that matches your screen.

## Install
```bash
tar xzf dexmond-arctic-cyan-1.0.0.tar.gz
cd dexmond-arctic-cyan-1.0.0
./install.sh                      # circuit wallpaper
./install.sh --wallpaper neural   # or: horizon
./install.sh --no-terminal --no-wallpaper   # GTK colours only
```
Log out and back in to see the GTK colours in every app.

## Uninstall
```bash
./uninstall.sh
```
Before changing anything, the installer saves your current `gtk.css` files, theme, dark-style, wallpaper and terminal-profile settings in `~/.local/share/dexmond-theme/backup-<date>/`. `uninstall.sh` restores them exactly and removes the Dexmond terminal profile and wallpapers.

The install and uninstall scripts were tested (see `TESTING.md`) on Ubuntu 24.04.5 LTS (GNOME Shell 46, GNOME Terminal 3.52). Other GNOME desktops may work; other desktop environments are not supported.

## Wallpapers
`wallpapers/` has three designs: Circuit (the default), Neural and Horizon, at 3840×2160, 2560×1440, 1920×1080 and 1080×1920 (phone). They are drawn entirely in code by `tools/make_wallpapers.py`. To regenerate them, run `python3 tools/make_wallpapers.py --all` (needs pycairo, numpy and Pillow).

## Licence
- Code, scripts and CSS: MIT (`LICENSE`).
- Wallpapers and other artwork: CC BY 4.0 (`LICENSE-ARTWORK`). Credit "Dexmond Technologies".
- The Dexmond name and mark are excluded from both licences (copyright and trademark). You may keep the mark in unmodified copies of the wallpapers; remove it from modified versions.

Ubuntu is a registered trademark of Canonical Ltd. GNOME is a trademark of the GNOME Foundation. This project is not affiliated with, sponsored or endorsed by Canonical or the GNOME Foundation.
