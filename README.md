# What is n8n?

n8n (pronounced "n-eight-n") is a workflow automation platform for connecting apps, APIs, and data so repetitive work runs automatically.

In short:
- Build automations visually (low-code), then add code when needed.
- Connect many services (500+ integrations, plus custom API calls).
- Run in n8n Cloud or self-host for more control and privacy.
- Use it for classic automation and AI-powered workflows.

## Why people use it

- Automate cross-tool tasks (for example: forms -> database -> Slack alerts).
- Create reliable business workflows with triggers, logic, and error handling.
- Add custom JavaScript/Python for advanced logic.
- Keep control of infrastructure and security with self-hosting options.

## Good starting points

- Docs home: https://docs.n8n.io/
- About n8n: https://docs.n8n.io/
- Quickstart: https://docs.n8n.io/try-it-out/
- Choosing Cloud vs self-host: https://docs.n8n.io/choose-n8n/
- Product website: https://n8n.io/
- Integrations: https://n8n.io/integrations/

## POC Setup Guide

### Prerequisites
- Docker Desktop installed
- A Slack workspace (free tier is fine)
- A Jira Cloud account (free tier is fine)
- A GitHub account

### Step 1 — Start n8n

```bash
docker compose up -d
```

Open http://localhost:5678 and create your owner account.

### Step 2 — Configure Slack

1. Go to https://api.slack.com/apps and click **Create New App → From scratch**.
2. Name it (e.g. `n8n-incident-bot`), pick your workspace.
3. Go to **OAuth & Permissions** and add these Bot Token Scopes:
   - `channels:history` — read messages in public channels
   - `channels:read` — list channels
   - `chat:write` — post messages
   - `reactions:read` — detect emoji reactions (optional)
4. Click **Install to Workspace** and copy the **Bot User OAuth Token** (starts with `xoxb-`).
5. Create a channel (e.g. `#alerts-test`) and invite the bot: type `/invite @n8n-incident-bot` in the channel.
6. In n8n, go to **Credentials → New → Slack API** and paste the Bot Token.

### Step 3 — Configure Jira

1. Go to https://id.atlassian.com/manage-profile/security/api-tokens and click **Create API token**.
2. Copy the token.
3. In your Jira Cloud, create a project for this POC (e.g. project key `INC`).
4. In n8n, go to **Credentials → New → Jira Software Cloud API** and fill in:
   - Email: your Atlassian email
   - API Token: the token you copied
   - Domain: `https://your-domain.atlassian.net`

### Step 4 — Configure GitHub

1. Go to https://github.com/settings/tokens and create a **Fine-grained personal access token** scoped to this repo with permissions:
   - Contents: Read and Write
   - Pull requests: Read and Write
2. In n8n, go to **Credentials → New → GitHub API** and paste the token.

### Step 5 — Test each connection

Create a test workflow in n8n with a Manual Trigger and one node for each service to verify credentials:

1. **Slack → Send Message** to `#alerts-test` with text `n8n test`.
2. **Jira → Create Issue** in your project with summary `n8n test issue`.
3. **GitHub → Get Repository** for this repo.

Execute each and confirm they succeed. Delete the test issue/message after.

### Step 6 — Send a test alert in Slack

Post a message in `#alerts-test` that simulates a Splunk alert:
```
🚨 ALERT: TimeoutError: request to payment-service exceeded 30s
Splunk query: index=prod sourcetype=payment-service "TimeoutError"
Severity: High
Service: payment-service
```

This message will be used to test the full workflow once we build it.

## Project structure

```
poc-n8n/
├── docker-compose.yml           # n8n local instance
├── .env                         # API tokens (gitignored – never commit)
├── .gitignore
├── run-book.md                  # operational runbook (scenarios + remediation)
├── requirements.md              # detailed requirements for the automation
├── workflows/
│   └── incident-triage.json     # n8n workflow definition (code-based)
├── scripts/
│   └── import-workflow.sh       # Bash script to import workflow
└── README.md                    # this file
```

## Importing the Workflow (Code-Based Approach)

The workflow is defined as JSON in `workflows/incident-triage.json` so it can be version-controlled and imported without using the n8n UI.

### Option A — REST API (recommended)

1. Start n8n and create your owner account.
2. Go to **Settings → API** and create an API key, add it to `.env` as `N8N_API_KEY`.
3. Run the import script:

```bash
./scripts/import-workflow.sh            # uses N8N_API_KEY from .env
```

### Option B — Docker CLI

```bash
./scripts/import-workflow.sh --method cli
```

### Option C — Manual import via UI

1. Open http://localhost:5678
2. Go to **Workflows → Import from File**
3. Select `workflows/incident-triage.json`

### After Import

The workflow arrives **inactive** (paused). Before activating:

1. Open the workflow in the n8n editor.
2. Set the Slack channel ID in the Slack nodes.
3. Set the Jira project/issue type in the Jira node.
4. Update the GitHub repo URL in the HTTP Request nodes to match your fork.
5. Configure credentials — the tokens from `.env` are available as environment variables inside the container. When creating credentials in n8n, paste the corresponding values from `.env`.
6. Test by clicking **Execute Workflow** manually first.

## More references

- Very quick quickstart: https://docs.n8n.io/try-it-out/quickstart/
- First workflow tutorial: https://docs.n8n.io/try-it-out/tutorial-first-workflow/
- Docker install docs: https://docs.n8n.io/hosting/installation/docker/
- Slack node docs: https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.slack/
- Jira node docs: https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.jira/
- GitHub node docs: https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.github/
