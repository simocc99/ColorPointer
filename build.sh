#!/bin/bash
# Builds ColorPointer.app (universal: Apple Silicon + Intel) in ./build
# and packages it as a zip ready to share.
set -euo pipefail

cd "$(dirname "$0")"

swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

APP="build/ColorPointer.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS"

cp "$BIN_DIR/ColorPointer" "$APP/Contents/MacOS/ColorPointer"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

# Ad-hoc signature (no Apple Developer account needed).
codesign --force --sign - "$APP"

# Zip for sharing: the app plus the install guide for the recipient.
# ditto keeps the signature and permissions intact.
SHARE="build/ColorPointer"
mkdir -p "$SHARE"
cp -R "$APP" "$SHARE/"
cp "Resources/LEGGIMI.txt" "$SHARE/LEGGIMI.txt"
ditto -c -k --keepParent "$SHARE" "build/ColorPointer.zip"

echo "App: $(pwd)/$APP"
echo "Zip da condividere: $(pwd)/build/ColorPointer.zip"
