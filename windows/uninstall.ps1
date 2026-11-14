<#
.SYNOPSIS
    Dexmond Arctic Cyan for Windows 10 and 11: uninstaller.

.DESCRIPTION
    Puts back every setting install.ps1 saved in %LOCALAPPDATA%\Dexmond\ArcticCyan\backup-<date>\ :
    values that existed get their old type and data back, values that did not exist are removed.
    It also removes the wallpaper copy and the "Dexmond Arctic Cyan" Windows Terminal scheme.

.PARAMETER Force
    Restore the Windows Terminal settings.json backup even if the file was edited after install.
    Without -Force an edited file is kept and only the Dexmond scheme is taken out of it.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -WhatIf
    Shows what would be restored, changes nothing.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Force
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'This script is for Windows 10 and 11.' }

$SchemeName  = 'Dexmond Arctic Cyan'
$StateDir    = Join-Path $env:LOCALAPPDATA 'Dexmond\ArcticCyan'
$CurrentFile = Join-Path $StateDir 'current'

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
    [void][DexmondArcticCyan.Win32]::SendMessageTimeout([IntPtr]0xFFFF, 0x1A, [UIntPtr]::Zero, $Area, 0x2, 5000, [ref]$r)
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-FileSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Restore-RegValue($Rec) {
    $path = [string]$Rec.Path; $name = [string]$Rec.Name
    if ($Rec.Exists) {
        $kind = [string]$Rec.Kind
        $data = $Rec.Data
        $shown = [string]$data
        if ($kind -eq 'Binary') { $data = [Convert]::FromBase64String([string]$Rec.Data); $shown = "$($data.Length) bytes" }
        elseif ($kind -eq 'MultiString') { $data = [string[]]@($Rec.Data); $shown = ($data -join '; ') }
        elseif ($kind -eq 'DWord') { $data = [int]$Rec.Data }
        elseif ($kind -eq 'QWord') { $data = [long]$Rec.Data }
        else { $data = [string]$Rec.Data }
        if ($PSCmdlet.ShouldProcess("HKCU registry: $path\$name", "Restore to $shown ($kind)")) {
            if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force -Confirm:$false | Out-Null }
            New-ItemProperty -LiteralPath $path -Name $name -PropertyType $kind -Value $data -Force -Confirm:$false | Out-Null
            Write-Host "  restored $path\$name = $shown"
        }
    } else {
        $present = $false
        if (Test-Path -LiteralPath $path) { $present = (Get-Item -LiteralPath $path).GetValueNames() -contains $name }
        if ($present -and $PSCmdlet.ShouldProcess("HKCU registry: $path\$name", 'Remove (it did not exist before install)')) {
            Remove-ItemProperty -LiteralPath $path -Name $name -Force -Confirm:$false
            Write-Host "  removed $path\$name (it did not exist before)"
        }
    }
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

# Removes the Dexmond scheme from settings text. Returns new text, or $null if it is not there.
function Remove-SchemeFromSettingsText([string]$Text) {
    if (Test-JsonHasComments $Text) { throw 'it contains comments' }
    $obj = $Text | ConvertFrom-Json
    if ($null -eq $obj -or -not ($obj.PSObject.Properties.Name -contains 'schemes')) { return $null }
    $before = @($obj.schemes)
    $keep = @($before | Where-Object { -not ($_ -and ($_.PSObject.Properties.Name -contains 'name') -and $_.name -eq $SchemeName) })
    if ($keep.Count -eq $before.Count) { return $null }
    $names = @($obj.PSObject.Properties | ForEach-Object { $_.Name })
    $obj.schemes = $keep
    $out = ConvertTo-Json -InputObject $obj -Depth 32
    $check = $out | ConvertFrom-Json
    $after = @($check.PSObject.Properties | ForEach-Object { $_.Name })
    foreach ($n in $names) { if ($after -notcontains $n) { throw "round trip lost the '$n' setting" } }
    if (@($check.schemes).Count -ne $keep.Count) { throw 'round trip changed the schemes list' }
    return $out
}

# ---------------------------------------------------------------------------------------------

if ($PSVersionTable.PSVersion.Major -lt 6) {
    Remove-TypeData -TypeName System.Array -ErrorAction SilentlyContinue -WhatIf:$false -Confirm:$false
}

if (-not (Test-Path -LiteralPath $CurrentFile)) {
    throw "Dexmond Arctic Cyan is not installed (no record at $CurrentFile)."
}
$BackupDir  = ([System.IO.File]::ReadAllText($CurrentFile)).Trim()
$backupJson = Join-Path $BackupDir 'backup.json'
if (-not (Test-Path -LiteralPath $backupJson)) { throw "Backup record $backupJson is missing; nothing restored." }
$backup = [System.IO.File]::ReadAllText($backupJson) | ConvertFrom-Json

Write-Host "Dexmond Arctic Cyan: restoring your settings from $BackupDir"

# 1. Registry values, exactly as they were.
foreach ($rec in @($backup.Registry)) { if ($rec) { Restore-RegValue $rec } }

# 2. Wallpaper: put the old path back through Windows (after the style values above).
if ($backup.Wallpaper) {
    $old = ''
    if ($backup.Wallpaper.Exists) { $old = [string]$backup.Wallpaper.Data }
    $label = $old; if ($old -eq '') { $label = '(none)' }
    if ($PSCmdlet.ShouldProcess("HKCU registry: Control Panel\Desktop\Wallpaper", "Restore wallpaper to $label")) {
        Initialize-Win32
        $expanded = [Environment]::ExpandEnvironmentVariables($old)
        if ([DexmondArcticCyan.Win32]::SystemParametersInfo(0x14, 0, $expanded, 0x3)) {
            Write-Host "  restored wallpaper = $label"
        } else {
            Write-Host "  WARNING: Windows did not accept $label (error $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))."
            Write-Host '  The registry value is restored; pick a wallpaper in Settings > Personalisation if the desktop looks wrong.'
        }
        Restore-RegValue $backup.Wallpaper
    }
}
foreach ($f in @($backup.WallpaperCopied)) {
    if ($f -and (Test-Path -LiteralPath $f) -and $PSCmdlet.ShouldProcess($f, 'Delete wallpaper copy')) {
        Remove-Item -LiteralPath $f -Force -Confirm:$false
        Write-Host "  deleted $f"
    }
}
$wallDir = Join-Path $StateDir 'wallpapers'
if ((Test-Path -LiteralPath $wallDir) -and -not (Get-ChildItem -LiteralPath $wallDir -Force) -and $PSCmdlet.ShouldProcess($wallDir, 'Delete empty folder')) {
    Remove-Item -LiteralPath $wallDir -Force -Confirm:$false
}

# 3. Windows Terminal.
foreach ($t in @($backup.Terminal)) {
    if (-not $t) { continue }
    $sp = [string]$t.Path
    $copy = Join-Path $BackupDir ([string]$t.BackupCopy)
    if (-not (Test-Path -LiteralPath $sp)) { Write-Host "  $sp no longer exists; skipped."; continue }
    $unchanged = $t.InstalledSha256 -and ((Get-FileSha256 $sp) -eq [string]$t.InstalledSha256)
    if (($unchanged -or $Force) -and (Test-Path -LiteralPath $copy)) {
        if ($PSCmdlet.ShouldProcess($sp, "Restore from backup $copy")) {
            Copy-Item -LiteralPath $copy -Destination $sp -Force -Confirm:$false
            Write-Host "  restored $sp from the backup"
        }
        continue
    }
    Write-Host "  $sp was edited after install; keeping your edits and only removing the '$SchemeName' scheme."
    $new = $null
    try { $new = Remove-SchemeFromSettingsText ([System.IO.File]::ReadAllText($sp)) }
    catch {
        Write-Host "  could not read it as plain JSON ($($_.Exception.Message)); it was NOT changed."
        Write-Host "  Remove the '$SchemeName' entry by hand, or run uninstall.ps1 -Force to restore $copy."
        continue
    }
    if ($null -eq $new) { Write-Host "  the scheme is not in $sp; nothing to remove."; continue }
    $keepCopy = Join-Path $BackupDir ('before-uninstall-' + [string]$t.BackupCopy)
    if ($PSCmdlet.ShouldProcess($sp, "Save a copy to $keepCopy, then remove the '$SchemeName' scheme")) {
        Copy-Item -LiteralPath $sp -Destination $keepCopy -Force -Confirm:$false
        Write-Utf8NoBom $sp $new
        Write-Host "  removed the scheme from $sp (copy of your version: $keepCopy)"
        if (([System.IO.File]::ReadAllText($sp)).Contains($SchemeName)) {
            Write-Host "  NOTE: a profile still names '$SchemeName' as its colour scheme; choose another one in Terminal settings."
        }
    }
}

if ($PSCmdlet.ShouldProcess('Windows', 'Tell open windows that colours changed')) {
    Send-SettingChange 'ImmersiveColorSet'
}
if ($PSCmdlet.ShouldProcess($CurrentFile, 'Mark the theme as uninstalled')) {
    Remove-Item -LiteralPath $CurrentFile -Force -Confirm:$false
}

if ($WhatIfPreference) {
    Write-Host 'WhatIf: nothing was changed.'
} else {
    Write-Host "Done. Your previous settings are back. The backup stays in $BackupDir; you can delete it."
    Write-Host 'If the taskbar or Start menu colours look wrong, sign out and back in.'
}
