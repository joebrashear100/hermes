# Hermes bin/ - Script Documentation

Scripts and tools in `~/.hermes/bin/` for Hermes agent management and monitoring.

## Overview

| Script | Purpose | Usage |
|--------|---------|-------|
| `specialist` | Invoke Claude Code specialist agents headlessly | CLI delegation |
| `specialist-stream` | Invoke specialist with streaming output | Watch progress |
| `claude-usage` | Summarize token consumption | Token tracking |
| `claude-usage-monitor.sh` | Hourly token monitoring (launchd job) | Automatic monitoring |
| `router-bench.py` | A/B test router model candidates | Performance testing |
| `tirith` | Hermes router binary (compiled) | Internal routing |

---

## specialist

**Invoke a Claude Code specialist agent headlessly and return its output.**

Wraps the Claude Code CLI (`claude`) with proper authentication and settings so Hermes can delegate complex tasks without manual flag management.

### Usage

```bash
specialist <agent-name> "<task text>" [extra-add-dir ...]
specialist <agent-name> --task-file /path/to/task.txt [extra-add-dir ...]
echo "<task>" | specialist <agent-name> --stdin [extra-add-dir ...]
```

### Examples

```bash
# Invoke a specialist with inline task
specialist mike-ross "Design the database schema for user profiles"

# Use a task file
specialist harvey-specter --task-file /tmp/requirements.txt

# Pipe task from stdin
echo "Audit this code for security issues" | specialist penelope-featherington --stdin

# Add multiple working directories
specialist ruth-langmore "Update the sprint board" ~/.projects/main ~/.projects/secondary
```

### Available Agents

```bash
specialist --help  # Lists all available agents
```

Agents are defined in `~/.claude/agents/` and include:
- mike-ross (Principal Architect)
- harvey-specter (Product Owner)
- ruth-langmore (Scrum Master)
- penelope-featherington (Comms & Exec Voice)
- donna-paulsen (Chief of Staff)
- And others...

### How It Works

1. Reads Claude Code credential from macOS Keychain
2. Sets up isolated Claude CLI session with correct flags
3. Executes task against the specialist agent
4. Returns agent output as plain text

**Auth:** Uses Joe's macOS Keychain Claude Code credential (`claude-code` service, user `<your-github-handle>`).

**Run:** On Joe's Claude subscription (flat-rate, not API).

### Implementation Notes

- Never improvises CLI flags; all settings are hardcoded and tested
- Prevents mode failures like `--settings with max-turns=1`
- Keychain auth verified to work with launchd GUI agents
- Works from any directory with multiple context paths

---

## specialist-stream

**Invoke a Claude Code specialist and stream a clean activity report.**

Similar to `specialist` but displays live progress (agent reasoning, file edits, tool calls) as the task executes.

### Usage

```bash
specialist-stream <agent-name> "<task text>" [extra-add-dir ...]
```

### Example

```bash
# Watch a specialist implement a feature in real time
specialist-stream mike-ross "Add OAuth2 to the auth service" ~/projects/api-server
```

### Output

Streams agent activity including:
- Reasoning steps
- File read/edit operations
- Tool invocations (git, bash, etc)
- Final summary

---

## claude-usage

**Summarize Claude Code CLI token consumption from local session JSONLs.**

Parses session transcripts from `~/.claude/sessions/` and calculates total tokens used, breakdown by operation type, and cost estimate.

### Usage

```bash
claude-usage              # Show today's usage
claude-usage --yesterday  # Show yesterday's usage
claude-usage --week       # Show this week
```

### Output Example

```
Claude Code Token Summary
========================
Date Range: 2026-06-27

Operation Type    Input Tokens   Output Tokens   Total
-----------      -----------    -----------     -----
Code edits              45000          12000     57000
Reasoning              120000          35000    155000
Agent runs             200000          50000    250000
Other                   10000           5000     15000
-----------           --------        ------    ------
TOTAL                 375000         102000    477000

Estimated cost: $1.43 (at current API rates)
```

### How It Works

1. Scans `~/.claude/sessions/` for session JSONL files
2. Extracts token counts from each session's transcript
3. Groups by operation type (detected from tool calls and context)
4. Sums totals and estimates cost

### Implementation Notes

- Parses JSON from Claude Code session logs (JSONL format)
- Does NOT track claude.ai web usage (API gap - see memory)
- Does NOT track Claude Design usage
- Local-only; no external API calls

---

## claude-usage-monitor.sh

**Runs claude-usage and writes a rolling log + ntfy alert.**

Invoked hourly by the `com.<your-username>.claude-usage-monitor` launchd job. Tracks daily token consumption and alerts if thresholds are exceeded.

### Usage

Normally runs via launchd (automatic). Can also run manually:

```bash
~/.hermes/bin/claude-usage-monitor.sh
```

### How It Works

1. Calls `claude-usage` to get current token count
2. Writes summary to `~/.hermes/logs/token-monitor.log`
3. If daily total exceeds threshold, sends alert via ntfy

### Configuration

Set threshold in `.env`:
```bash
export CLAUDE_USAGE_DAILY_LIMIT=500000  # tokens per day
export NTFY_TOPIC=claude-usage-alerts
```

### Log File

```bash
tail -f ~/.hermes/logs/token-monitor.log
```

---

## router-bench.py

**A/B tool-calling benchmark for Hermes router model candidates.**

Benchmarks two models against a suite of tool-calling tasks to compare accuracy, latency, and cost.

### Usage

```bash
router-bench.py <model1> <model2> [--iterations N] [--output results.json]
```

### Examples

```bash
# Compare Claude Opus vs Sonnet
./~/.hermes/bin/router-bench.py claude-opus-4-8 claude-sonnet-4-6

# Extended benchmark with 100 iterations
./~/.hermes/bin/router-bench.py claude-haiku-4-5 claude-sonnet-4-6 --iterations 100

# Save results to JSON
./~/.hermes/bin/router-bench.py claude-opus-4-8 claude-sonnet-4-6 --output /tmp/bench.json
```

### Output

```
Router Benchmark Results
=======================
Model 1: claude-opus-4-8
Model 2: claude-sonnet-4-6

Accuracy:
  Opus:   98.2% (164/167 tools correct)
  Sonnet: 94.1% (157/167 tools correct)

Latency (p50):
  Opus:   245ms
  Sonnet: 180ms

Cost per task:
  Opus:   $0.00034
  Sonnet: $0.00018

Winner (best accuracy): Opus
Winner (best latency):  Sonnet
Winner (best cost):     Sonnet
```

### Use Case

Helps decide which model to use as the Hermes default router when new candidates appear.

---

## tirith

**Hermes router binary (compiled executable).**

The actual router responsible for:
- Parsing tasks
- Selecting appropriate models
- Managing fallback chains
- Handling provider failures

This is a compiled binary (likely Go or Rust) and not typically invoked directly from the shell.

### How It's Used

Called by the WebUI and specialist scripts to route work to the correct model/provider.

### Configuration

Behavior configured via `~/.hermes/config.yaml`:
- Default model selection
- Provider fallback order
- Cost optimization rules
- Latency constraints

### Debugging

Check logs if routing fails:
```bash
tail -f ~/.hermes/logs/router.log
```

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `specialist mike-ross "<task>"` | Delegate to architect specialist |
| `specialist-stream ruth-langmore "<task>"` | Watch specialist progress |
| `claude-usage` | Check today's token use |
| `./router-bench.py model1 model2` | Compare models |
| `launchctl list \| grep claude-usage-monitor` | Check hourly monitor status |

---

## Troubleshooting

**Specialist fails with "no such specialist":**
```bash
# List available agents
ls ~/.claude/agents/ | sed 's/\.md$//'
```

**Claude-usage shows no data:**
```bash
# Ensure sessions exist
ls -lA ~/.claude/sessions/ | head
```

**Router-bench hangs:**
```bash
# Kill and check model availability
pkill -f router-bench.py
echo "export HERMES_DEBUG=1" >> ~/.hermes/.env
```

---

## See Also

- **README.md** - Directory structure
- **RUNBOOK.md** - Common tasks and maintenance
- **SOUL.md** - Agent philosophy
