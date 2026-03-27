## Incident Automation Requirements (n8n)

### Goal
Automate alert triage from Slack + Splunk, reuse known runbook scenarios when possible, and create a Git PR + Jira ticket when a new scenario is discovered.

### Functional flow
1. Monitor Slack alerts.
2. Extract the Splunk reference from each alert and fetch log results.
3. Load runbook scenarios from run-book.md in Git.
4. Match current logs to existing runbook scenarios.
5. If matched, execute the associated runbook action (with approval rules).
6. If not matched:
    - Generate a proposed new scenario (error signature + suggested resolution).
    - Create a Git branch and open a PR updating run-book.md.
    - Create a Jira ticket linked to the PR.
    - Notify on-call by email only if impact is user-facing or severity is high.

### Decisions captured
1. Runbook source of truth is Git.
2. Unknown scenarios must generate a PR (not direct commit to main).
3. Unknown scenarios should create a Jira ticket linked to the PR.
4. Email notification is conditional: skip email when LLM classifies issue as non-user-impacting.
5. No strict processing timeout required for now.

### Acceptance criteria (suggested)
1. Slack alert ingestion
    - Given a new alert in the configured channel, the workflow ingests it exactly once.
    - Duplicate alert messages do not create duplicate remediation actions.
2. Splunk log retrieval
    - Given a valid Splunk reference, logs are fetched and normalized into a standard structure.
    - If Splunk retrieval fails, workflow records failure reason and creates a Jira ticket for manual triage.
3. Scenario matching
    - Workflow returns one of: MATCHED, NO_MATCH, or MATCH_LOW_CONFIDENCE.
    - Low confidence is treated as NO_MATCH unless manual approval is provided.
4. Matched scenario handling
    - Workflow executes only approved runbook actions.
    - Action outcome is recorded back to Slack thread and Jira (if present).
5. No-match handling
    - Workflow opens a PR with a runbook entry template populated from logs and suggested fix.
    - Workflow creates a Jira issue that includes alert id, error signature, PR link, and suggested fix.
6. Notification behavior
    - Email is sent to on-call only when impact_classification is USER_IMPACTING or severity >= High.
    - For non-user-impacting issues, email is skipped but Slack/Jira are still updated.

### Data contract (suggested)
1. Slack alert minimum fields
    - alert_id
    - timestamp
    - source_service
    - severity
    - splunk_query_or_link
    - slack_channel
    - slack_thread_ts
2. Normalized Splunk result minimum fields
    - error_signature
    - error_message
    - stack_trace_or_log_excerpt
    - affected_service
    - first_seen
    - last_seen
    - occurrence_count
3. Runbook scenario entry minimum fields
    - scenario_id
    - title
    - match_pattern (string/regex/signature)
    - impact_classification (USER_IMPACTING or NON_USER_IMPACTING)
    - remediation_steps
    - rollback_steps
    - owner_team
    - last_reviewed
4. Jira issue minimum fields
    - project_key
    - issue_type
    - summary
    - description
    - severity
    - alert_id
    - pr_url

### Guardrails (minimal for now)
1. Never execute destructive actions without explicit approval.
2. Treat low-confidence LLM classification as manual-review-required.
3. All workflow decisions must be logged in execution history (input, classification, action, output).

### Out of scope for now
1. Strict SLO/SLA and timeout targets.
2. Advanced reliability/performance tuning.
3. Full governance/compliance model beyond PR + Jira traceability.