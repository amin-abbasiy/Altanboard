#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
    echo "Native UI tests require an Apple Silicon Mac with Xcode 16 or newer." >&2
    echo "The portable drawing tests can run here with: swift test" >&2
    exit 1
fi

xcodebuild \
    -project "$ROOT/Altanboard.xcodeproj" \
    -scheme Altanboard \
    -configuration Debug \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$ROOT/build" \
    test
