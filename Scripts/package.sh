#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-release}"
[[ "$MODE" == release || "$MODE" == --unsigned ]] || { echo 'Usage: Scripts/package.sh [--unsigned]' >&2; exit 1; }
if [[ "$MODE" == release ]]; then
  : "${SIGNING_IDENTITY:?Developer ID Application signing identity is required}"
  : "${APPLE_ID:?Missing APPLE_ID}"
  : "${APPLE_ID_PASSWORD:?Missing APPLE_ID_PASSWORD}"
  : "${APPLE_TEAM_ID:?Missing APPLE_TEAM_ID}"
  [[ "$SIGNING_IDENTITY" == 'Developer ID Application:'* ]] || exit 1
fi
xcodebuild -project Pop.xcodeproj -scheme Pop -configuration Release -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
APP="$PWD/build/Build/Products/Release/Pop.app"
mkdir -p dist
STAGE="$(mktemp -d "$PWD/dist/package.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
notarize() {
  xcrun notarytool submit "$1" --apple-id "$APPLE_ID" --password "$APPLE_ID_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" --wait --timeout 30m --output-format json > "$2"
  python3 - "$2" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
if result.get('status') != 'Accepted':
    sys.exit(f"Notarization failed: {result.get('id')} {result.get('status')}")
PY
}
SUFFIX='-unsigned'
if [[ "$MODE" == release ]]; then
  SUFFIX=''
  codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
  codesign --verify --deep --strict "$APP"
  ditto -c -k --keepParent "$APP" "$STAGE/submission.zip"
  notarize "$STAGE/submission.zip" "$PWD/dist/notary-app.json"
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  spctl --assess --type execute --verbose "$APP"
else
  codesign --force --sign - "$APP"
fi
mkdir -p "$STAGE/image"
ditto "$APP" "$STAGE/image/Pop.app"
ln -s /Applications "$STAGE/image/Applications"
cp README.md "$STAGE/image/README.md"
DMG="$PWD/dist/Pop${SUFFIX}.dmg"
ZIP="$PWD/dist/Pop${SUFFIX}.zip"
hdiutil create -volname Pop -srcfolder "$STAGE/image" -ov -format UDZO "$DMG"
if [[ "$MODE" == release ]]; then
  codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG"
  notarize "$DMG" "$PWD/dist/notary-dmg.json"
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
fi
ditto -c -k --keepParent "$APP" "$ZIP"
(cd dist && shasum -a 256 "Pop${SUFFIX}.dmg" "Pop${SUFFIX}.zip" > "SHA256SUMS${SUFFIX}.txt")
