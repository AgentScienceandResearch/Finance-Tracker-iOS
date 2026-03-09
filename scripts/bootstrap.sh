#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen not found. Install with: brew install xcodegen"
  exit 1
fi

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "swiftlint not found. Install with: brew install swiftlint"
fi

if ! command -v swiftformat >/dev/null 2>&1; then
  echo "swiftformat not found. Install with: brew install swiftformat"
fi

xcodegen generate --spec project.yml

if [ ! -f "App Template/.env" ]; then
  cp "App Template/.env.example" "App Template/.env"
  echo "Created App Template/.env from template"
fi

echo "Bootstrap complete. Open IOSAppTemplate.xcodeproj or IOSAppTemplate.xcworkspace"
