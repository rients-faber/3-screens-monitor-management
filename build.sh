#!/bin/bash
# Bouwt Schermbeheer.app (universal: Apple Silicon + Intel) en een .dmg.
# Draai dit op een Mac met Xcode of de Command Line Tools: ./build.sh
set -euo pipefail

APP=Schermbeheer
VERSION="${VERSION:-1.0.0}"
cd "$(dirname "$0")"

SDK="$(xcrun --sdk macosx --show-sdk-path)"
rm -rf build
mkdir -p build

for ARCH in arm64 x86_64; do
  xcrun swiftc -O -sdk "$SDK" -target "$ARCH-apple-macos13.0" \
    -o "build/$APP-$ARCH" Sources/*.swift
done

APPDIR="build/$APP.app"
mkdir -p "$APPDIR/Contents/MacOS" "$APPDIR/Contents/Resources"
lipo -create -output "$APPDIR/Contents/MacOS/$APP" "build/$APP-arm64" "build/$APP-x86_64"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APPDIR/Contents/Info.plist"
codesign --force --deep --sign - "$APPDIR"

STAGE="build/dmg"
mkdir -p "$STAGE"
cp -R "$APPDIR" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP" -srcfolder "$STAGE" -ov -format UDZO "build/$APP-$VERSION.dmg"

echo "Klaar: build/$APP-$VERSION.dmg"
