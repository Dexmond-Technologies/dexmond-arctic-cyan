# Test record

**Date:** 10 November 2026
**System:** Ubuntu 24.04.5 LTS, GNOME Shell 46.0, GNOME Terminal 3.52.0

## Method
The scripts ran in a sandbox so that the tester's own desktop was never touched:
- a temporary `HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME` and `XDG_RUNTIME_DIR`;
- a private D-Bus session (`dbus-run-session`), so `gsettings` and `dconf` wrote to a throw-away dconf database.

The tester's real settings (theme, colour scheme, wallpaper, terminal profiles, both `gtk.css` files) were recorded before and after each run and compared.

## Runs
1. **From the source folder:** `./install.sh --wallpaper neural`, then `./install.sh` again, then `./uninstall.sh`.
   - The install applied Yaru-blue-dark, prefer-dark, the wallpaper, and the Dexmond terminal profile (added to the list and set as default).
   - The second install was refused ("already installed").
   - The uninstall restored the previous theme, colour scheme, wallpaper and terminal profile list and default. It put back the user's own `gtk-3.0/gtk.css` and removed `gtk-4.0/gtk.css`, which had not existed before.
2. **From the extracted release archive:** `./install.sh`, then `./uninstall.sh`.
   - The install set the Circuit wallpaper at the size that matches the screen.
   - The uninstall restored the previous wallpaper and removed the theme's wallpaper folder.

**Result:** both runs passed. The tester's real settings were identical before and after.

## Not tested
- The visual result on screen.
- Other Ubuntu versions and other GNOME-based distributions.
