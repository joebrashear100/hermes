# Hermes Quick Start

Get stuff done via delegation. This is the 90-second version.

## Delegate a Task

```bash
specialist <agent> "<task>"
```

Example:
```bash
specialist mike-ross "Design a rate-limiting strategy for the API"
```

## Common Tasks

**Watch a specialist's progress:**
```bash
specialist-stream <agent> "<task>"
```

**Check token usage today:**
```bash
claude-usage
```

**Start the WebUI chat:**
```bash
launchctl start com.parantoux.hermes-webui
open http://localhost:8787
```

**List available agents:**
```bash
ls ~/.claude/agents/ | sed 's/\.md$//'
```

## Agent Selection Guide

| Task | Agent |
|------|-------|
| Architecture & design | `mike-ross` |
| Product requirements | `harvey-specter` |
| Sprint & delivery | `ruth-langmore` |
| Exec comms & docs | `penelope-featherington` |
| Life admin & scheduling | `donna-paulsen` |
| Markets & trading | `marty-byrde` |
| Chief of staff duties | Any agent (auto-routes) |

## Troubleshooting

**Specialist won't run:**
```bash
# Check agent name
ls ~/.claude/agents/ | grep <name>

# Try verbose
bash -x ~/.hermes/bin/specialist <agent> "<task>" 2>&1 | head -50
```

**WebUI won't start:**
```bash
# Check port
lsof -i :8787

# Check logs
tail -f ~/.hermes/webui.log
```

**Tokens not tracking:**
```bash
# Check sessions exist
ls ~/.claude/sessions/ | head

# Run manually
claude-usage
```

## Full Documentation

- **README.md** - Full directory guide
- **RUNBOOK.md** - All common tasks & maintenance
- **BIN.md** - Script details
- **SOUL.md** - Agent philosophy

## One-Liners

```bash
# Check Hermes status
launchctl list | grep hermes

# View config
cat ~/.hermes/config.yaml

# View logs
tail -20 ~/.hermes/logs/*.log

# Backup before editing
cp ~/.hermes/config.yaml ~/.hermes/.backups/config.yaml.$(date +%s)
```

**You're ready.** Start delegating.
