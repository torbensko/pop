#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SPARKLE_PRIVATE_KEY:?Missing SPARKLE_PRIVATE_KEY secret}"
: "${RELEASE_VERSION:?Missing release version}"
TOOLS="$PWD/build/SourcePackages/artifacts/sparkle/Sparkle/bin"
[[ -x "$TOOLS/generate_appcast" ]]
FEED_DIR="$(mktemp -d "$PWD/dist/feed.XXXXXX")"
trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1])" "$FEED_DIR"' EXIT
cp dist/Pop.zip "$FEED_DIR/Pop.zip"
printf '%s' "$SPARKLE_PRIVATE_KEY" | "$TOOLS/generate_appcast" --ed-key-file - \
  --download-url-prefix "https://github.com/torbensko/pop/releases/download/v$RELEASE_VERSION/" \
  --maximum-deltas 0 -o "$FEED_DIR/appcast.xml" "$FEED_DIR"
cp "$FEED_DIR/appcast.xml" dist/appcast.xml
python3 - "$RELEASE_VERSION" <<'PYTHON'
import sys, xml.etree.ElementTree as ET
root = ET.parse('dist/appcast.xml')
ns = {'sparkle': 'http://www.andymatuschak.org/xml-namespaces/sparkle'}
item = root.find('./channel/item')
assert item is not None
assert item.findtext('sparkle:shortVersionString', namespaces=ns) == sys.argv[1]
enclosure = item.find('enclosure')
assert enclosure is not None
assert enclosure.get('{%s}edSignature' % ns['sparkle'])
assert enclosure.get('url') == 'https://github.com/torbensko/pop/releases/download/v' + sys.argv[1] + '/Pop.zip'
PYTHON
