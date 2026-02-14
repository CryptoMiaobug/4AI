# Multi-OpenClaw Setup on Mac

A guide to running multiple isolated OpenClaw instances on a single Mac, each powered by a different AI model, collaborating through shared resources.

---

## Introduction

OpenClaw supports running multiple independent instances on one machine. Each instance connects to a different messaging bot (e.g., Telegram) and uses a different AI model backend. This enables a "team of bots" architecture where specialized agents collaborate under a single operator.

**Use cases:**
- Run Claude, DeepSeek, and Gemini side-by-side for different strengths
- A/B test model responses in real-time
- Assign different tasks to different models
- Build a collaborative multi-agent system with a shared knowledge base

---

## Prerequisites

- **macOS** (Apple Silicon or Intel)
- **Node.js** v20+ installed
- **OpenClaw** installed globally (`npm install -g openclaw`)
- **Telegram Bot tokens** — one per instance (create via [@BotFather](https://t.me/BotFather))
- **API keys** for each model provider (stored securely, never in shared files)

## Version Compatibility

This guide has been tested with the following OpenClaw versions:

| OpenClaw Version | Tested Date | Status |
|------------------|-------------|--------|
| 0.9.x series | 2026-02 | ✅ Fully compatible |
| 0.8.x series | 2026-01 | ✅ Compatible (minor config differences) |
| 0.7.x and below | Untested | ⚠️ May require adjustments |

**Note:** OpenClaw evolves rapidly. Always check the [official docs](https://docs.openclaw.ai) for the latest features and breaking changes. If you encounter issues with newer versions, check the release notes for migration guides.

### Key Version Features
- **v0.9.x**: Enhanced multi-bot support, improved cron scheduling
- **v0.8.x**: Basic multi-instance support (documented here)
- **v0.7.x and earlier**: Limited multi-bot capabilities (not recommended)

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────┐
│                     macOS Host                        │
│                                                      │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐        │
│  │ Instance C │  │ Instance D │  │ Instance G │       │
│  │  Claude    │  │  DeepSeek  │  │  Gemini    │       │
│  │           │  │           │  │           │        │
│  │ ~/.openclaw│  │~/.oc-deep │  │ ~/.oc-gem  │       │
│  │           │  │           │  │           │        │
│  │ workspace/│  │ workspace/│  │ workspace/│        │
│  │ skills/ ──┤  │ skills/───┤  │ skills/───┤        │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘        │
│        │   symlink ──→ │ ←── symlink  │              │
│        │               │              │              │
│        ▼               │              │              │
│  ┌───────────┐         │              │              │
│  │ skills/   │ ◄───────┘──────────────┘              │
│  │ (source)  │  Single source of truth               │
│  └───────────┘                                       │
│        │                                             │
│  ┌─────┴──────────┐   ┌────────────────┐             │
│  │ ~/shared/      │   │  Telegram API  │             │
│  │  ├── setting/  │   └────────────────┘             │
│  │  ├── github/   │                                  │
│  │  └── program/  │                                  │
│  └────────────────┘                                  │
└──────────────────────────────────────────────────────┘
```

Each instance runs as a separate process with its own:
- Configuration directory
- Workspace (memory, soul, identity files)
- Cron scheduler
- Telegram bot connection

All instances share:
- **Skills directory** (via symlinks) — tools, scripts, and skill definitions auto-sync
- **Collaboration folder** (`~/shared/`) — documents, settings, and inter-bot communication

---

## Quick Start Checklist

Use this checklist to verify your setup is ready before launching instances:

- [ ] **Verify macOS environment**: `node --version` shows v20+, `which openclaw` returns path
- [ ] **Create directories**: All instance folders exist (`~/.openclaw`, `~/.openclaw-deepseek`, `~/.openclaw-gemini`) and shared folder (`~/shared/`)
- [ ] **Configure Telegram bots**: Unique bot tokens obtained from @BotFather (3 tokens for 3 instances)
- [ ] **Set up API keys**: Environment variables defined in each launch script (one per model provider)
- [ ] **Initialize workspace files**: `SOUL.md`, `MEMORY.md`, and `USER.md` created in each instance's `workspace/` directory
- [ ] **Create launch scripts**: `.command` files written with correct `OPENCLAW_HOME` paths and made executable (`chmod +x`)
- [ ] **Test single instance**: Launch one instance with `OPENCLAW_HOME=~/.openclaw openclaw gateway`, verify it connects to Telegram
- [ ] **Verify shared folder access**: All instances can read/write to `~/shared/`
- [ ] **Add bots to group**: All bots added to your Telegram group with admin rights

**If all checks pass**, you're ready to launch all three instances!

---

## Setup Steps

### Step 1: Create Instance Directories

Each instance needs its own `OPENCLAW_HOME`:

```bash
# Instance C (Claude)
mkdir -p ~/.openclaw/workspace

# Instance D (DeepSeek)
mkdir -p ~/.openclaw-deepseek/workspace

# Instance G (Gemini)
mkdir -p ~/.openclaw-gemini/workspace

# Shared collaboration folder
mkdir -p ~/shared/setting
mkdir -p ~/shared/github
mkdir -p ~/shared/program
```

### Step 2: Configure Each Instance

Create `config.yaml` in each instance's root directory.

**Example structure** (`~/.openclaw-<name>/config.yaml`):

```yaml
# Model configuration
model: <provider>/<model-name>

# Channel configuration
channels:
  telegram:
    enabled: true
    token: "<your-bot-token>"
    dmPolicy: open
    allowFrom:
      - "*"

# Optional: proxy settings (if behind a proxy)
# proxy: http://proxy-host:port
```

> ⚠️ **Never hardcode API keys in config files.** Use environment variables instead.

### Step 3: Create Launch Scripts

Create a `.command` file for each instance:

**`OpenClaw_Claude.command`**:
```bash
#!/bin/bash
cd ~

# Set API key via environment variable
export ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"

# Optional: proxy configuration
# export HTTP_PROXY="http://your-proxy:port"
# export HTTPS_PROXY="http://your-proxy:port"
# export NO_PROXY="localhost,127.0.0.1"

# Launch with specific home directory
OPENCLAW_HOME=~/.openclaw openclaw gateway
```

**`OpenClaw_DeepSeek.command`**:
```bash
#!/bin/bash
cd ~

export DEEPSEEK_API_KEY="$DEEPSEEK_API_KEY"

OPENCLAW_HOME=~/.openclaw-deepseek openclaw gateway
```

**`OpenClaw_Gemini.command`**:
```bash
#!/bin/bash
cd ~

export GOOGLE_API_KEY="$GOOGLE_API_KEY"

OPENCLAW_HOME=~/.openclaw-gemini openclaw gateway
```

Make them executable:
```bash
chmod +x OpenClaw_*.command
```

### Step 4: Initialize Workspace Files

Each instance needs its own personality and memory:

```bash
# For each instance directory
for dir in ~/.openclaw ~/.openclaw-deepseek ~/.openclaw-gemini; do
  cat > "$dir/workspace/SOUL.md" << 'EOF'
# SOUL.md
# Customize personality for this instance
EOF

  cat > "$dir/workspace/MEMORY.md" << 'EOF'
# MEMORY.md - Long-term Memory
EOF

  cat > "$dir/workspace/USER.md" << 'EOF'
# USER.md - About Your Human
EOF
done
```

### Step 5: Launch All Instances

Double-click each `.command` file, or run in separate terminal tabs:

```bash
# Terminal 1
OPENCLAW_HOME=~/.openclaw openclaw gateway

# Terminal 2
OPENCLAW_HOME=~/.openclaw-deepseek openclaw gateway

# Terminal 3
OPENCLAW_HOME=~/.openclaw-gemini openclaw gateway
```

---

## Isolation Techniques

### Process-Level Isolation

Each instance runs as a completely separate OS process:

| Aspect | Isolation Method |
|--------|-----------------|
| **Config** | Separate `OPENCLAW_HOME` directories |
| **Memory** | Independent `MEMORY.md` and `workspace/` |
| **Skills** | **Shared** via symlinks (single source of truth) |
| **Cron** | Separate `cron/jobs.json` per instance |
| **Telegram** | Unique bot token per instance |
| **API Keys** | Environment variables, not shared |
| **Credentials** | Separate `credentials/` per instance |

### What's Shared vs. Isolated

```
ISOLATED (per instance):          SHARED (all instances):
├── openclaw.json                 ~/shared/
├── workspace/                      ├── setting/     # Rules & config docs
│   ├── MEMORY.md                   ├── github/      # Code & docs
│   ├── SOUL.md                     └── program/     # Projects
│   └── AGENTS.md
├── skills/ → symlink (see below)
├── cron/
└── credentials/
```

### Skills Auto-Sync via Symlinks

Instead of manually copying skills between instances, use **symbolic links** so all instances share the same skills directory. One edit propagates instantly to all bots.

**Setup (one-time):**

```bash
# Designate one instance as the "source" (e.g., Claude)
# Link the others to it

# Remove existing skills directories (if any)
rm -rf ~/.openclaw-deepseek/skills
rm -rf ~/.openclaw-gemini/skills

# Create symlinks
ln -s ~/.openclaw/skills ~/.openclaw-deepseek/skills
ln -s ~/.openclaw/skills ~/.openclaw-gemini/skills
```

**Verify:**

```bash
ls -la ~/.openclaw-deepseek/skills
# lrwxr-xr-x  ... /Users/you/.openclaw-deepseek/skills -> /Users/you/.openclaw/skills

ls -la ~/.openclaw-gemini/skills
# lrwxr-xr-x  ... /Users/you/.openclaw-gemini/skills -> /Users/you/.openclaw/skills
```

**Result:**

```
~/.openclaw/skills/           ← Source (C)
~/.openclaw-deepseek/skills   → symlink to above
~/.openclaw-gemini/skills     → symlink to above
```

Now when any bot (or you) updates a skill, adds a new tool, or modifies a script, all instances see the change immediately. No manual sync needed.

> **Tip:** This works for any shared resource. You can symlink individual skill folders instead of the entire `skills/` directory if you want per-instance customization for some skills.

### Environment Variable Isolation

Never let API keys leak between instances:

```bash
# Bad: global export that all instances see
export ANTHROPIC_API_KEY="sk-..."

# Good: set only in the specific launch script
# Only the Claude instance sees this key
```

---

## Control and Collaboration Mechanisms

### Shared Folder Structure

All instances read/write to `~/shared/`:

```
~/shared/
├── setting/
│   ├── 群聊天规则.md          # Group chat behavior rules
│   ├── 机器人简称对照表.md      # Bot roster and roles
│   ├── cron-config-guide.md   # Timer/reminder configuration
│   └── api-tokens.md          # Token registry (access-controlled)
├── github/
│   └── (collaborative documents)
└── program/
    └── (project folders)
```

### Group Chat Coordination

Add all bots to a single Telegram group. Define rules in the shared settings:

1. **Single commander**: Only the designated human operator issues commands
2. **Selective response**: Bots only respond when @-mentioned by the operator
3. **Context awareness**: Each bot reads recent group history to understand context
4. **Role hierarchy**: Designate a "lead" bot for conflict resolution

### Inter-Bot Communication via Files

Bots can leave messages for each other in the shared folder:

```bash
# Bot D writes a status update
echo "Task completed at $(date)" > ~/shared/status/d-last-update.txt

# Bot C reads it during its next check
cat ~/shared/status/d-last-update.txt
```

### Cron-Based Monitoring

One bot can monitor another's activity:

```json
{
  "name": "Check bot D status",
  "schedule": { "kind": "cron", "expr": "*/30 * * * *" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Check if Bot D has posted any updates in the last 30 minutes."
  },
  "delivery": {
    "mode": "announce",
    "channel": "telegram",
    "to": "<group-chat-id>"
  }
}
```

---

## Configuration for Different Models

### Model Selection

Each instance specifies its model in `config.yaml`:

```yaml
# Claude instance
model: anthropic/claude-opus-4-6

# DeepSeek instance
model: deepseek/deepseek-chat

# Gemini instance
model: google/gemini-2.5-pro
```

### Model-Specific Environment Variables

| Provider | Environment Variable | Notes |
|----------|---------------------|-------|
| Anthropic | `ANTHROPIC_API_KEY` | Claude models |
| DeepSeek | `DEEPSEEK_API_KEY` | DeepSeek models |
| Google | `GOOGLE_API_KEY` | Gemini models |
| OpenAI | `OPENAI_API_KEY` | GPT models |

### Customizing Behavior Per Instance

**System prompts** — Edit each instance's `SOUL.md`:
```markdown
# For a code-focused bot
You specialize in code review and programming tasks.

# For a research-focused bot
You specialize in web research and summarization.
```

**Model parameters** — Adjust in `config.yaml`:
```yaml
# For creative tasks (higher temperature)
modelParams:
  temperature: 0.8

# For precise tasks (lower temperature)
modelParams:
  temperature: 0.2
```

### Choosing the Right Model for Each Role

| Role | Recommended Model | Strength |
|------|------------------|----------|
| Lead / Complex reasoning | Claude | Nuanced analysis, safety |
| Cost-effective bulk tasks | DeepSeek | Speed, efficiency |
| Multimodal / Search | Gemini | Vision, web grounding |
| Code generation | GPT-4o / Claude | Strong coding ability |

---

## Best Practices

### 1. Security
- **Never store API keys in shared folders**
- Use environment variables exclusively for secrets
- Keep `api-tokens.md` as a reference (token names only, not values)
- Restrict shared folder write access to operator commands only

### 2. Resource Management
- Each instance consumes memory (~300-500MB)
- Monitor with `ps aux | grep openclaw`
- Consider shutting down unused instances to save resources

### 3. Naming Conventions
- Use consistent short names (C, D, G) across all documentation
- Prefix shared files with the creating bot's identifier when relevant
- Keep shared settings in a single `setting/` directory

### 4. Communication Protocol
- Define clear rules for when bots should respond vs. stay silent
- Use a designated leader for conflict resolution
- Batch periodic checks to reduce API costs

### 5. Maintenance
- Regularly review and clean shared folders
- Keep instance configurations in sync with shared rules
- Update all instances together when upgrading OpenClaw:
  ```bash
  npm update -g openclaw
  # Then restart all instances
  ```

### 6. Monitoring and Logging
- **Process monitoring**: Use `ps aux | grep openclaw` to check all running instances
- **Memory usage**: Monitor with `top` or `htop`; each instance uses ~300-500MB
- **Log files**: Each instance logs to its own directory:
  ```bash
  # View logs for a specific instance
  tail -f ~/.openclaw-<name>/logs/gateway.log
  
  # Check for errors
  grep -i error ~/.openclaw-<name>/logs/gateway.log | tail -20
  
  # Monitor all instances at once
  for dir in ~/.openclaw ~/.openclaw-deepseek ~/.openclaw-gemini; do
    echo "=== $(basename $dir) ==="
    tail -5 "$dir/logs/gateway.log" 2>/dev/null || echo "No logs found"
  done
  ```
- **Health checks**: Create a cron job to periodically check instance health:
  ```bash
  # Health check script
  for name in openclaw openclaw-deepseek openclaw-gemini; do
    if ps aux | grep -v grep | grep -q "$name"; then
      echo "✅ $name is running"
    else
      echo "❌ $name is NOT running"
    fi
  done
  ```

### 7. Backup and Recovery
- **Configuration backup**: Regularly backup instance configurations:
  ```bash
  # Backup all instance configs
  backup_dir="~/openclaw-backup/$(date +%Y%m%d)"
  mkdir -p "$backup_dir"
  
  for dir in ~/.openclaw ~/.openclaw-deepseek ~/.openclaw-gemini; do
    if [ -d "$dir" ]; then
      cp -r "$dir/config.yaml" "$backup_dir/$(basename $dir)-config.yaml"
      echo "Backed up $(basename $dir)"
    fi
  done
  
  # Backup shared folder
  tar -czf "$backup_dir/shared.tar.gz" ~/shared/
  ```
- **Workspace backup**: Backup memory and soul files:
  ```bash
  # Backup workspace files
  for dir in ~/.openclaw ~/.openclaw-deepseek ~/.openclaw-gemini; do
    if [ -d "$dir/workspace" ]; then
      tar -czf "$backup_dir/$(basename $dir)-workspace.tar.gz" -C "$dir" workspace/
    fi
  done
  ```
- **Recovery procedure**:
  1. Stop all instances: `pkill -f openclaw-gateway`
  2. Restore configurations: `cp backup/config.yaml ~/.openclaw-<name>/`
  3. Restore workspace: `tar -xzf backup/workspace.tar.gz -C ~/.openclaw-<name>/`
  4. Restore shared folder: `tar -xzf backup/shared.tar.gz -C ~/`
  5. Restart instances
- **Automated backup**: Create a cron job for weekly backups:
  ```bash
  # Add to crontab (runs every Sunday at 2 AM)
  0 2 * * 0 /path/to/backup-script.sh
  ```

---

## Troubleshooting

### Instance Won't Start

```bash
# Check if another instance is using the same bot token
ps aux | grep openclaw

# Verify configuration
OPENCLAW_HOME=~/.openclaw-<name> openclaw doctor
```

### Bot Not Responding in Group

1. Verify the bot is added to the group with admin rights
2. Check that `allowFrom` includes `"*"` or the specific user ID
3. Ensure `dmPolicy: open` is set
4. Check logs: `tail -f ~/.openclaw-<name>/logs/gateway.log`

### Telegram Token Conflict

**Symptom**: One bot goes offline when another starts.

**Cause**: Two instances using the same bot token.

**Fix**: Each instance must have a unique Telegram bot token. Create separate bots via @BotFather.

### Shared Folder Permission Issues

```bash
# Ensure all instances can read/write
chmod -R 755 ~/shared/

# Check ownership
ls -la ~/shared/
```

### Cron Jobs Not Firing

- Use `isolated` + `agentTurn` + `delivery` for group chat reminders
- Avoid `main` + `systemEvent` in multi-bot group scenarios
- Verify timezone calculations (Beijing Time = UTC + 8)
- See `~/shared/setting/cron-config-guide.md` for details

### High Memory Usage

```bash
# Check per-instance memory
ps aux | grep openclaw-gateway | awk '{print $11, $6/1024 "MB"}'

# Restart a specific instance
# Find and kill the process, then relaunch
kill <PID>
```

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `OPENCLAW_HOME=~/.openclaw-<name> openclaw gateway` | Start instance |
| `OPENCLAW_HOME=~/.openclaw-<name> openclaw gateway status` | Check status |
| `ps aux \| grep openclaw` | List all running instances |
| `ls ~/shared/setting/` | View shared configuration |
| `cat ~/shared/setting/机器人简称对照表.md` | View bot roster |

---

> **Next step:** Once this file is complete, save it in the shared `GitHub` folder. Other team members will handle uploading it to the repository.
