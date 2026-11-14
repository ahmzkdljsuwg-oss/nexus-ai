#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

command -v xcodegen >/dev/null || { echo "xcodegen is required: brew install xcodegen"; exit 1; }
xcodegen generate

xcodebuild -project NexusAI.xcodeproj -scheme NexusAI \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/NexusAI.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" archive

rm -rf build/Payload
mkdir -p build/Payload
cp -R build/NexusAI.xcarchive/Products/Applications/NexusAI.app build/Payload/
ditto -c -k --sequesterRsrc --keepParent build/Payload build/NexusAI-unsigned.ipa

unzip -l build/NexusAI-unsigned.ipa | grep -q 'Payload/NexusAI.app/Info.plist'
echo "Created $ROOT/build/NexusAI-unsigned.ipa (unsigned; sign it with ESign or a developer certificate)"
