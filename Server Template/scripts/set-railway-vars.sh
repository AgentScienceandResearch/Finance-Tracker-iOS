#!/usr/bin/env bash
set -euo pipefail

SERVICE=""
ENVIRONMENT=""
OPENAI_API_KEY=""
OPENAI_MODEL="gpt-4.1-mini"
JWT_SECRET=""
ALLOWED_ORIGINS="https://example.com"
RATE_LIMIT_MAX="100"
DATABASE_URL=""
SKIP_DEPLOYS="false"

usage() {
  cat <<USAGE
Set required Finance Tracker AI variables in Railway.

Usage:
  ./scripts/set-railway-vars.sh \
    --openai-key <OPENAI_API_KEY> \
    [--openai-model <OPENAI_MODEL>] \
    [--jwt-secret <JWT_SECRET>] \
    [--allowed-origins <CSV_ORIGINS>] \
    [--rate-limit-max <NUMBER>] \
    [--database-url <DATABASE_URL>] \
    [--service <SERVICE_NAME>] \
    [--environment <ENVIRONMENT_NAME>] \
    [--skip-deploys]

Examples:
  ./scripts/set-railway-vars.sh --openai-key sk-... --allowed-origins https://app.example.com --service "Finance Tracker API"
  ./scripts/set-railway-vars.sh --openai-key sk-... --openai-model gpt-4.1-mini --environment production --rate-limit-max 100
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --openai-key)
      OPENAI_API_KEY="${2:-}"
      shift 2
      ;;
    --openai-model)
      OPENAI_MODEL="${2:-}"
      shift 2
      ;;
    --jwt-secret)
      JWT_SECRET="${2:-}"
      shift 2
      ;;
    --allowed-origins)
      ALLOWED_ORIGINS="${2:-}"
      shift 2
      ;;
    --rate-limit-max)
      RATE_LIMIT_MAX="${2:-}"
      shift 2
      ;;
    --database-url)
      DATABASE_URL="${2:-}"
      shift 2
      ;;
    --service)
      SERVICE="${2:-}"
      shift 2
      ;;
    --environment)
      ENVIRONMENT="${2:-}"
      shift 2
      ;;
    --skip-deploys)
      SKIP_DEPLOYS="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$OPENAI_API_KEY" ]]; then
  echo "Error: --openai-key is required."
  exit 1
fi

if [[ -z "$ALLOWED_ORIGINS" ]]; then
  echo "Error: --allowed-origins must not be empty."
  exit 1
fi

if ! [[ "$RATE_LIMIT_MAX" =~ ^[0-9]+$ ]]; then
  echo "Error: --rate-limit-max must be a positive integer."
  exit 1
fi

if ! command -v railway >/dev/null 2>&1; then
  echo "Error: Railway CLI is not installed. Install from https://docs.railway.com/develop/cli"
  exit 1
fi

if ! railway whoami >/dev/null 2>&1; then
  echo "Error: Railway CLI is not authenticated. Run: railway login"
  exit 1
fi

if [[ -z "$JWT_SECRET" ]]; then
  if command -v openssl >/dev/null 2>&1; then
    JWT_SECRET="$(openssl rand -hex 48)"
  else
    echo "Error: openssl not found and --jwt-secret was not provided."
    exit 1
  fi
fi

CMD=(railway variable set)

if [[ -n "$SERVICE" ]]; then
  CMD+=(--service "$SERVICE")
fi

if [[ -n "$ENVIRONMENT" ]]; then
  CMD+=(--environment "$ENVIRONMENT")
fi

if [[ "$SKIP_DEPLOYS" == "true" ]]; then
  CMD+=(--skip-deploys)
fi

CMD+=(
  "NODE_ENV=production"
  "OPENAI_API_KEY=$OPENAI_API_KEY"
  "OPENAI_MODEL=$OPENAI_MODEL"
  "JWT_SECRET=$JWT_SECRET"
  "ALLOWED_ORIGINS=$ALLOWED_ORIGINS"
  "RATE_LIMIT_MAX=$RATE_LIMIT_MAX"
)

if [[ -n "$DATABASE_URL" ]]; then
  CMD+=("DATABASE_URL=$DATABASE_URL")
fi

"${CMD[@]}"

echo "Set Railway variables: NODE_ENV, OPENAI_API_KEY, OPENAI_MODEL, JWT_SECRET, ALLOWED_ORIGINS, RATE_LIMIT_MAX${DATABASE_URL:+, DATABASE_URL}"
