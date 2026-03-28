#!/usr/bin/env bash
#
# Import the incident-triage workflow into a running n8n instance.
#
# Usage:
#   ./import-workflow.sh                  # API method (default), reads .env
#   ./import-workflow.sh --method cli     # Docker CLI method
#   ./import-workflow.sh --api-key KEY    # override API key
#   ./import-workflow.sh --base-url URL   # override n8n URL
#   ./import-workflow.sh --container NAME # override container name (cli mode)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/../workflows/incident-triage.json"
ENV_FILE="$SCRIPT_DIR/../.env"

# Defaults
METHOD="api"
BASE_URL="http://localhost:5678"
CONTAINER_NAME="poc-n8n-n8n-1"
API_KEY=""

# Load .env if present
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
  API_KEY="${N8N_API_KEY:-}"
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --method)     METHOD="$2"; shift 2 ;;
    --api-key)    API_KEY="$2"; shift 2 ;;
    --base-url)   BASE_URL="$2"; shift 2 ;;
    --container)  CONTAINER_NAME="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Validate
if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "ERROR: Workflow file not found at: $WORKFLOW_FILE" >&2
  exit 1
fi

echo "Workflow file: $WORKFLOW_FILE"

if [[ "$METHOD" == "api" ]]; then
  # ── REST API import ──────────────────────────────────────────────
  if [[ -z "$API_KEY" ]]; then
    echo "ERROR: N8N_API_KEY not set. Add it to .env or pass --api-key KEY" >&2
    echo "       Generate one at $BASE_URL/settings/api" >&2
    exit 1
  fi

  echo "Importing via REST API to $BASE_URL ..."

  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "$BASE_URL/api/v1/workflows" \
    -H "X-N8N-API-KEY: $API_KEY" \
    -H "Content-Type: application/json" \
    -d @"$WORKFLOW_FILE")

  HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    WF_ID=$(echo "$BODY" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    WF_NAME=$(echo "$BODY" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "Workflow imported successfully!"
    echo "  ID   : $WF_ID"
    echo "  Name : $WF_NAME"
    echo "  Open : $BASE_URL/workflow/$WF_ID"
  else
    echo "ERROR: Import failed (HTTP $HTTP_CODE)" >&2
    echo "$BODY" >&2
    exit 1
  fi

elif [[ "$METHOD" == "cli" ]]; then
  # ── Docker CLI import ──────────────────────────────────────────
  CONTAINER_PATH="/tmp/incident-triage.json"

  echo "Copying workflow into container '$CONTAINER_NAME' ..."
  docker cp "$WORKFLOW_FILE" "${CONTAINER_NAME}:${CONTAINER_PATH}"

  echo "Importing via n8n CLI ..."
  docker exec -u node "$CONTAINER_NAME" n8n import:workflow --input="$CONTAINER_PATH"

  # Clean up
  docker exec "$CONTAINER_NAME" rm -f "$CONTAINER_PATH"

  echo "Workflow imported successfully!"
  echo "  Open n8n at: $BASE_URL"

else
  echo "ERROR: Unknown method '$METHOD'. Use 'api' or 'cli'." >&2
  exit 1
fi
