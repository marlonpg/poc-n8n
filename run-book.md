# Run Book

Operational runbook for production incident scenarios. Each entry describes an error pattern, its impact, and the steps to resolve it.

---

## Scenario: APP_TIMEOUT_001

- **Title:** Application request timeout on payment service
- **Match pattern:** `TimeoutError: request to payment-service exceeded 30s`
- **Impact classification:** USER_IMPACTING
- **Severity:** High
- **Affected service:** payment-service
- **Remediation steps:**
  1. Check payment-service pod health: `kubectl get pods -n payments`
  2. Restart unhealthy pods: `kubectl rollout restart deployment/payment-service -n payments`
  3. Verify recovery by checking logs for successful requests
- **Rollback steps:**
  1. Roll back to previous deployment: `kubectl rollout undo deployment/payment-service -n payments`
- **Owner team:** payments-team
- **Last reviewed:** 2026-03-27

---

## Scenario: DB_CONN_002

- **Title:** Database connection pool exhausted
- **Match pattern:** `Error: pool exhausted, cannot acquire connection`
- **Impact classification:** USER_IMPACTING
- **Severity:** High
- **Affected service:** order-service
- **Remediation steps:**
  1. Check active connections: `SELECT count(*) FROM pg_stat_activity;`
  2. Kill idle connections older than 10 min
  3. Restart order-service to reset connection pool
- **Rollback steps:**
  1. Revert connection pool size config to previous value
- **Owner team:** platform-team
- **Last reviewed:** 2026-03-27

---

## Scenario: DISK_SPACE_003

- **Title:** Disk space warning on log volume
- **Match pattern:** `DiskSpaceWarning: /var/log usage above 90%`
- **Impact classification:** NON_USER_IMPACTING
- **Severity:** Medium
- **Affected service:** logging-infra
- **Remediation steps:**
  1. Archive and compress logs older than 7 days
  2. Verify disk usage dropped below 70%
- **Rollback steps:**
  1. Restore archived logs if needed for investigation
- **Owner team:** infra-team
- **Last reviewed:** 2026-03-27

---

<!-- NEW SCENARIOS WILL BE ADDED BELOW BY AUTOMATION -->
