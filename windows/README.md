# Dexmond Arctic Cyan for Windows

A free dark cyan look for **Windows 10 and Windows 11**: dark mode, a cyan accent colour (`#00f5ff`), a Dexmond wallpaper and a Windows Terminal colour scheme. It is the Windows version of the GNOME theme in this repository.

It costs nothing, needs no administrator rights, downloads nothing and sends nothing anywhere.

## What it changes
Only your own Windows account is changed. Nothing else on the PC is touched.

| Setting | Where Windows keeps it | New value |
|---|---|---|
| Dark mode for apps and for Windows | `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize` (`AppsUseLightTheme`, `SystemUsesLightTheme`) | 0 (dark) |
| Accent colour | `HKCU\Software\Microsoft\Windows\DWM` (`AccentColor`, `ColorizationColor`) and `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent` (`AccentColorMenu`, `StartColorMenu`, `AccentPalette`) | `#00f5ff` and 7 shades of it worked out by the script |
| "Pick accent colour from wallpaper" | `HKCU\Control Panel\Desktop\AutoColorization` | off |
| Wallpaper | `HKCU\Control Panel\Desktop` (`Wallpaper`, `WallpaperStyle` = fill, `TileWallpaper` = off) | a copy in `%LOCALAPPDATA%\Dexmond\ArcticCyan\wallpapers\` |
| Windows Terminal | its `settings.json` | adds a colour scheme called **Dexmond Arctic Cyan**. Your profiles are not switched to it. |

Before it changes anything, the installer saves every one of these values, and a copy of each Windows Terminal `settings.json`, in `%LOCALAPPDATA%\Dexmond\ArcticCyan\backup-<date>\`. It notes which values did not exist yet, so that uninstalling can remove them again.

## Install
1. Download and unzip `dexmond-arctic-cyan-windows-<version>.zip`, or clone this repository.
2. Open the unzipped folder (or the `windows` folder of the repository) in File Explorer.
3. Click the address bar, type `powershell` and press Enter. A PowerShell window opens in that folder.
4. See what would change first, without changing anything:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1 -WhatIf
   ```
5. Install:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```
   The script prints each change it makes.

`-ExecutionPolicy Bypass` lets Windows run this one script in this one window. It does not change your PC's settings.

Options:
- `-Wallpaper neural` or `-Wallpaper horizon` picks another design. Circuit is the default.
- `-Size 1920x1080`, `2560x1440` or `3840x2160` picks a wallpaper size. By default the script reads your screen width and picks the closest size.
- `-NoWallpaper`, `-NoAccent`, `-NoDarkMode` and `-NoTerminal` skip that part.

If the taskbar or Start menu still shows the old colour, sign out and back in.

To use the colour scheme in Windows Terminal, open **Settings**, choose your profile, then **Appearance > Color scheme > Dexmond Arctic Cyan**.

## Undo
In the same folder, run:
```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -WhatIf   # see what would be restored
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```
This puts back every saved value with its old type and data, removes the values that did not exist before, deletes the wallpaper copy and puts back your old wallpaper.

For Windows Terminal:
- If you have not edited `settings.json` since installing, it is replaced with the saved copy.
- If you have edited it, your edits are kept and only the Dexmond Arctic Cyan scheme is taken out. A copy of your edited file is saved first. Use `-Force` if you would rather get the saved copy back.

The backup folder stays after uninstalling, and you can delete it.

## Things to know
- **Slideshow and Windows Spotlight:** if your desktop background was a slideshow or Spotlight, uninstalling puts back your last wallpaper picture. Turn the slideshow or Spotlight back on in **Settings > Personalisation > Background**.
- **Windows Terminal settings with comments:** if your `settings.json` has `//` comments, the scripts leave it alone, because rewriting it would delete your comments. Copy the scheme from `terminal\dexmond-arctic-cyan.json` into the `"schemes"` list of that file yourself.
- **Accent shades:** Windows normally works out 7 lighter and darker shades when you pick an accent colour in Settings. The script works out its own shades. They may differ slightly from Windows' own.
- The installer refuses to run a second time until you uninstall.

## Without the script: the .theme file
`DexmondArcticCyan.theme` sets dark mode, the cyan accent and the Circuit wallpaper. To use it:
1. Copy `wallpapers\dexmond-circuit-3840x2160.png` into `%LOCALAPPDATA%\Dexmond\ArcticCyan\wallpapers\` (paste that path into the File Explorer address bar, creating the folders if needed).
2. Double-click `DexmondArcticCyan.theme`.

Windows does not keep a backup when you apply a .theme file. To go back, choose your old theme in **Settings > Personalisation > Themes**.

There is no one-click `.deskthemepack` file yet. A .deskthemepack is a Microsoft cabinet (CAB) file, and it can only be built and checked with cabinet tools.

## Files
- `install.ps1`, `uninstall.ps1`: the scripts. They run in Windows PowerShell 5.1, which comes with Windows 10 and 11, and in PowerShell 7.
- `DexmondArcticCyan.theme`: the .theme file.
- `terminal/dexmond-arctic-cyan.json`: the Windows Terminal scheme. Its 16 colours are the same as the GNOME Terminal palette in `../terminal/palette.txt`, in the same order. The background is `#070812`, the text `#e6f1ff` and the cursor `#00f5ff`.
- `build-zip.sh`: builds the download zip (run on Linux or macOS).
- `SHA256SUMS`: checksums. To check them, run `sha256sum -c SHA256SUMS` in this folder, or `Get-FileHash` in PowerShell.
- Wallpapers: the scripts use the PNG files in `../wallpapers/` in the repository, or in `wallpapers\` inside the zip. Three designs (Circuit, Neural, Horizon), each at 3840×2160, 2560×1440 and 1920×1080. The 1080×1920 phone versions in the repository are not used on Windows.

## Licence
The same as the rest of this repository:
- Scripts and the .theme file: MIT (`LICENSE`).
- Wallpapers: CC BY 4.0 (`LICENSE-ARTWORK`). Credit "Dexmond Technologies".
- The Dexmond name and mark are excluded from both licences.

Windows and Windows Terminal are trademarks of Microsoft Corporation. This project is not affiliated with, sponsored or endorsed by Microsoft.

## Testing
These scripts have **not** been run on a real Windows PC yet. They were checked on Linux:
- PowerShell 7 parsed both scripts with no errors.
- The Windows Terminal merge and removal steps passed a test run against sample `settings.json` files.
- The .theme file was read as an INI file.

The registry, wallpaper and colour changes themselves are not tested yet.
