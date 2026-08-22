#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -d "FinanceTrackeriOS.xcodeproj" ]; then
  xcodegen generate --spec project.yml
fi

DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro Max"

xcodebuild \
  -project FinanceTrackeriOS.xcodeproj \
  -scheme FinanceTrackerAI \
  -configuration Debug \
  -destination "$DESTINATION" \
  build
