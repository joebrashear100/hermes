# Hermes RUNBOOK

Common tasks, maintenance, and troubleshooting for the Hermes agent system.

## Delegation (Primary Use Case)

**Invoke a specialist for a task:**
```bash
specialist <agent-name> "<task description>"
```

Example:
```bash
specialist mike-ross "Design a caching strategy for pagination"
specialist harvey-specter "Write acceptance criteria for the auth feature"
```

**Available specialists:**
```bash
ls ~/.claude/agents/ | sed 's/\.md$//'
```

**Stream output (watch progress):**
```bash
specialist-stream <agent-name> "<task>"
```

**Use a different working directory:**
```bash
specialist <agent-name> "<task>" /path/to/project
```

## Token Tracking

**Check today's token usage:**
```bash
claude-usage
```

Shows breakdown by CLI operation type (code, reasoning, agent runs).

**Monitor tokens hourly:**
The `com.<your-username>.claude-usage-monitor` launchd job runs `claude-usage` every hour and writes a rolling log. Logs are in `~/.hermes/logs/`.

Check job status:
```bash
launchctl list | grep claude-usage-monitor
```

## WebUI (Chat Interface)

**Start the WebUI:**
```bash
launchctl start com.parantoux.hermes-webui
open http://localhost:8787
```

**Stop the WebUI:**
```bash
launchctl stop com.parantoux.hermes-webui
```

**Check WebUI logs:**
```bash
tail -f ~/.hermes/webui.log
```

**Troubleshoot: WebUI won't start**
1. Check if port 8787 is in use: `lsof -i :8787`
2. Kill any existing process: `lsof -i :8787 | grep LISTEN | awk '{print $2}' | xargs kill -9`
3. Restart: `launchctl start com.parantoux.hermes-webui`
4. Check logs: `tail -f ~/.hermes/webui.log`

## Configuration & Credentials

**View current config:**
```bash
cat ~/.hermes/config.yaml
```

**View environment variables:**
```bash
cat ~/.hermes/.env
```

**Update a setting:**
1. Edit `~/.hermes/config.yaml` or `~/.hermes/.env`
2. Restart Hermes if needed: `launchctl restart com.parantoux.hermes-webui`

**Restore from backup:**
```bash
ls ~/.hermes/.backups/
# Backups are auto-created on config edits with timestamps
cp ~/.hermes/.backups/config.yaml.bak.TIMESTAMP ~/.hermes/config.yaml
```

## Model & Router Selection

**Change default model:**
Add to `~/.hermes/.env`:
```bash
export HERMES_MODEL=claude-opus-4-8
export HERMES_FALLBACK_MODEL=claude-sonnet-4-6
```

**A/B test router models:**
```bash
./~/.hermes/bin/router-bench.py <model1> <model2>
```

(Benchmarks tool-calling performance across candidate models.)

## Profile Management

**View available profiles:**
```bash
ls -lA ~/.hermes/profiles/
```

Each profile (apple, github, autonomous-ai-agents, etc.) contains skills and agent definitions.

**Add a skill to a profile:**
1. Create `~/.hermes/profiles/<profile>/<skill-name>.yml`
2. Hermes auto-loads on next run

**Check profile state:**
```bash
cat ~/.hermes/profiles/curator.md  # Curator state
cat ~/.hermes/profiles/.usage.json # Usage tracking
```

## Known Issues & Workarounds

### Authentication Failures

**Problem:** "Missing Authentication header" when running specialist.

**Cause:** Usually a fat-fingered env var (e.g., a URL in an API key).

**Fix:**
```bash
# Check ~/.hermes/.env for typos
cat ~/.hermes/.env | grep -E '^export'

# Clear auth cache and restart
rm ~/.hermes/auth.lock
launchctl restart com.parantoux.hermes-webui
```

### Hermes Won't Start

**Problem:** Launchd service fails to start.

**Debug:**
```bash
# Check launchd status
launchctl list | grep hermes

# Check system logs
log stream --predicate 'process == "hermes"' --level debug

# Check for port conflicts
lsof -i :8787
lsof -i :8017  # API server
```

**Common cause:** macOS TCC (transparency, consent, control) blocking access. Hermes needs FDA (Full Disk Access) for proper operation, especially for Events/Calendar access.

**Fix:**
1. Open System Settings > Privacy & Security > Full Disk Access
2. Add the Hermes binary (usually `/opt/homebrew/bin/hermes` or wherever installed)
3. Restart: `launchctl restart com.parantoux.hermes-webui`

### Models Not Available

**Problem:** "Model not found" or "provider unavailable".

**Check available models:**
```bash
cat ~/.hermes/cache/model_catalog.json | jq '.[] | select(.provider == "openrouter")' | head -5
```

**Add a provider:**
Edit `config.yaml` and add provider config, then restart Hermes.

## Backups & Recovery

**View backup history:**
```bash
ls -lAt ~/.hermes/.backups/
```

**Auto-backup on edit:**
Hermes auto-creates timestamped backups whenever config or auth files are modified.

**Manual backup before risky changes:**
```bash
cp ~/.hermes/config.yaml ~/.hermes/.backups/config.yaml.manual.$(date +%s)
```

**Restore a backup:**
```bash
# List available backups
ls ~/.hermes/.backups/

# Restore specific version
cp ~/.hermes/.backups/config.yaml.bak.TIMESTAMP ~/.hermes/config.yaml
```

## Performance & Cleanup

**Clear cache:**
```bash
rm -rf ~/.hermes/cache/vision
rm -rf ~/.hermes/cache/documents
```

(Safe to clear; will be regenerated.)

**Check cache size:**
```bash
du -sh ~/.hermes/cache/
du -sh ~/.hermes/sessions/
du -sh ~/.hermes/logs/
```

**Archive old sessions:**
```bash
mkdir -p ~/.hermes/sessions/.archive
find ~/.hermes/sessions -type f -mtime +30 -exec mv {} ~/.hermes/sessions/.archive/ \;
```

## Maintenance Schedule

| Task | Frequency | Command |
|------|-----------|---------|
| Check token usage | Daily | `claude-usage` |
| Review logs | Weekly | `tail -20 ~/.hermes/logs/*.log` |
| Clear old caches | Monthly | See "Performance & Cleanup" |
| Archive sessions | Quarterly | See "Archive old sessions" |
| Verify auth | Monthly | `specialist <any-agent> "echo ok"` |

## Debugging

**Enable verbose logging:**
```bash
export HERMES_DEBUG=1
launchctl restart com.parantoux.hermes-webui
tail -f ~/.hermes/webui.log
```

**Trace a specialist invocation:**
```bash
bash -x ~/.hermes/bin/specialist <agent> "<task>" 2>&1 | head -100
```

**Check keychain credentials:**
```bash
security find-generic-password -s "claude-code" -a <your-github-handle> 2>/dev/null
```

(Specialist reads Claude Code auth from macOS Keychain.)

## Emergency Recovery

**Full reset (preserve data):**
```bash
# Stop all services
launchctl stop com.parantoux.hermes-webui
launchctl unload ~/Library/LaunchAgents/com.parantoux.hermes-webui.plist

# Clear state
rm ~/.hermes/state.db*
rm ~/.hermes/kanban.db*
rm ~/.hermes/auth.lock

# Restart
launchctl load ~/Library/LaunchAgents/com.parantoux.hermes-webui.plist
launchctl start com.parantoux.hermes-webui
```

**Preserve config but nuke state:**
```bash
rm ~/.hermes/state.db* ~/.hermes/kanban.db* ~/.hermes/sessions/*.jsonl
```

## See Also

- **README.md** - Directory structure and overview
- **BIN.md** - Script documentation
- **SOUL.md** - Agent philosophy and delegation pattern
