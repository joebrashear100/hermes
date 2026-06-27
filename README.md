# Hermes - Joe's Agent System

Hermes is a self-hosted agent system that orchestrates Claude Code specialists and manages the routing layer for AI-assisted tasks. It runs locally on the Mac mini as a launchd service and handles CLI delegation, token tracking, and profile management.

## Quick Start

**Check Hermes status:**
```bash
launchctl list | grep hermes
```

**Delegate work to a specialist:**
```bash
specialist <agent-name> "<task description>"
```

**Monitor token usage:**
```bash
claude-usage
```

## Directory Structure

```
~/.hermes/
├── README.md                 # This file
├── RUNBOOK.md               # Common tasks and troubleshooting
├── BIN.md                   # Script documentation
├── SOUL.md                  # Agent persona and delegation philosophy
├── config.yaml              # Hermes configuration (runtime + routes)
├── .env                     # Environment variables (API keys, model config)
├── .backups/                # Backup copies of config (*.bak.TIMESTAMP)
│
├── bin/                     # Executable scripts and tools
│   ├── specialist           # Invoke a Claude Code specialist agent
│   ├── specialist-stream    # Invoke specialist with streaming output
│   ├── claude-usage         # Summarize Claude Code token consumption
│   ├── claude-usage-monitor.sh  # Hourly token monitoring
│   ├── router-bench.py      # A/B test router model candidates
│   └── tirith               # [Hermes router binary]
│
├── profiles/                # Hermes agent profiles and skills
│   ├── apple/               # Apple-related tasks (Calendar, Mail, Notes)
│   ├── autonomous-ai-agents/# Multi-agent orchestration
│   ├── creative/            # Content creation, writing
│   ├── data-science/        # Data analysis
│   ├── doc-based-writing/   # Documentation and reports
│   ├── dogfood/             # Internal testing
│   ├── email/               # Email management
│   ├── github/              # GitHub operations
│   ├── media/               # Media processing
│   ├── meeting-prep/        # Meeting preparation
│   ├── mlops/               # ML operations
│   ├── note-taking/         # Note organization
│   ├── productivity/        # Task and workflow management
│   └── curator.md           # Curator skill configuration
│
├── skills/                  # Skill definitions (loaded by profiles)
│
├── sessions/                # Session logs and history
│
├── logs/                    # Runtime logs
│   └── webui.log           # WebUI service log
│
├── memories/                # Persistent memory entries (Mem0 style)
│
├── cache/                   # Cached model metadata and documents
│   ├── model_catalog.json
│   ├── openrouter_model_metadata.json
│   ├── vision/
│   └── documents/
│
├── workspace/               # Working directory for task execution
│
├── kanban/                  # Task board data
│   └── kanban.db           # SQLite database
│
├── state.db                 # Hermes state and session persistence
│
├── auth.json                # Authentication credentials (gitignored)
│
└── providers/               # Provider integrations (OpenRouter, etc)
```

## Key Files

| File | Purpose |
|------|---------|
| `config.yaml` | Router config, model selection, provider settings, remotes |
| `.env` | Secret API keys, model overrides, endpoint URLs |
| `SOUL.md` | Agent persona, communication style, delegation pattern |
| `.backups/` | Timestamped backups of config and auth (auto-created on edits) |
| `state.db` | SQLite: session history, conversation logs, task state |
| `kanban.db` | SQLite: kanban board for task management |
| `auth.json` | API credentials and authentication state |

## Services

**Hermes WebUI** (self-hosted chat interface)
```bash
launchctl start com.parantoux.hermes-webui  # Start
launchctl stop com.parantoux.hermes-webui   # Stop
open http://localhost:8787                  # Access
tail -f ~/.hermes/webui.log                 # Logs
```

**Claude Usage Monitor** (hourly token tracking)
```bash
launchctl list | grep claude-usage-monitor
# Runs hourly, logs to ~/.hermes/logs/
```

## Specialist Agents

Nine specialist agents live in `~/.claude/agents/`:
- These are separate from Hermes profiles
- Used via `specialist <name> "<task>"` from Hermes/CLI
- Inherit Joe's Claude subscription (not API)
- Optimized for specific domains

## Data Safety

- **Backups**: Auto-created on config edits as `.backups/*.bak.TIMESTAMP`
- **Secrets**: `.env` and `auth.json` are gitignored
- **Logs**: Session and runtime logs in `logs/` and `sessions/`
- **State**: SQLite databases (`state.db`, `kanban.db`) hold persistent data

## Configuration

**Changing models:**
```bash
# Add to ~/.hermes/.env
export HERMES_MODEL=claude-opus-4-8
export HERMES_FALLBACK_MODEL=claude-sonnet-4-6
```

**Changing providers:**
Edit `config.yaml` for OpenRouter config, provider overrides, API endpoints.

**Adding skills:**
New skill YAML files in `~/.hermes/profiles/<profile>/` are auto-loaded.

## Next Steps

- See **RUNBOOK.md** for common tasks and troubleshooting
- See **BIN.md** for script documentation
- See **SOUL.md** for agent philosophy and delegation pattern
