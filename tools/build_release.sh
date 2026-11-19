#!/usr/bin/env bash
# Builds dist/dexmond-arctic-cyan-<version>.tar.gz and its SHA-256 file.
set -euo pipefail
cd "$(dirname "$0")/.."
V="${1:-1.1.0}"; N="dexmond-arctic-cyan-$V"
rm -rf "dist/$N"; mkdir -p "dist/$N"
cp -r README.md TESTING.md LICENSE LICENSE-ARTWORK install.sh uninstall.sh \
      gtk-3.0 gtk-4.0 terminal gtksourceview gnome-shell vscode qt chrome firefox wallpapers "dist/$N/"
[ -f "RELEASE_NOTES_$V.md" ] && cp "RELEASE_NOTES_$V.md" "dist/$N/"
[ -d "screenshots/v$V" ] && { mkdir -p "dist/$N/screenshots"; cp -r "screenshots/v$V" "dist/$N/screenshots/"; }
mkdir -p "dist/$N/tools"; cp tools/make_wallpapers.py tools/mark_mask.png tools/contrast.py "dist/$N/tools/"
tar -C dist --owner=0 --group=0 --sort=name -czf "dist/$N.tar.gz" "$N"
(cd dist && sha256sum "$N.tar.gz" > "$N.tar.gz.sha256")
rm -rf "dist/$N"; ls -la dist
