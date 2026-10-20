#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_BINARY="$(mktemp -t pop-tests)"
trap 'rm -f "$TEST_BINARY"' EXIT
swiftc Pop/Index.swift Pop/UsageStore.swift Pop/Calculator.swift Tests/main.swift -o "$TEST_BINARY"
"$TEST_BINARY"
xcodebuild -project Pop.xcodeproj -scheme Pop -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
