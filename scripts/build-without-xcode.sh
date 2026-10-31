#!/bin/bash
set -euo pipefail

# Build a local app using Apple's Command Line Tools, without Xcode or an account.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build-command-line"
APP="$BUILD/Altanboard.app"

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
    echo "This app requires an Apple Silicon Mac (M1 or newer)." >&2
    exit 1
fi

mkdir -p "$BUILD/modules" "$APP/Contents/MacOS"

echo "Building the drawing library..."
xcrun swiftc \
    -swift-version 6 -target arm64-apple-macosx13.0 -O \
    -module-cache-path "$BUILD/modules" \
    -parse-as-library -emit-library -static -emit-module \
    -module-name WhiteboardCore \
    -emit-module-path "$BUILD/WhiteboardCore.swiftmodule" \
    "$ROOT"/Sources/WhiteboardCore/*.swift \
    -o "$BUILD/libWhiteboardCore.a"

echo "Building the app..."
xcrun swiftc \
    -swift-version 6 -target arm64-apple-macosx13.0 -O \
    -module-cache-path "$BUILD/modules" \
    -parse-as-library -I "$BUILD" -L "$BUILD" -lWhiteboardCore \
    "$ROOT"/Altanboard/*.swift \
    -o "$APP/Contents/MacOS/Altanboard"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Altanboard</string>
    <key>CFBundleIdentifier</key><string>local.altanboard.app</string>
    <key>CFBundleName</key><string>Altanboard</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# Local signing uses no Apple account or certificate.
codesign --force --sign - \
    --entitlements "$ROOT/Altanboard/Altanboard.entitlements" "$APP"

echo "Ready! Double-click Altanboard in the folder that opens."
open -R "$APP"
