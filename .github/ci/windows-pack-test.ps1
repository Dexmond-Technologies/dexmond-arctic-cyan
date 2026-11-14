<#
CI test for the Windows pack (runs on a throw-away GitHub Windows runner, never on a real PC).
1. Seed a known state (light apps, no DWM AccentColor, a minimal Windows Terminal settings.json).
2. install.ps1 -WhatIf must change nothing.
3. install.ps1 must set dark mode, the #00f5ff accent and add the Terminal scheme.
4. uninstall.ps1 must put every value back exactly and restore settings.json byte for byte.
Exits non-zero on the first failed check.
#>
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$Pack = Join-Path $env:GITHUB_WORKSPACE 'windows'
$StateDir = Join-Path $env:LOCALAPPDATA 'Dexmond\ArcticCyan'
$CurrentFile = Join-Path $StateDir 'current'
$Failures = New-Object System.Collections.ArrayList

function Check([bool]$Ok, [string]$What) {
    if ($Ok) { Write-Host "PASS  $What" } else { Write-Host "FAIL  $What"; [void]$Failures.Add($What) }
}

$Personalize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$Dwm         = 'HKCU:\Software\Microsoft\Windows\DWM'
$AccentKey   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
$Desktop     = 'HKCU:\Control Panel\Desktop'
$Watched = @(
    @($Personalize, 'AppsUseLightTheme'), @($Personalize, 'SystemUsesLightTheme'),
    @($AccentKey, 'AccentPalette'), @($AccentKey, 'AccentColorMenu'), @($AccentKey, 'StartColorMenu'),
    @($Dwm, 'AccentColor'), @($Dwm, 'ColorizationColor'),
    @($Desktop, 'AutoColorization'), @($Desktop, 'WallpaperStyle'), @($Desktop, 'TileWallpaper'),
    @($Desktop, 'Wallpaper')
)

function Get-Snapshot {
    $out = [ordered]@{}
    foreach ($w in $Watched) {
        $key = "$($w[0])\$($w[1])"
        $val = 'ABSENT'
        if (Test-Path -LiteralPath $w[0]) {
            $k = Get-Item -LiteralPath $w[0]
            if ($k.GetValueNames() -contains $w[1]) {
                $kind = $k.GetValueKind($w[1]).ToString()
                $raw = $k.GetValue($w[1], $null, 'DoNotExpandEnvironmentNames')
                if ($kind -eq 'Binary') { $raw = [Convert]::ToBase64String([byte[]]$raw) }
                $val = "$kind=$raw"
            }
        }
        $out[$key] = $val
    }
    return $out
}

function Get-U32([string]$Path, [string]$Name) {
    $v = (Get-ItemProperty -LiteralPath $Path -Name $Name).$Name
    # The value can come back as Int32 (negative) or as a wider type; compare the 32-bit pattern.
    $l = [int64]$v
    if ($l -lt 0) { $l += 4294967296L }
    return $l
}

function Invoke-Pack([string]$Script, [string[]]$ScriptArgs, [switch]$NonFatal) {
    Write-Host "---- powershell $Script $($ScriptArgs -join ' ')"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Pack $Script) @ScriptArgs
    $code = $LASTEXITCODE
    if ($NonFatal) { Check ($code -eq 0) "$Script $($ScriptArgs -join ' ') exits 0 (got $code)"; return }
    if ($code -ne 0) { throw "$Script exited with $code" }
}

Write-Host "PowerShell used for the pack: Windows PowerShell 5.1 (powershell.exe)"
Write-Host "OS: $([Environment]::OSVersion.VersionString)"

# 0. Pack file hashes match windows/SHA256SUMS.
Push-Location $Pack
foreach ($line in (Get-Content -LiteralPath 'SHA256SUMS')) {
    if (-not $line.Trim()) { continue }
    $parts = $line -split '\s+', 2
    $file = $parts[1].Trim()
    $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    Check ($hash -eq $parts[0].ToLowerInvariant()) "SHA256SUMS: $file"
}
Pop-Location

# 1. Seed a known state.
if (Test-Path -LiteralPath $StateDir) { throw "unexpected: $StateDir exists before the test" }
if (-not (Test-Path -LiteralPath $Personalize)) { New-Item -Path $Personalize -Force | Out-Null }
New-ItemProperty -LiteralPath $Personalize -Name 'AppsUseLightTheme' -PropertyType DWord -Value 1 -Force | Out-Null
if ((Test-Path -LiteralPath $Dwm) -and ((Get-Item -LiteralPath $Dwm).GetValueNames() -contains 'AccentColor')) {
    Remove-ItemProperty -LiteralPath $Dwm -Name 'AccentColor' -Force
}
$TermDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal'
$TermFile = Join-Path $TermDir 'settings.json'
if (-not (Test-Path -LiteralPath $TermFile)) {
    New-Item -ItemType Directory -Path $TermDir -Force | Out-Null
    $seed = @'
{
    "$schema": "https://aka.ms/terminal-profiles-schema",
    "defaultProfile": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
    "profiles": {
        "defaults": {},
        "list": [
            { "guid": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}", "name": "Windows PowerShell", "commandline": "powershell.exe" }
        ]
    },
    "schemes": [
        { "name": "CI Existing Scheme", "background": "#000000", "foreground": "#ffffff" }
    ],
    "actions": []
}
'@
    [System.IO.File]::WriteAllText($TermFile, $seed, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "created minimal $TermFile"
}
$TermSha0 = (Get-FileHash -LiteralPath $TermFile -Algorithm SHA256).Hash
$Snap0 = Get-Snapshot
Write-Host 'Seeded state:'; $Snap0.GetEnumerator() | ForEach-Object { Write-Host "  $($_.Key) = $($_.Value)" }

# 2. -WhatIf changes nothing.
# Non-fatal: a -WhatIf crash is recorded and the install/undo checks below still run.
Invoke-Pack 'install.ps1' @('-WhatIf', '-Size', '1920x1080') -NonFatal
Check (-not (Test-Path -LiteralPath $CurrentFile)) 'WhatIf: no install record written'
Check (-not (Test-Path -LiteralPath $StateDir)) 'WhatIf: no state folder created'
$SnapW = Get-Snapshot
foreach ($k in $Snap0.Keys) { Check ($SnapW[$k] -eq $Snap0[$k]) "WhatIf: $k unchanged" }
Check ((Get-FileHash -LiteralPath $TermFile -Algorithm SHA256).Hash -eq $TermSha0) 'WhatIf: Terminal settings.json unchanged'

# 3. Install.
Invoke-Pack 'install.ps1' @('-Size', '1920x1080')
Check (Test-Path -LiteralPath $CurrentFile) 'install: record written'
Check ((Get-ItemProperty -LiteralPath $Personalize).AppsUseLightTheme -eq 0) 'install: AppsUseLightTheme = 0'
Check ((Get-ItemProperty -LiteralPath $Personalize).SystemUsesLightTheme -eq 0) 'install: SystemUsesLightTheme = 0'
Check ((Get-U32 $Dwm 'AccentColor') -eq 0xFFFFF500L) 'install: DWM AccentColor = 0xFFFFF500 (ABGR #00f5ff)'
Check ((Get-U32 $Dwm 'ColorizationColor') -eq 0xC400F5FFL) 'install: DWM ColorizationColor = 0xC400F5FF'
Check ((Get-U32 $AccentKey 'AccentColorMenu') -eq 0xFFFFF500L) 'install: AccentColorMenu = 0xFFFFF500'
$pal = [byte[]](Get-ItemProperty -LiteralPath $AccentKey).AccentPalette
Check ($pal.Length -eq 32 -and $pal[12] -eq 0x00 -and $pal[13] -eq 0xF5 -and $pal[14] -eq 0xFF) 'install: AccentPalette entry 4 = 00 F5 FF'
$term = Get-Content -LiteralPath $TermFile -Raw | ConvertFrom-Json
$names = @($term.schemes | ForEach-Object { $_.name })
Check ($names -contains 'Dexmond Arctic Cyan') 'install: Terminal scheme "Dexmond Arctic Cyan" present'
Check ($names -contains 'CI Existing Scheme') 'install: existing Terminal scheme kept'
Check (@($term.profiles.list).Count -eq 1) 'install: Terminal profiles kept'

# 4. Uninstall restores everything (-WhatIf first must change nothing).
Invoke-Pack 'uninstall.ps1' @('-WhatIf') -NonFatal
Check (Test-Path -LiteralPath $CurrentFile) 'uninstall -WhatIf: install record kept'
Invoke-Pack 'uninstall.ps1' @()
Check (-not (Test-Path -LiteralPath $CurrentFile)) 'uninstall: install record removed'
$Snap1 = Get-Snapshot
foreach ($k in $Snap0.Keys) {
    Check ($Snap1[$k] -eq $Snap0[$k]) "uninstall: $k restored (before '$($Snap0[$k])', after '$($Snap1[$k])')"
}
Check ((Get-FileHash -LiteralPath $TermFile -Algorithm SHA256).Hash -eq $TermSha0) 'uninstall: Terminal settings.json byte-identical to before'
Check (-not (Test-Path -LiteralPath (Join-Path $StateDir 'wallpapers'))) 'uninstall: wallpaper copy folder removed'

if ($Failures.Count -gt 0) {
    Write-Host "$($Failures.Count) check(s) failed:"; $Failures | ForEach-Object { Write-Host "  $_" }
    exit 1
}
Write-Host 'All checks passed.'
