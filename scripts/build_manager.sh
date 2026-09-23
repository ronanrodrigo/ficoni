#!/bin/bash
# build_manager.sh [--install]
#
# Builds "Ficoni Manager.app" — the SwiftUI GUI that lists, adds,
# edits and removes the sidebar icon apps — from scripts/Manager.swift.
#
# The app bundles the build script + extension sources in Contents/Resources so
# the GUI can shell out to them (a GUI process has no shell PATH).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
NAME="Ficoni Manager"
OUT="${1:-$HOME/Applications/$NAME.app}"
BUNDLE_ID="dev.ronanrodrigo.finder-sidebar-icons.manager"
WORK="$(mktemp -d)"

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"

swiftc -O -parse-as-library \
  -framework SwiftUI -framework Cocoa \
  -o "$OUT/Contents/MacOS/FiconiManager" \
  "$HERE/Manager.swift"

cp "$HERE/build_icon_app.sh" "$HERE/sync.swift" "$HERE/app.entitlements" \
   "$HERE/make_sidebar_icon.swift" "$OUT/Contents/Resources/"

# App icon: pixel-art .icns shipped in assets/ (macOS 26 masks legacy .icns
# into the squircle itself, so the art is full-bleed).
if [ -f "$ROOT/assets/AppIcon.icns" ]; then
  cp "$ROOT/assets/AppIcon.icns" "$OUT/Contents/Resources/AppIcon.icns"
fi

cat > "$OUT/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleExecutable</key><string>FiconiManager</string>
	<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>CFBundleName</key><string>$NAME</string>
	<key>CFBundleDisplayName</key><string>$NAME</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
	<key>NSHighResolutionCapable</key><true/>
</dict></plist>
EOF

IDENT=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/{print $2; exit}')
if [ -n "$IDENT" ]; then
  codesign --force --sign "$IDENT" --timestamp=none "$OUT"
  echo "signed ($IDENT)"
else
  echo "no Apple Development identity: left unsigned (fine for local use)"
fi

rm -rf "$WORK"
echo "built: $OUT"