#!/bin/bash
# Regenerates AppIcon.png and AppIcon.icns from MakeIcon.swift
set -euo pipefail
cd "$(dirname "$0")"

swift MakeIcon.swift

rm -rf AppIcon.iconset && mkdir AppIcon.iconset
for sz in 16 32 128 256 512; do
  sips -z $sz $sz AppIcon.png --out "AppIcon.iconset/icon_${sz}x${sz}.png" >/dev/null
  sips -z $((sz*2)) $((sz*2)) AppIcon.png --out "AppIcon.iconset/icon_${sz}x${sz}@2x.png" >/dev/null
done
iconutil -c icns AppIcon.iconset -o AppIcon.icns
rm -rf AppIcon.iconset
echo "Built AppIcon.icns"
