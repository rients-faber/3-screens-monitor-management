#!/bin/bash
# Bouwt Schermbeheer.app (universal: Apple Silicon + Intel) en een .dmg.
# Draai dit op een Mac met Xcode of de Command Line Tools: ./build.sh
set -euo pipefail

APP=Schermbeheer
VERSION="${VERSION:-$(cat VERSION 2>/dev/null || echo 1.0.0)}"
cd "$(dirname "$0")"

SDK="$(xcrun --sdk macosx --show-sdk-path)"
rm -rf build
mkdir -p build

for ARCH in arm64 x86_64; do
  xcrun swiftc -O -parse-as-library -sdk "$SDK" -target "$ARCH-apple-macos13.0" \
    -o "build/$APP-$ARCH" Sources/*.swift
done

APPDIR="build/$APP.app"
mkdir -p "$APPDIR/Contents/MacOS" "$APPDIR/Contents/Resources"
lipo -create -output "$APPDIR/Contents/MacOS/$APP" "build/$APP-arm64" "build/$APP-x86_64"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APPDIR/Contents/Info.plist"

# App-icoon (.icns) maken uit Resources/AppIcon.png
ICONSET="build/AppIcon.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
  sips -z $SIZE $SIZE Resources/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE=$((SIZE * 2))
  sips -z $DOUBLE $DOUBLE Resources/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APPDIR/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APPDIR"

STAGE="build/dmg"
mkdir -p "$STAGE"
cp -R "$APPDIR" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP" -srcfolder "$STAGE" -ov -format UDZO "build/$APP-$VERSION.dmg"

echo "Klaar: build/$APP-$VERSION.dmg"
