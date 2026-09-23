#!/bin/bash
# build_icon_app.sh <Name> <TargetFolder> <BundleIdSuffix> <SFSymbol> [systemIcns]
#
# Builds a signed Finder Sync helper app whose icon becomes the sidebar icon of
# <TargetFolder> in the macOS Finder sidebar.
#
# Icon modes:
#   SYMBOLMODE=1 (default)  native sidebar look: CFBundleSymbolName, no .icns.
#                           The sidebar draws a bare tinted glyph, exactly like
#                           Finder's own rows.
#   SYMBOLMODE=0            classic app-icon route: either the CoreTypes .icns
#                           passed as the 5th arg (standard Finder folder icon)
#                           or a generated squircle .iconset built from the SF
#                           Symbol. macOS 26+ draws its Tahoe plate behind it.
#
# Env:
#   BUNDLE_PREFIX   bundle-id prefix (default dev.ronanrodrigo.findericon)
#   SYMBOLMODE      1 | 0, see above
#   OUT             install dir (default ~/Applications/Ficoni)
set -e
TAB=$'\t'
NAME="$1"; TARGET="$2"; SUFFIX="$3"; SYMBOL="$4"; SYSICNS="$5"

if [ -z "$NAME" ] || [ -z "$TARGET" ] || [ -z "$SUFFIX" ] || [ -z "$SYMBOL" ]; then
  echo "usage: [SYMBOLMODE=1] $0 <Name> <TargetFolder> <BundleIdSuffix> <SFSymbol> [systemIcns]" >&2
  exit 2
fi

if [ -z "${SYMBOLMODE:-}" ]; then
  if [ -n "$SYSICNS" ]; then SYMBOLMODE=0; else SYMBOLMODE=1; fi
fi

if [ "$SYMBOLMODE" = "1" ]; then
  ICONBLOCK="${TAB}<key>CFBundleIcons</key><dict><key>CFBundlePrimaryIcon</key><dict><key>CFBundleSymbolName</key><string>$SYMBOL</string></dict></dict>"
else
  ICONBLOCK="${TAB}<key>CFBundleIconFile</key><string>AppIcon</string>"
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${OUT:-$HOME/Applications/Ficoni}"
APP="$OUT/$NAME.app"
APPID="${BUNDLE_PREFIX:-dev.ronanrodrigo.findericon}.$SUFFIX"
EXTID="$APPID.sync"
WORK="$(mktemp -d)"
ENT="$HERE/app.entitlements"
LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# Apple Development identity preferred; ad-hoc signing often leaves the
# extension undiscovered by pkd.
IDENT=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/{print $2; exit}')
[ -n "$IDENT" ] || IDENT="-"

# Unregister the previous build before overwriting it.
pluginkit -r "$APP/Contents/PlugIns/SidebarSync.appex" 2>/dev/null || true
"$LSR" -u "$APP" 2>/dev/null || true

rm -rf "$APP"
mkdir -p "$OUT" "$APP/Contents/MacOS" "$APP/Contents/Resources"
mkdir -p "$APP/Contents/PlugIns/SidebarSync.appex/Contents/MacOS"

# Icons: the sidebar shows the CONTAINING APP's icon.
if [ "$SYMBOLMODE" = "1" ]; then
  : # symbol declared in Info.plist; an .icns would add the Tahoe app-icon plate
elif [ -n "$SYSICNS" ]; then
  cp "$SYSICNS" "$APP/Contents/Resources/AppIcon.icns"   # standard Finder/CoreTypes icon
else
  swiftc -O -o "$WORK/mksidebar" "$HERE/make_sidebar_icon.swift"
  "$WORK/mksidebar" "$SYMBOL" "$WORK/$NAME.iconset"
  cp -R "$WORK/$NAME.iconset" "$APP/Contents/Resources/$NAME.iconset"
  iconutil -c icns "$WORK/$NAME.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
fi

# The helper app itself never has to run: the extension is what macOS loads.
printf 'import Foundation\nexit(0)\n' > "$WORK/main.swift"
swiftc -O -o "$APP/Contents/MacOS/$NAME" "$WORK/main.swift"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleExecutable</key><string>$NAME</string>
	<key>CFBundleIdentifier</key><string>$APPID</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>CFBundleName</key><string>$NAME</string>
	<key>CFBundleDisplayName</key><string>$NAME</string>
$ICONBLOCK
	<key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
EOF

sed "s|__TARGET__|$TARGET|" "$HERE/sync.swift" > "$WORK/sync.swift"
swiftc -O -framework Cocoa -framework FinderSync -Xlinker -e -Xlinker _NSExtensionMain \
  -o "$APP/Contents/PlugIns/SidebarSync.appex/Contents/MacOS/SidebarSync" "$WORK/sync.swift"

cat > "$APP/Contents/PlugIns/SidebarSync.appex/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleExecutable</key><string>SidebarSync</string>
	<key>CFBundleIdentifier</key><string>$EXTID</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>CFBundleName</key><string>SidebarSync</string>
	<key>CFBundleDisplayName</key><string>SidebarSync</string>
	<key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
	<key>CFBundlePackageType</key><string>XPC!</string>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
	<key>DTPlatformName</key><string>macosx</string>
	<key>NSExtension</key><dict>
		<key>NSExtensionAttributes</key><dict/>
		<key>NSExtensionPointIdentifier</key><string>com.apple.FinderSync</string>
		<key>NSExtensionPrincipalClass</key><string>SyncExtension</string>
	</dict>
</dict></plist>
EOF

# Appex first, then the app. Never --deep (it breaks extension registration).
codesign --force --sign "$IDENT" --entitlements "$ENT" --timestamp=none "$APP/Contents/PlugIns/SidebarSync.appex"
codesign --force --sign "$IDENT" --entitlements "$ENT" --timestamp=none "$APP"
echo "built+signed ($IDENT): $APP"

# Register and refresh: pkd for a brand-new extension, then Finder for the UI.
"$LSR" -f "$APP"
pluginkit -a "$APP/Contents/PlugIns/SidebarSync.appex" || true
pluginkit -e use -i "$EXTID" || true
killall pkd 2>/dev/null || true
sleep 3
killall Finder 2>/dev/null || true
pluginkit -m -A -D -p com.apple.FinderSync | grep "$EXTID" \
  || echo "WARNING: $EXTID not discovered by pkd"

rm -rf "$WORK"