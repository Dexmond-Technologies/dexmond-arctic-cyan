# Test record

## Version 1.1.0
**Date:** 19 November 2026
**System:** Ubuntu 24.04.5 LTS, GNOME Shell 46.0 (Wayland), GTK 3.24.41, GTK 4.14.5, libadwaita 1.5.0, GtkSourceView 5.12.0, libgedit-gtksourceview 300, Rhythmbox 3.4.7, gedit 46.2, GNOME Text Editor 46.3

### 1. Stylesheets parse cleanly
GTK's own CSS parser loaded both files, through `Gtk.CssProvider` for GTK 3 and for GTK 4, and reported **0 parsing errors** for each.

### 2. GTK 3 result on screen: Rhythmbox
Rhythmbox 3.4.7 ran as a separate test instance on the real Wayland desktop through Xwayland, so that the window could be captured on its own. It used the following:
- `--no-registration` and its own database and playlist files;
- scratch config and data folders holding a copy of the 1.1.0 `gtk.css`;
- a demo library of generated test tones with neutral tags. The demo tracks had not yet been imported when the screenshot was taken, so the lists are empty.

The tester's own Rhythmbox, which was playing, was not touched. Result: `screenshots/v1.1.0/rhythmbox.png`.
- The sidebar, browser lists, track list and column headers are navy, not Yaru grey. This is the 1.0.0 bug, now fixed.
- The selected rows in the browser ("All artists", "All albums") are cyan with navy text.
- The toolbar buttons, the checked "Browse" button, the search entry, the volume slider and the status bar use the theme colours.

### 3. Installer and uninstaller, in a sandbox
The scripts ran with a throw-away `HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME` and `XDG_RUNTIME_DIR`, and a private D-Bus session. The environment was set *before* `dbus-run-session`, so the private dconf service also wrote to the throw-away folder. That was checked first with a canary key: it appeared in the sandbox and not in the real dconf database, and the real database file's modification time did not change.

The sandbox started with:
- the user's own `gtk-3.0/gtk.css`;
- a Firefox profile with an existing `user.js`;
- an empty `~/.vscode/extensions`;
- a stand-in `qt6ct` command.

Run: `./install.sh --wallpaper neural --firefox --flatpak`, then `./install.sh` again, then `./uninstall.sh`.
- The install placed both `gtk.css` files and the wallpaper. It added the Dexmond GNOME Terminal profile, with the fixed palette, and set it as the default.
- It placed the GtkSourceView scheme in the `gtksourceview-3.0`, `gtksourceview-4`, `gtksourceview-5` and `libgedit-gtksourceview-300` folders. The metadata block was kept only in the version 5 copy.
- It set the scheme in Text Editor and gedit.
- It placed the VS Code extension folder, the qt6ct colour scheme and the Chrome theme folder.
- It placed Firefox's `chrome/userChrome.css` and appended one pref line to `user.js`, keeping the existing line.
- It wrote the Flatpak override.
- It skipped Ptyxis and the Shell theme, and said why.
- The second install was refused ("already installed").
- After the uninstall, every file in the sandbox home, the settings and the GNOME Terminal dconf tree were identical to before. That includes the user's `gtk.css` (by SHA-256) and `user.js`. Settings that had been at their default were reset, not pinned. The folders the installer had created were removed. One difference remained: `flatpak override` itself creates an empty Flatpak user repository (`~/.local/share/flatpak/repo`), which is left in place.

**Result: pass.** The tester's real settings were identical before and after the sandbox run.

The same run from the extracted release archive (`dexmond-arctic-cyan-1.1.0.tar.gz`) gave the same result.

**Incident during testing:** the first sandbox attempt set the throw-away folders *inside* the private D-Bus session. Its dconf service therefore wrote to the tester's real settings for about one minute: theme, colour scheme, wallpaper, gedit scheme and the Terminal profile list. The values recorded just before the test were restored at once and checked. The method above fixes the cause. Logged as INC-2026-11-19-THEME1.

### 4. Style scheme files
- `gtksourceview/dexmond-arctic-cyan.xml` is well-formed XML.
- Its GtkSourceView 3/4 copy, without the metadata block, validates against `styles.rng` and loads in libgedit-gtksourceview 300 through `GtkSource.StyleSchemeManager`, which is what gedit 46 uses.
- The `styles.rng` shipped with Ubuntu 24.04 rejects the metadata block, as it also does for Ubuntu's own `Adwaita-dark.xml`. GtkSourceView 5 itself reads that block.

### 5. JSON files
`chrome/manifest.json`, `vscode/package.json` and `vscode/themes/dexmond-arctic-cyan-color-theme.json` parse as valid JSON.

### 6. Installed on the tester's desktop
`./install.sh --no-wallpaper`. The current wallpaper was kept, and no app was restarted.
- The backup in `~/.local/share/dexmond-theme/backup-20261119-010433/` holds the previous `gtk.css` files (SHA-256 `3ff4757b…f333`), the settings and the list of added files.
- The installed `gtk.css` files are byte-identical to the repository's.
- It installed: both GTK files, the Dexmond GNOME Terminal profile, the Text Editor and gedit schemes, and the Chrome theme folder.
- It skipped: Ptyxis, VS Code and qt5ct/qt6ct (not installed), and the Shell theme (the User Themes extension is not installed).

### 7. Contrast (WCAG 2.x)
Measured with `tools/contrast.py`. Translucent colours are composited over their background first. AA needs 4.5:1 for body text and 3:1 for large text and UI parts. Disabled text is exempt (WCAG 1.4.3).

| Pair | Text | Background | Ratio | Needs | Result |
|---|---|---|---|---|---|
| Body text on window | `#d8f5ff` | `#070912` | 17.43:1 | 4.5 | pass |
| Text in lists and views | `#d0efff` | `#05070d` | 16.76:1 | 4.5 | pass |
| Text in sidebars | `#d8f5ff` | `#080d19` | 17.03:1 | 4.5 | pass |
| Text on cards, menus, popovers | `#d8f5ff` | `#0c1424` | 16.15:1 | 4.5 | pass |
| Button text | `#d8f5ff` | `#0e1a2b` | 15.34:1 | 4.5 | pass |
| Button text, hover | `#ffffff` | `#13263a` | 15.37:1 | 4.5 | pass |
| Checked button text | `#00f5ff` | `#0b3644` | 9.54:1 | 4.5 | pass |
| Secondary / backdrop text on window | `#8fb0c6` | `#070912` | 8.70:1 | 4.5 | pass |
| Secondary text on cards | `#8fb0c6` | `#0c1424` | 8.06:1 | 4.5 | pass |
| Header bar title (cyan) | `#00f5ff` | `#0a1b2a` | 12.89:1 | 4.5 | pass |
| Header bar title, window in backdrop | `#7fa6bd` | `#07121c` | 7.27:1 | 4.5 | pass |
| Selected row text (focused) | `#03121a` | `#00c8d4` | 9.24:1 | 4.5 | pass |
| Selected row text (window in backdrop) | `#cfefff` | `#0b3644` | 10.73:1 | 4.5 | pass |
| Text selection (cyan 35% over view) | `#ffffff` | `#035a62` | 7.95:1 | 4.5 | pass |
| Suggested button text | `#03121a` | `#00f5ff` | 14.03:1 | 4.5 | pass |
| Suggested button text (gradient end) | `#03121a` | `#00b3d6` | 7.62:1 | 4.5 | pass |
| Destructive button text | `#ffffff` | `#a8155f` | 7.15:1 | 4.5 | pass |
| Links | `#5ce1ff` | `#05070d` | 13.11:1 | 4.5 | pass |
| Visited links | `#b48cff` | `#05070d` | 7.80:1 | 4.5 | pass |
| Error text | `#ff5ca8` | `#05070d` | 7.05:1 | 4.5 | pass |
| Warning text | `#ffd24d` | `#05070d` | 13.98:1 | 4.5 | pass |
| Success text | `#3ef0a0` | `#05070d` | 13.60:1 | 4.5 | pass |
| Tooltip text | `#d8f5ff` | `#03060c` | 17.80:1 | 4.5 | pass |
| Column header text | `#8fb0c6` | `#080f1a` | 8.41:1 | 4.5 | pass |
| Libadwaita accent text (accent_color) | `#00f5ff` | `#070912` | 14.67:1 | 4.5 | pass |
| Libadwaita accent button text | `#03121a` | `#00c8d4` | 9.24:1 | 4.5 | pass |
| Terminal text | `#e6f1ff` | `#070812` | 17.47:1 | 4.5 | pass |
| Editor comments | `#7f9db3` | `#05070d` | 7.07:1 | 4.5 | pass |
| Editor line numbers | `#5d7689` | `#070912` | 4.18:1 | 3.0 | pass |
| Disabled text (exempt under WCAG 1.4.3) | `#5d7689` | `#070912` | 4.18:1 | exempt | pass |

**Result:** every pair passes. The lowest body-text pair is *Destructive button text* at 7.15:1.

### Not tested
- **Screenshots of Files, Settings, Text Editor, a file chooser and Terminal.** They were not taken: the owner was working at the machine and asked for no more windows to be opened on the screen. Only the Rhythmbox screenshot exists.
- **libadwaita apps on screen.** The GTK 4 named colours are standard libadwaita 1.5 names and parse cleanly, but no libadwaita app was opened with them.
- **GNOME Shell theme** (User Themes is not installed here; the `@import` of Yaru's Shell stylesheet was not tried in a running Shell).
- **Ptyxis** (not installed; the palette file follows Ptyxis's palette format, but Ptyxis never loaded it).
- **VS Code** (not installed), **qt5ct/qt6ct** (not installed; only a stand-in command was used), **Chrome theme loaded in a browser**, **Firefox userChrome.css in a running Firefox**, and **Flatpak apps** reading the override.
- **GtkSourceView 5 loading the scheme** (no GtkSourceView 5 introspection data here; Text Editor was not opened).
- **Uninstalling a 1.0.0 install with the 1.1.0 uninstaller.** The code path keeps the 1.0.0 backup format, but it was not run.
- Other Ubuntu versions and other GNOME-based distributions.

## Version 1.0.0
**Date:** 10 November 2026
**System:** Ubuntu 24.04.5 LTS, GNOME Shell 46.0, GNOME Terminal 3.52.0

### Method
The scripts ran in a sandbox so that the tester's own desktop was never touched:
- a temporary `HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME` and `XDG_RUNTIME_DIR`;
- a private D-Bus session (`dbus-run-session`), so `gsettings` and `dconf` wrote to a throw-away dconf database.

The tester's real settings (theme, colour scheme, wallpaper, terminal profiles, both `gtk.css` files) were recorded before and after each run and compared.

### Runs
1. **From the source folder:** `./install.sh --wallpaper neural`, then `./install.sh` again, then `./uninstall.sh`.
   - The install applied Yaru-blue-dark, prefer-dark, the wallpaper, and the Dexmond terminal profile (added to the list and set as default).
   - The second install was refused ("already installed").
   - The uninstall restored the previous theme, colour scheme, wallpaper and terminal profile list and default. It put back the user's own `gtk-3.0/gtk.css` and removed `gtk-4.0/gtk.css`, which had not existed before.
2. **From the extracted release archive:** `./install.sh`, then `./uninstall.sh`.
   - The install set the Circuit wallpaper at the size that matches the screen.
   - The uninstall restored the previous wallpaper and removed the theme's wallpaper folder.

**Result:** both runs passed. The tester's real settings were identical before and after.

### Not tested
- The visual result on screen.
- Other Ubuntu versions and other GNOME-based distributions.
