<#
.SYNOPSIS
    Dexmond Arctic Cyan for Windows 10 and 11: installer (per user, no admin).

.DESCRIPTION
    Turns on dark mode, sets the accent colour to #00f5ff, sets a Dexmond wallpaper and
    adds the "Dexmond Arctic Cyan" colour scheme to Windows Terminal.

    Only your own user settings are changed (HKEY_CURRENT_USER and files in your own
    profile). Nothing is downloaded and nothing is sent anywhere.

    Before changing anything it saves every value it will touch in
    %LOCALAPPDATA%\Dexmond\ArcticCyan\backup-<date>\ . uninstall.ps1 puts them back.

.PARAMETER Wallpaper
    circuit (default), neural or horizon.

.PARAMETER Size
    Wallpaper size: auto (default, matches your screen), 1920x1080, 2560x1440 or 3840x2160.

.PARAMETER NoWallpaper
    Do not change the wallpaper.

.PARAMETER NoAccent
    Do not change the accent colour.

.PARAMETER NoDarkMode
    Do not change dark mode.

.PARAMETER NoTerminal
    Do not add the Windows Terminal colour scheme.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -WhatIf
    Shows what would change, changes nothing.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -Wallpaper neural
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('circuit', 'neural', 'horizon')]
    [string]$Wallpaper = 'circuit',
    [ValidateSet('auto', '1920x1080', '2560x1440', '3840x2160')]
    [string]$Size = 'auto',
    [switch]$NoWallpaper,
    [switch]$NoAccent,
    [switch]$NoDarkMode,
    [switch]$NoTerminal
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'This script is for Windows 10 and 11.' }

$SchemeName = 'Dexmond Arctic Cyan'
$StateDir   = Join-Path $env:LOCALAPPDATA 'Dexmond\ArcticCyan'
$WallDir    = Join-Path $StateDir 'wallpapers'
$Here       = $PSScriptRoot

# Accent #00f5ff. Windows stores AccentColor/AccentColorMenu as ABGR and ColorizationColor as ARGB.
$AccentR = 0x00; $AccentG = 0xF5; $AccentB = 0xFF

function ConvertTo-Dword([uint32]$Value) {
    # Registry DWORDs are written as signed Int32 by PowerShell; keep the bit pattern.
    return [BitConverter]::ToInt32([BitConverter]::GetBytes($Value), 0)
}

function Get-Abgr([int]$R, [int]$G, [int]$B) {
    return ConvertTo-Dword ([uint32](0xFF000000L -bor ([uint32]$B -shl 16) -bor ([uint32]$G -shl 8) -bor [uint32]$R))
}

function Get-Shade([int]$R, [int]$G, [int]$B, [double]$Mix, [int]$Toward) {
    # Mix the colour toward white (255) or black (0) by $Mix (0..1).
    $f = { param($c) [int][Math]::Round($c + ($Toward - $c) * $Mix) }
    return @((& $f $R), (& $f $G), (& $f $B))
}

function Get-AccentPalette {
    # 8 entries of R,G,B,0: three lighter shades, the accent, three darker shades, one extra dark.
    # Windows computes its own shades when you pick a colour in Settings; these are an approximation.
    $shades = @(
        (Get-Shade $AccentR $AccentG $AccentB 0.60 255),
        (Get-Shade $AccentR $AccentG $AccentB 0.40 255),
        (Get-Shade $AccentR $AccentG $AccentB 0.20 255),
        @($AccentR, $AccentG, $AccentB),
        (Get-Shade $AccentR $AccentG $AccentB 0.20 0),
        (Get-Shade $AccentR $AccentG $AccentB 0.40 0),
        (Get-Shade $AccentR $AccentG $AccentB 0.60 0),
        (Get-Shade $AccentR $AccentG $AccentB 0.80 0)
    )
    $bytes = New-Object byte[] 32
    for ($i = 0; $i -lt 8; $i++) {
        $bytes[$i * 4]     = [byte]$shades[$i][0]
        $bytes[$i * 4 + 1] = [byte]$shades[$i][1]
        $bytes[$i * 4 + 2] = [byte]$shades[$i][2]
        $bytes[$i * 4 + 3] = [byte]0
    }
    return ,$bytes
}

function Get-RegValue([string]$Path, [string]$Name) {
    # Returns a record of the value as it is now, including whether it exists.
    $rec = [ordered]@{ Path = $Path; Name = $Name; Exists = $false; Kind = $null; Data = $null }
    if (Test-Path -LiteralPath $Path) {
        $key = Get-Item -LiteralPath $Path
        if ($key.GetValueNames() -contains $Name) {
            $kind = $key.GetValueKind($Name).ToString()
            $raw  = $key.GetValue($Name, $null, 'DoNotExpandEnvironmentNames')
            $rec.Exists = $true
            $rec.Kind = $kind
            if ($kind -eq 'Binary') { $rec.Data = [Convert]::ToBase64String([byte[]]$raw) }
            elseif ($kind -eq 'MultiString') { $rec.Data = @($raw) }
            else { $rec.Data = $raw }
        }
    }
    return $rec
}

function Set-RegValue([string]$Path, [string]$Name, [string]$Kind, $Data, [string]$Shown) {
    if ($PSCmdlet.ShouldProcess("HKCU registry: $Path\$Name", "Set to $Shown ($Kind)")) {
        if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force -Confirm:$false | Out-Null }
        New-ItemProperty -LiteralPath $Path -Name $Name -PropertyType $Kind -Value $Data -Force -Confirm:$false | Out-Null
        Write-Host "  set $Path\$Name = $Shown"
    }
}

function Get-WallpaperSize {
    if ($Size -ne 'auto') { return $Size }
    $w = $null
    try {
        $w = (Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop |
              Where-Object { $_.CurrentHorizontalResolution } |
              Measure-Object -Property CurrentHorizontalResolution -Maximum).Maximum
    } catch { $w = $null }
    if (-not $w) {
        Write-Host "  could not read the screen width; using 3840x2160 (use -Size to choose)"
        return '3840x2160'
    }
    if ($w -le 1920) { return '1920x1080' }
    if ($w -le 2560) { return '2560x1440' }
    return '3840x2160'
}

function Find-WallpaperSource([string]$FileName) {
    foreach ($dir in @((Join-Path $Here 'wallpapers'), (Join-Path $Here '..\wallpapers'))) {
        $p = Join-Path $dir $FileName
        if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).Path }
    }
    return $null
}

function Get-TerminalSettingsPaths {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )
    return @($candidates | Where-Object { Test-Path -LiteralPath $_ })
}

function Get-FileSha256([string]$Path) {
    # Plain .NET, not Get-FileHash: under -WhatIf Get-FileHash returns nothing, and reading
    # .Hash from that stops the script in StrictMode. Reading a file changes nothing.
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $fs = [System.IO.File]::OpenRead($Path)
        try { return ([BitConverter]::ToString($sha.ComputeHash($fs))).Replace('-', '') }
        finally { $fs.Dispose() }
    } finally { $sha.Dispose() }
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Test-JsonHasComments([string]$Text) {
    # True if the text has // or /* */ comments outside strings. Rewriting such a file
    # would drop the comments, so the scripts leave it alone instead.
    $inString = $false
    for ($i = 0; $i -lt $Text.Length - 1; $i++) {
        $c = $Text[$i]
        if ($inString) {
            if ($c -eq '\') { $i++ } elseif ($c -eq '"') { $inString = $false }
        } elseif ($c -eq '"') { $inString = $true }
        elseif ($c -eq '/' -and ($Text[$i + 1] -eq '/' -or $Text[$i + 1] -eq '*')) { return $true }
    }
    return $false
}

# Adds $Scheme to the Windows Terminal settings text. Returns the new text, or $null if the
# scheme is already there. Throws if the text cannot be parsed as plain JSON (for example,
# it has comments) or if the round trip would lose top-level settings.
function Add-SchemeToSettingsText([string]$Text, $Scheme) {
    if (Test-JsonHasComments $Text) { throw 'it contains comments' }
    $obj = $Text | ConvertFrom-Json
    if ($null -eq $obj) { throw 'settings.json is empty' }
    $names = @($obj.PSObject.Properties | ForEach-Object { $_.Name })
    $existing = @()
    if ($names -contains 'schemes') { $existing = @($obj.schemes) }
    foreach ($s in $existing) {
        if ($s -and ($s.PSObject.Properties.Name -contains 'name') -and $s.name -eq $Scheme.name) { return $null }
    }
    $newList = @($existing) + @($Scheme)
    if ($names -contains 'schemes') { $obj.schemes = $newList }
    else { $obj | Add-Member -MemberType NoteProperty -Name 'schemes' -Value $newList }
    $out = ConvertTo-Json -InputObject $obj -Depth 32
    # Check the result before anyone writes it.
    $check = $out | ConvertFrom-Json
    $after = @($check.PSObject.Properties | ForEach-Object { $_.Name })
    foreach ($n in $names) { if ($after -notcontains $n) { throw "round trip lost the '$n' setting" } }
    foreach ($n in @('profiles', 'actions', 'keybindings')) {
        if ($names -notcontains $n) { continue }
        $a = $obj.$n; $b = $check.$n
        if ($a -is [array]) { if (@($b).Count -ne $a.Count) { throw "round trip changed '$n'" } }
        elseif ($a -and ($a.PSObject.Properties.Name -contains 'list')) {
            if (-not ($b -and ($b.PSObject.Properties.Name -contains 'list')) -or @($b.list).Count -ne @($a.list).Count) { throw "round trip changed '$n.list'" }
        }
    }
    $hits = @(@($check.schemes) | Where-Object { $_.name -eq $Scheme.name })
    if ($hits.Count -ne 1 -or @($check.schemes).Count -ne ($existing.Count + 1)) { throw 'round trip changed the schemes list' }
    return $out
}

function Initialize-Win32 {
    if (-not ('DexmondArcticCyan.Win32' -as [type])) {
        Add-Type -Namespace DexmondArcticCyan -Name Win32 -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, string pvParam, uint fWinIni);
[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
    }
}

function Send-SettingChange([string]$Area) {
    Initialize-Win32
    $r = [UIntPtr]::Zero
    # HWND_BROADCAST = 0xFFFF, WM_SETTINGCHANGE = 0x1A, SMTO_ABORTIFHUNG = 0x2
    [void][DexmondArcticCyan.Win32]::SendMessageTimeout([IntPtr]0xFFFF, 0x1A, [UIntPtr]::Zero, $Area, 0x2, 5000, [ref]$r)
}

# ---------------------------------------------------------------------------------------------

if ($PSVersionTable.PSVersion.Major -lt 6) {
    # Windows PowerShell 5.1 can wrap arrays as {"value":...,"Count":...} in ConvertTo-Json
    # because of extra type data on System.Array. Removing it affects this window only.
    Remove-TypeData -TypeName System.Array -ErrorAction SilentlyContinue -WhatIf:$false -Confirm:$false
}

$CurrentFile = Join-Path $StateDir 'current'
if (Test-Path -LiteralPath $CurrentFile) {
    throw "Dexmond Arctic Cyan is already installed (see $CurrentFile). Run uninstall.ps1 first."
}

$Stamp    = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupDir = Join-Path $StateDir "backup-$Stamp"

# 1. Plan the registry changes.
$Personalize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$Dwm         = 'HKCU:\Software\Microsoft\Windows\DWM'
$AccentKey   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
$Desktop     = 'HKCU:\Control Panel\Desktop'

$plan = New-Object System.Collections.ArrayList
if (-not $NoDarkMode) {
    [void]$plan.Add(@{ Path = $Personalize; Name = 'AppsUseLightTheme';    Kind = 'DWord'; Data = 0; Shown = '0 (dark apps)' })
    [void]$plan.Add(@{ Path = $Personalize; Name = 'SystemUsesLightTheme'; Kind = 'DWord'; Data = 0; Shown = '0 (dark Windows)' })
}
if (-not $NoAccent) {
    $abgr    = Get-Abgr $AccentR $AccentG $AccentB
    $palette = Get-AccentPalette
    $dark    = Get-Shade $AccentR $AccentG $AccentB 0.40 0
    $startAbgr = Get-Abgr $dark[0] $dark[1] $dark[2]
    $argb    = ConvertTo-Dword ([uint32]0xC400F5FFL)
    [void]$plan.Add(@{ Path = $AccentKey; Name = 'AccentPalette';     Kind = 'Binary'; Data = $palette;  Shown = '8 cyan shades' })
    [void]$plan.Add(@{ Path = $AccentKey; Name = 'AccentColorMenu';   Kind = 'DWord';  Data = $abgr;     Shown = '0xFFFFF500 (#00f5ff)' })
    $startShown = '0xFF{0:X2}{1:X2}{2:X2} (darker cyan)' -f $dark[2], $dark[1], $dark[0]
    [void]$plan.Add(@{ Path = $AccentKey; Name = 'StartColorMenu';    Kind = 'DWord';  Data = $startAbgr; Shown = $startShown })
    [void]$plan.Add(@{ Path = $Dwm;       Name = 'AccentColor';       Kind = 'DWord';  Data = $abgr;     Shown = '0xFFFFF500 (#00f5ff)' })
    [void]$plan.Add(@{ Path = $Dwm;       Name = 'ColorizationColor'; Kind = 'DWord';  Data = $argb;     Shown = '0xC400F5FF (#00f5ff)' })
    [void]$plan.Add(@{ Path = $Desktop;   Name = 'AutoColorization';  Kind = 'DWord';  Data = 0;         Shown = '0 (do not pick accent from wallpaper)' })
}

$wallFile = $null; $wallSrc = $null
if (-not $NoWallpaper) {
    $wsize    = Get-WallpaperSize
    $wallFile = "dexmond-$Wallpaper-$wsize.png"
    $wallSrc  = Find-WallpaperSource $wallFile
    if (-not $wallSrc) { throw "Wallpaper $wallFile not found next to this script (looked in .\wallpapers and ..\wallpapers)." }
    [void]$plan.Add(@{ Path = $Desktop; Name = 'WallpaperStyle'; Kind = 'String'; Data = '10'; Shown = '10 (fill)' })
    [void]$plan.Add(@{ Path = $Desktop; Name = 'TileWallpaper';  Kind = 'String'; Data = '0';  Shown = '0 (no tiling)' })
}

# 2. Back up everything we will touch.
$backup = [ordered]@{
    Version    = 1
    Created    = (Get-Date).ToString('o')
    Registry   = @()
    Wallpaper  = $null
    WallpaperCopied = @()
    Terminal   = @()
}
foreach ($p in $plan) {
    $rec = Get-RegValue $p.Path $p.Name
    $backup.Registry += ,$rec
    # Keep the value's existing type (for example AutoColorization may be a string on some PCs).
    if ($rec.Exists -and $rec.Kind -ne $p.Kind -and @('String', 'DWord') -contains $rec.Kind -and @('String', 'DWord') -contains $p.Kind) {
        $p.Kind = $rec.Kind
        if ($rec.Kind -eq 'String') { $p.Data = [string]$p.Data } else { $p.Data = [int]$p.Data }
    }
}
if (-not $NoWallpaper) { $backup.Wallpaper = Get-RegValue $Desktop 'Wallpaper' }

Write-Host "Dexmond Arctic Cyan: installing for user $env:USERNAME"
if ($PSCmdlet.ShouldProcess($BackupDir, 'Create backup folder and save current settings')) {
    New-Item -ItemType Directory -Path $BackupDir -Force -Confirm:$false | Out-Null
    Write-Host "  backup folder: $BackupDir"
}

# 3. Terminal: back up and prepare new settings text (written later, after the backup file).
$terminalWrites = @()
if (-not $NoTerminal) {
    $schemeFile = Join-Path $Here 'terminal\dexmond-arctic-cyan.json'
    $scheme = (Get-Content -LiteralPath $schemeFile -Raw | ConvertFrom-Json).schemes[0]
    $paths = @(Get-TerminalSettingsPaths)
    if ($paths.Count -eq 0) {
        Write-Host '  Windows Terminal settings.json not found; skipping the colour scheme.'
        Write-Host "  (You can paste the scheme by hand from $schemeFile.)"
    }
    $i = 0
    foreach ($sp in $paths) {
        $i++
        $text = [System.IO.File]::ReadAllText($sp)
        $new = $null
        try { $new = Add-SchemeToSettingsText $text $scheme }
        catch {
            Write-Host "  could not read $sp as plain JSON ($($_.Exception.Message)); it was NOT changed."
            Write-Host "  Paste the scheme from $schemeFile into its ""schemes"" list by hand."
            continue
        }
        if ($null -eq $new) { Write-Host "  $sp already has the '$SchemeName' scheme; not changed."; continue }
        $copyName = "terminal-settings-$i.json"
        $terminalWrites += ,@{ Path = $sp; Text = $new; Copy = (Join-Path $BackupDir $copyName) }
        $backup.Terminal += ,([ordered]@{ Path = $sp; BackupCopy = $copyName; OriginalSha256 = (Get-FileSha256 $sp); InstalledSha256 = $null })
    }
}

foreach ($tw in $terminalWrites) {
    if ($PSCmdlet.ShouldProcess($tw.Path, "Copy to $($tw.Copy) (backup)")) {
        Copy-Item -LiteralPath $tw.Path -Destination $tw.Copy -Force -Confirm:$false
    }
}

$backupJson = Join-Path $BackupDir 'backup.json'
function Save-Backup {
    if ($PSCmdlet.ShouldProcess($backupJson, 'Write backup record')) {
        Write-Utf8NoBom $backupJson (ConvertTo-Json -InputObject $backup -Depth 8)
    }
}
Save-Backup
if ($PSCmdlet.ShouldProcess($CurrentFile, "Record $BackupDir as the current install")) {
    Write-Utf8NoBom $CurrentFile $BackupDir
}

# 4. Apply.
Write-Host 'Changes:'
foreach ($p in $plan) { Set-RegValue $p.Path $p.Name $p.Kind $p.Data $p.Shown }

if (-not $NoWallpaper) {
    $dest = Join-Path $WallDir $wallFile
    if ($PSCmdlet.ShouldProcess($dest, "Copy wallpaper from $wallSrc")) {
        New-Item -ItemType Directory -Path $WallDir -Force -Confirm:$false | Out-Null
        Copy-Item -LiteralPath $wallSrc -Destination $dest -Force -Confirm:$false
        $backup.WallpaperCopied += $dest
        Save-Backup
        Write-Host "  copied wallpaper to $dest"
    }
    if ($PSCmdlet.ShouldProcess("HKCU registry: $Desktop\Wallpaper", "Set desktop wallpaper to $dest")) {
        Initialize-Win32
        # SPI_SETDESKWALLPAPER = 0x14, SPIF_UPDATEINIFILE | SPIF_SENDWININICHANGE = 0x3
        if (-not [DexmondArcticCyan.Win32]::SystemParametersInfo(0x14, 0, $dest, 0x3)) {
            Write-Host "  WARNING: Windows did not accept the wallpaper (error $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))."
        } else { Write-Host "  set wallpaper = $dest" }
    }
}

foreach ($tw in $terminalWrites) {
    if ($PSCmdlet.ShouldProcess($tw.Path, "Add the '$SchemeName' colour scheme")) {
        Write-Utf8NoBom $tw.Path $tw.Text
        foreach ($t in $backup.Terminal) { if ($t.Path -eq $tw.Path) { $t.InstalledSha256 = (Get-FileSha256 $tw.Path) } }
        Save-Backup
        Write-Host "  added colour scheme '$SchemeName' to $($tw.Path)"
    }
}

if ($plan.Count -gt 0 -and $PSCmdlet.ShouldProcess('Windows', 'Tell open windows that colours changed')) {
    Send-SettingChange 'ImmersiveColorSet'
}

if ($WhatIfPreference) {
    Write-Host 'WhatIf: nothing was changed.'
} else {
    Write-Host 'Done. If the taskbar or Start menu colours do not update, sign out and back in.'
    if ($terminalWrites.Count -gt 0) {
        Write-Host "In Windows Terminal: Settings > (your profile) > Appearance > Color scheme > $SchemeName."
    }
    Write-Host 'To undo: powershell -ExecutionPolicy Bypass -File .\uninstall.ps1'
}
