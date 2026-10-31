#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
    echo "Build this app on an Apple Silicon Mac with Xcode 16 or newer." >&2
    exit 1
fi

xcodebuild \
    -project "$ROOT/Altanboard.xcodeproj" \
    -scheme Altanboard \
    -configuration Release \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$ROOT/build" \
    build

echo "App built: $ROOT/build/Build/Products/Release/Altanboard.app"
