#!/bin/bash
# claude-usage-monitor - runs claude-usage and writes a rolling log + ntfy alert
# Invoked hourly by com.<your-username>.claude-usage-monitor launchd job.
set -euo pipefail

LOG_DIR="$HOME/.hermes/logs"
mkdir -p "$LOG_DIR"

TS=$(/opt/homebrew/bin/python3 -c "from datetime import datetime, timezone; print(datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC'))")
DATE_TAG=$(/opt/homebrew/bin/python3 -c "from datetime import datetime, timezone; print(datetime.now(timezone.utc).strftime('%Y-%m-%d'))")

LOG_FILE="$LOG_DIR/claude-usage-$DATE_TAG.log"

{
  echo
  echo "=========================================="
  echo "[$TS] hourly snapshot"
  echo "=========================================="
  "$HOME/.hermes/bin/claude-usage" 2>&1 || echo "claude-usage exited nonzero"
} >> "$LOG_FILE"

# Pull today's totals for alerting (BSD awk lacks GNU's 3-arg match, so use python).
TODAY_INPUT=$("$HOME/.hermes/bin/claude-usage" 2>/dev/null | /opt/homebrew/bin/python3 -c '
import re, sys
in_today = False
for line in sys.stdin:
    if line.startswith("=== TODAY"):
        in_today = True
        continue
    if line.startswith("==="):
        in_today = False
    if in_today and line.startswith("  total:"):
        m = re.search(r"total: ([0-9.]+)([MkB])", line)
        if m:
            v = float(m.group(1))
            mult = {"B": 1e9, "M": 1e6, "k": 1e3}.get(m.group(2), 1)
            print(int(v * mult))
            break
')

# Threshold: warn if today's input tokens exceed 500M (rough proxy for "you might be approaching
# the 5h rolling limit on Claude Max").  Adjust as Joe learns his actual ceiling.
DAILY_WARN_THRESHOLD=${CLAUDE_USAGE_WARN_TOKENS:-500000000}
NTFY_TOPIC="${NTFY_TOPIC:-<your-ntfy-topic>}"
ALERT_FLAG="$LOG_DIR/.claude-usage-warned-$DATE_TAG"

if [ -n "$TODAY_INPUT" ] && [ "$TODAY_INPUT" -gt "$DAILY_WARN_THRESHOLD" ] && [ ! -f "$ALERT_FLAG" ]; then
  M=$((TODAY_INPUT / 1000000))
  /usr/bin/curl -fsS --max-time 5 \
    -H "Title: Claude usage high" \
    -H "Priority: default" \
    -H "Tags: warning" \
    -d "Today input tokens: ${M}M (threshold ${DAILY_WARN_THRESHOLD} = $((DAILY_WARN_THRESHOLD/1000000))M). Check ~/.hermes/logs/claude-usage-$DATE_TAG.log" \
    "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1 || true
  touch "$ALERT_FLAG"
  echo "[$TS] ALERT fired: today input ${M}M > threshold $((DAILY_WARN_THRESHOLD/1000000))M" >> "$LOG_FILE"
fi
