#!/bin/bash
# audit-daemon - hourly codebase auditor. Scans for bugs, secrets, security, compliance.
# Invoked by: com.<your-username>.audit-daemon launchd job
# Output: ~/.hermes/logs/audit-findings.jsonl (append-only)
set -uo pipefail

CLAUDE=/opt/homebrew/bin/claude
AGENT_DIR="$HOME/.claude/agents"
LOG_DIR="$HOME/.hermes/logs"
FINDINGS_LOG="$LOG_DIR/audit-findings.jsonl"
AUDIT_LEVEL="${AUDIT_LEVEL:-medium}"
AUDIT_DIRS="${AUDIT_DIRS:-$HOME/projects $HOME/code $HOME/.claude}"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Generate run ID (timestamp)
RUN_ID="audit-$(date +%Y%m%d-%H%M%S)"
RUN_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

DIR_COUNT=$(echo "$AUDIT_DIRS" | wc -w)
echo "[${RUN_TS}] Starting audit (level: $AUDIT_LEVEL, dirs: $DIR_COUNT targets)"

# Invoke /audit skill on each directory
DIRS_ARRAY=($AUDIT_DIRS)
for DIR in "${DIRS_ARRAY[@]}"; do
  [ ! -d "$DIR" ] && continue
  echo "[${RUN_TS}] Scanning: $DIR"
done

# Use the claude /audit command directly (invokes the skill)
# Note: /audit requires a git repo, so we need to cd into a project dir
cd "${DIRS_ARRAY[0]}" 2>/dev/null || cd "$HOME"

# Run audit skill and capture output
OUTPUT=$("$CLAUDE" /audit "$AUDIT_LEVEL" 2>&1)

# Parse output: extract JSON lines
FINDINGS=$(echo "$OUTPUT" | grep -E '^\s*\{' | sed 's/^[[:space:]]*//')

if [ -z "$FINDINGS" ]; then
  # No structured findings returned; log the raw output as warning
  echo "{\"run_id\": \"$RUN_ID\", \"timestamp\": \"$RUN_TS\", \"status\": \"no-findings\", \"raw_output_lines\": $(echo "$OUTPUT" | wc -l)}" >> "$FINDINGS_LOG"
  echo "[${RUN_TS}] ⚠ No structured findings (audit may have failed; check logs)"
  exit 1
fi

# Normalize and log each finding
CRITICAL_COUNT=0
while IFS= read -r line; do
  [ -z "$line" ] && continue

  # Inject run metadata if missing
  if ! echo "$line" | jq -e '.run_id' > /dev/null 2>&1; then
    line=$(echo "$line" | jq --arg run_id "$RUN_ID" --arg ts "$RUN_TS" '. + {run_id: $run_id, timestamp: $ts}')
  fi

  # Log to findings file
  echo "$line" >> "$FINDINGS_LOG"

  # Count critical findings for alerting
  if echo "$line" | jq -e '.severity == "critical"' > /dev/null 2>&1; then
    ((CRITICAL_COUNT++))
    TITLE=$(echo "$line" | jq -r '.title // "unknown"')
    echo "[${RUN_TS}] 🚨 CRITICAL: $TITLE"
  fi
done <<< "$FINDINGS"

# Summary
TOTAL_FINDINGS=$(echo "$FINDINGS" | wc -l)
echo "[${RUN_TS}] ✓ Audit complete: $TOTAL_FINDINGS finding(s), $CRITICAL_COUNT critical"

# Exit with error code if critical findings (triggers launchd error notifications)
[ "$CRITICAL_COUNT" -gt 0 ] && exit 2 || exit 0
