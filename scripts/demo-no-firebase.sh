#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -d "IOSAppTemplate.xcodeproj" ]; then
  xcodegen generate --spec project.yml
fi

DESTINATION="platform=iOS Simulator,name=iPhone 17"

xcodebuild \
  -project IOSAppTemplate.xcodeproj \
  -scheme TemplateApp \
  -configuration Debug \
  -destination "$DESTINATION" \
  build
