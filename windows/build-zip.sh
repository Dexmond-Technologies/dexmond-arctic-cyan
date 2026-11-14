#!/usr/bin/env bash
# Builds dist/dexmond-arctic-cyan-windows-<version>.zip (plain zip, not a .deskthemepack) and its SHA-256 file.
# The zip holds the scripts, the .theme file, the Terminal scheme, the licences and the
# desktop-size wallpapers from ../wallpapers (copied as they are, not regenerated).
set -euo pipefail
cd "$(dirname "$0")/.."
V="${1:-1.0.0}"; N="dexmond-arctic-cyan-windows-$V"
rm -rf "dist/$N" "dist/$N.zip"; mkdir -p "dist/$N/wallpapers" "dist/$N/terminal"
cp windows/install.ps1 windows/uninstall.ps1 windows/DexmondArcticCyan.theme windows/README.md "dist/$N/"
cp windows/terminal/dexmond-arctic-cyan.json "dist/$N/terminal/"
cp LICENSE LICENSE-ARTWORK "dist/$N/"
for d in circuit neural horizon; do for s in 1920x1080 2560x1440 3840x2160; do
  cp "wallpapers/dexmond-$d-$s.png" "dist/$N/wallpapers/"
done; done
(cd "dist/$N" && find . -type f ! -name SHA256SUMS -printf '%P\n' | LC_ALL=C sort | xargs -d '\n' sha256sum > SHA256SUMS)
find "dist/$N" -exec touch -d '2026-11-14 00:00:00 UTC' {} +
(cd dist && find "$N" -print | LC_ALL=C sort | zip -X -q -9 -n .png "$N.zip" -@)
(cd dist && sha256sum "$N.zip" > "$N.zip.sha256")
rm -rf "dist/$N"; ls -la dist
