#!/usr/bin/env bash
#
# Full POC setup: imports the workflow, creates all n8n credentials,
# and wires up every node with the correct channel IDs, project IDs, and URLs.
#
# Usage:
#   ./import-workflow.sh          # reads all values from .env
#
# Requirements: curl, jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/../workflows/incident-triage.json"
ENV_FILE="$SCRIPT_DIR/../.env"

# ── Load .env ─────────────────────────────────────────────────────────────────
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
fi

BASE_URL="${N8N_BASE_URL:-http://localhost:5678}"

# ── Check dependencies ────────────────────────────────────────────────────────
for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' is required but not installed." >&2; exit 1
  fi
done

# ── Validate required vars ────────────────────────────────────────────────────
required=(N8N_API_KEY SLACK_ACCESS_TOKEN JIRA_EMAIL JIRA_API_TOKEN JIRA_DOMAIN
          JIRA_PROJECT_KEY GITHUB_PAT GITHUB_OWNER GITHUB_REPO SLACK_CHANNEL_NAME)
for var in "${required[@]}"; do
  val="${!var:-}"
  if [[ -z "$val" || "$val" == *"your-"* ]]; then
    echo "ERROR: $var is missing or still a placeholder in .env" >&2; exit 1
  fi
done

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "ERROR: Workflow file not found: $WORKFLOW_FILE" >&2; exit 1
fi

# ── Check n8n is reachable ────────────────────────────────────────────────────
if ! curl -sf "$BASE_URL/healthz" > /dev/null 2>&1; then
  echo "ERROR: n8n is not reachable at $BASE_URL" >&2
  echo "       Run 'docker compose up -d' and wait a few seconds." >&2
  exit 1
fi

N8N_HEADERS=(-H "X-N8N-API-KEY: $N8N_API_KEY" -H "Content-Type: application/json")

# ── Helper: call n8n API ──────────────────────────────────────────────────────
n8n() {
  local method="$1" path="$2"; shift 2
  curl -sf -X "$method" "$BASE_URL/api/v1$path" "${N8N_HEADERS[@]}" "$@"
}

# ── Helper: create credential or return existing ID ───────────────────────────
upsert_credential() {
  local name="$1" type="$2" data="$3"
  local existing
  existing=$(n8n GET "/credentials" | jq -r --arg n "$name" \
    '.data[] | select(.name == $n) | .id // empty' 2>/dev/null || true)
  if [[ -n "$existing" ]]; then
    echo "$existing"; return
  fi
  local payload
  payload=$(jq -n --arg n "$name" --arg t "$type" --argjson d "$data" \
    '{name: $n, type: $t, data: $d}')
  n8n POST "/credentials" -d "$payload" | jq -r '.id'
}

# ── Step 1: Create credentials ────────────────────────────────────────────────
echo ""
echo "==> [1/5] Creating n8n credentials ..."

SLACK_CRED_ID=$(upsert_credential "Slack - POC" "slackApi" \
  "$(jq -n --arg t "$SLACK_ACCESS_TOKEN" '{accessToken: $t}')")
echo "    Slack  : $SLACK_CRED_ID"

JIRA_CRED_ID=$(upsert_credential "Jira - POC" "jiraSoftwareCloudApi" \
  "$(jq -n --arg e "$JIRA_EMAIL" --arg t "$JIRA_API_TOKEN" --arg d "$JIRA_DOMAIN" \
    '{email: $e, apiToken: $t, domain: $d}')")
echo "    Jira   : $JIRA_CRED_ID"

GITHUB_CRED_ID=$(upsert_credential "GitHub PAT" "httpHeaderAuth" \
  "$(jq -n --arg v "Bearer $GITHUB_PAT" '{name: "Authorization", value: $v}')")
echo "    GitHub : $GITHUB_CRED_ID"

# ── Step 2: Import workflow ───────────────────────────────────────────────────
echo ""
echo "==> [2/5] Importing workflow ..."
IMPORT_RESP=$(n8n POST "/workflows" -d @"$WORKFLOW_FILE")
WF_ID=$(echo "$IMPORT_RESP" | jq -r '.id')
echo "    Workflow ID: $WF_ID"

# ── Step 3: Resolve Slack channel ID ─────────────────────────────────────────
echo ""
echo "==> [3/5] Looking up Slack channel '#$SLACK_CHANNEL_NAME' ..."
SLACK_CHANNEL_ID=$(curl -sf \
  -H "Authorization: Bearer $SLACK_ACCESS_TOKEN" \
  "https://slack.com/api/conversations.list?limit=200&exclude_archived=true" \
  | jq -r --arg name "$SLACK_CHANNEL_NAME" \
    '.channels[] | select(.name == $name) | .id // empty')

if [[ -z "$SLACK_CHANNEL_ID" ]]; then
  echo "ERROR: Channel '#$SLACK_CHANNEL_NAME' not found." >&2
  echo "       Create the channel and invite the bot first (/invite @<bot-name>)." >&2
  exit 1
fi
echo "    Channel ID: $SLACK_CHANNEL_ID"

# ── Step 4: Resolve Jira project ID and issue type ID ────────────────────────
echo ""
echo "==> [4/5] Looking up Jira project '$JIRA_PROJECT_KEY' ..."
JIRA_AUTH=$(printf '%s:%s' "$JIRA_EMAIL" "$JIRA_API_TOKEN" | base64 | tr -d '\n')

PROJECT_RESP=$(curl -sf \
  -H "Authorization: Basic $JIRA_AUTH" -H "Accept: application/json" \
  "$JIRA_DOMAIN/rest/api/3/project/$JIRA_PROJECT_KEY")

JIRA_PROJECT_ID=$(echo "$PROJECT_RESP" | jq -r '.id // empty')
if [[ -z "$JIRA_PROJECT_ID" ]]; then
  echo "ERROR: Jira project '$JIRA_PROJECT_KEY' not found." >&2; exit 1
fi
echo "    Project ID: $JIRA_PROJECT_ID"

# Fetch issue types and prefer Bug > Task > Story > first available
ISSUE_TYPES_RESP=$(curl -sf \
  -H "Authorization: Basic $JIRA_AUTH" -H "Accept: application/json" \
  "$JIRA_DOMAIN/rest/api/3/issuetype")

JIRA_ISSUE_TYPE_ID=$(echo "$ISSUE_TYPES_RESP" | jq -r \
  '[.[] | select(.name | test("^(Bug|Task|Story)$"; "i"))] | sort_by(.name) | first | .id // empty')

if [[ -z "$JIRA_ISSUE_TYPE_ID" ]]; then
  # Fall back to first available type
  JIRA_ISSUE_TYPE_ID=$(echo "$ISSUE_TYPES_RESP" | jq -r '.[0].id // empty')
fi
if [[ -z "$JIRA_ISSUE_TYPE_ID" ]]; then
  echo "ERROR: Could not find a suitable Jira issue type." >&2; exit 1
fi
echo "    Issue Type ID: $JIRA_ISSUE_TYPE_ID"

# ── Step 5: Patch workflow nodes ──────────────────────────────────────────────
echo ""
echo "==> [5/5] Wiring credentials and config into workflow nodes ..."

CURRENT_WF=$(n8n GET "/workflows/$WF_ID")

RUNBOOK_URL="https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/contents/run-book.md"
PR_URL="https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/contents/run-book.md"

UPDATED_WF=$(echo "$CURRENT_WF" | jq \
  --arg slackId   "$SLACK_CRED_ID" \
  --arg jiraId    "$JIRA_CRED_ID" \
  --arg githubId  "$GITHUB_CRED_ID" \
  --arg chanId    "$SLACK_CHANNEL_ID" \
  --arg chanName  "#$SLACK_CHANNEL_NAME" \
  --arg projId    "$JIRA_PROJECT_ID" \
  --arg projName  "$JIRA_PROJECT_KEY" \
  --arg typeId    "$JIRA_ISSUE_TYPE_ID" \
  --arg runbookUrl "$RUNBOOK_URL" \
  --arg prUrl      "$PR_URL" \
  '
  # Slack credentials + channel on every Slack node
  (.nodes[] | select(.type == "n8n-nodes-base.slack")
    | .credentials.slackApi) = {id: $slackId, name: "Slack - POC"} |
  (.nodes[] | select(.type == "n8n-nodes-base.slack")
    | .parameters.channelId) = {__rl: true, mode: "id", value: $chanId, cachedResultName: $chanName} |

  # Jira credentials + project + issue type
  (.nodes[] | select(.type == "n8n-nodes-base.jira")
    | .credentials.jiraSoftwareCloudApi) = {id: $jiraId, name: "Jira - POC"} |
  (.nodes[] | select(.type == "n8n-nodes-base.jira")
    | .parameters.project) = {__rl: true, mode: "id", value: $projId, cachedResultName: $projName} |
  (.nodes[] | select(.type == "n8n-nodes-base.jira")
    | .parameters.issueType) = {__rl: true, mode: "id", value: $typeId} |

  # GitHub HTTP Request nodes: credentials + URLs
  (.nodes[] | select(.id == "http-fetch-runbook")
    | .credentials.httpHeaderAuth) = {id: $githubId, name: "GitHub PAT"} |
  (.nodes[] | select(.id == "http-fetch-runbook")
    | .parameters.url) = $runbookUrl |
  (.nodes[] | select(.id == "http-create-pr")
    | .credentials.httpHeaderAuth) = {id: $githubId, name: "GitHub PAT"} |
  (.nodes[] | select(.id == "http-create-pr")
    | .parameters.url) = $prUrl
  ')

n8n PUT "/workflows/$WF_ID" -d "$UPDATED_WF" > /dev/null
echo "    Done."

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "✅  Setup complete!"
echo ""
echo "    Workflow : $BASE_URL/workflow/$WF_ID"
echo ""
echo "    Next steps:"
echo "    1. Open the workflow URL above."
echo "    2. Click 'Execute Workflow' to do a manual test run."
echo "    3. Once it runs cleanly, toggle 'Active' to start the 5-minute schedule."
