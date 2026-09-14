#!/bin/bash
# Builds Chameleon.app into ~/Applications
set -euo pipefail
cd "$(dirname "$0")"

APP="$HOME/Applications/Chameleon.app"
BIN="$APP/Contents/MacOS/Chameleon"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Compiling…"
swiftc -O -swift-version 5 -target arm64-apple-macos14.0 \
       -o "$BIN" Sources/*.swift

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>              <string>Chameleon</string>
  <key>CFBundleDisplayName</key>       <string>Chameleon</string>
  <key>CFBundleExecutable</key>        <string>Chameleon</string>
  <key>CFBundleIdentifier</key>        <string>local.chameleon</string>
  <key>CFBundlePackageType</key>       <string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key>           <string>1</string>
  <key>CFBundleIconFile</key>          <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>    <string>14.0</string>
  <key>NSHighResolutionCapable</key>   <true/>
  <key>LSApplicationCategoryType</key> <string>public.app-category.video</string>
</dict>
</plist>
PLIST

if [ -f AppIcon.icns ]; then
  cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
touch "$APP"   # nudge Finder to refresh the icon

echo "Built: $APP"
