# OpenClaw + Claude Max (Docker Compose)

Run **OpenClaw** AI Agent connected to **Telegram**, powered by **Claude Max subscription** instead of pay-per-token API keys.

## Architecture

```
┌──────────┐    ┌─── Docker Compose ──────────────────────────────────────┐
│ Telegram │───▶│                                                         │
│ (User)   │◀───│  ┌──────────┐   ┌──────────────────┐   ┌────────────┐  │
└──────────┘    │  │ OpenClaw │──▶│ Claude Proxy (Go)│──▶│ Claude CLI │  │
                │  │ :18789   │   │ :8080            │   │ (claude -p)│  │
┌──────────┐    │  │ AI Agent │   │ OpenAI-compatible│   │ OAuth Max  │  │
│ Dashboard│───▶│  │ Telegram │   │ FlexContent patch│   └─────┬──────┘  │
│ (Browser)│    │  └──────────┘   └──────────────────┘         │         │
└──────────┘    │                                              │         │
                │                                    ┌─────────▼───────┐ │
                │                                    │ Anthropic API   │ │
                │                                    │ (quota Claude   │ │
                │                                    │  Max, no API$)  │ │
                │                                    └─────────────────┘ │
                └─────────────────────────────────────────────────────────┘
                                      │
                               mount: ~/.claude/
                          (OAuth token from host)
```

- **OpenClaw**: AI Agent framework, connects to Telegram/WhatsApp/Discord
- **Claude Proxy**: Go proxy that translates OpenAI API requests into `claude -p` CLI calls
- **Claude Code CLI**: Anthropic's official CLI, authenticated with Claude Max subscription

**Result**: Use Claude Max quota ($100-200/month, flat-rate) instead of pay-per-token API billing.

---

## Prerequisites

- **Docker** + **Docker Compose** (v2)
- **Claude Max subscription** (Claude Code CLI logged in on host machine)
- **Telegram account** (to create a bot)

---

## Step 1: Install Claude Code CLI + Log in to Claude Max

The Docker container mounts `~/.claude/` from the host machine to use the OAuth token. You need to install and log in to the CLI on the host first.

### 1.1 Install Claude Code CLI

**Linux / macOS:**

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://claude.ai/install.ps1 | iex
```

Add to PATH if needed:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Verify:

```bash
claude --version
```

### 1.2 Log in to Claude Max

```bash
claude login
```

The terminal will display:

```
To login, open this URL in your browser:
https://claude.ai/oauth/authorize?code=XXXXXX

Waiting for authentication...
```

**Steps:**

1. Copy the URL
2. Open it in a browser (desktop or mobile)
3. Log in with your **Claude Max** account ($100-200/month subscription)
4. Click **Authorize** — the terminal will detect it automatically

> If the host has no browser (e.g., a VPS), copy the URL and open it on another machine.

Verify login:

```bash
claude auth status
```

### 1.3 Test the CLI

```bash
claude -p "Hello, reply briefly"
```

If you see a response — the CLI is successfully using your Max quota.

### 1.4 Verify the token directory

```bash
ls ~/.claude/
```

You should see files like `.credentials.json`, `settings.json`, etc. This is the directory Docker will mount (read-only) into the proxy container.

> **Security**: The `~/.claude/` directory contains your OAuth token. Do not share it. The token auto-refreshes and does not require re-login unless revoked.

---

## Step 2: Create a Telegram Bot

### 2.1 Create bot via @BotFather

1. Open Telegram, search for **@BotFather** (verified with blue checkmark)
2. Send `/start`
3. Send `/newbot`
4. Enter a **display name** for your bot:
   ```
   My AI Assistant
   ```
5. Enter a **username** (must end with `bot`):
   ```
   my_ai_openclaw_bot
   ```
6. BotFather returns a **token**:
   ```
   Use this token to access the HTTP API:
   7123456789:AAHxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```
   **Copy this token** — you'll need it in step 3.

### 2.2 Additional configuration (optional)

Send these commands to @BotFather:

| Command | Description |
|---------|-------------|
| `/setdescription` | Bot description shown when a user opens the chat for the first time |
| `/setabouttext` | About text shown in the bot's profile |
| `/setuserpic` | Bot profile picture |
| `/setprivacy` → `Disable` | Allow bot to read group messages (without @mention) |

> **Security**: The bot token grants full control over the bot. Never share it. If compromised, send `/revoke` to @BotFather to generate a new one.

---

## Step 3: Configure Docker Compose

```bash
cd docker/
cp .env.example .env
```

Edit the `.env` file:

```env
# Telegram bot token (from @BotFather in step 2)
TELEGRAM_BOT_TOKEN=7123456789:AAHxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Proxy port (default 8080)
PROXY_PORT=8080

# OpenClaw dashboard port (default 18789)
GATEWAY_PORT=18789

# Dashboard access token (generate a random one)
DASHBOARD_TOKEN=your-random-token-here

# Path to ~/.claude on the HOST machine
CLAUDE_CONFIG_HOST=~/.claude

# OpenClaw data directory
OPENCLAW_DATA=./data
```

### Generate a random dashboard token:

```bash
openssl rand -hex 24
```

---

## Step 4: Start the services

```bash
cd docker/
docker compose up -d
```

Verify:

```bash
# Check status
docker compose ps

# View proxy logs
docker compose logs claude-proxy -f

# View OpenClaw logs
docker compose logs openclaw -f
```

### Test proxy:

```bash
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer not-needed" \
  -d '{
    "model": "claude-sonnet-4-6-20250620",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

---

## Step 5: Connect Telegram

### 5.1 Message the bot

Open Telegram, find your bot by its username, and send any message (e.g., "Hello").

The bot will reply with a **pairing code**:

```
To continue, ask your admin to approve pairing code: ABC12345
```

### 5.2 Approve the pairing

```bash
# List pending pairing requests
docker compose exec openclaw openclaw pairing list telegram

# Approve
docker compose exec openclaw openclaw pairing approve telegram <CODE>
```

### 5.3 Test

Send a message to the bot on Telegram — it should reply using Claude AI.

---

## Changing models

Available models:

| Model ID | Name | Note |
|---|---|---|
| `claude-sonnet-4-20250514` | Claude Sonnet 4 | |
| `claude-sonnet-4-6-20250620` | Claude Sonnet 4.6 | **Default** |
| `claude-opus-4-6-20250620` | Claude Opus 4.6 | Most capable |
| `claude-haiku-4-5-20251001` | Claude Haiku 4.5 | Fastest |

### Change model on a running container:

```bash
docker compose exec openclaw node -e "
const fs = require('fs');
const cfg = JSON.parse(fs.readFileSync('/home/node/.openclaw/openclaw.json','utf8'));
cfg.agents.defaults.model.primary = 'claude-max/claude-opus-4-6-20250620';
delete cfg.agents.defaults.models;
cfg.agents.defaults.models = {'claude-max/claude-opus-4-6-20250620': {streaming: false}};
fs.writeFileSync('/home/node/.openclaw/openclaw.json', JSON.stringify(cfg, null, 2));
console.log('Done');
"
docker compose restart openclaw
```

### Change default model (for fresh setup):

Edit `docker/config/openclaw.json`, find:

```json
"primary": "claude-max/claude-sonnet-4-6-20250620"
```

Replace with your desired model, e.g.:

```json
"primary": "claude-max/claude-opus-4-6-20250620"
```

---

## Dashboard

Access the OpenClaw dashboard:

```
http://localhost:18789?token=<DASHBOARD_TOKEN>
```

`DASHBOARD_TOKEN` is the value from your `.env` file.

---

## Directory structure

```
openclaw/
├── README.md                    # This file
├── SETUP_GUIDE.md               # Manual VPS setup guide (without Docker, Vietnamese)
├── docker/
│   ├── docker-compose.yml       # Main Docker Compose file
│   ├── .env.example             # Environment variables template
│   ├── .env                     # Environment variables (secrets, not committed)
│   ├── config/
│   │   ├── Dockerfile.proxy     # Multi-stage build: Go proxy + Claude CLI
│   │   ├── patch-proxy.sh       # Patch proxy to support array content format
│   │   ├── openclaw.json        # OpenClaw config template
│   │   ├── models.json          # Model definitions template
│   │   └── auth-profiles.json   # Auth profiles template
│   └── data/                    # Runtime data (not committed)
│       └── openclaw/            # OpenClaw config + data (volume mount)
└── .gitignore
```

---

## Troubleshooting

### Proxy won't start

```bash
# Check if Claude CLI is logged in on the host
claude auth status

# Check volume mount
docker compose exec claude-proxy ls -la /root/.claude/
```

### Telegram bot not responding

```bash
# Verify bot token is valid
curl "https://api.telegram.org/bot<TOKEN>/getMe"

# Check logs
docker compose logs openclaw -f

# Check pairing status
docker compose exec openclaw openclaw pairing list telegram
```

### Error: "No API key found for provider anthropic"

OpenClaw is using model `anthropic/...` instead of `claude-max/...`. Check the config:

```bash
docker compose exec openclaw cat /home/node/.openclaw/openclaw.json | grep primary
```

It should be `claude-max/claude-sonnet-4-6-20250620` (or another model with the `claude-max/` prefix).

### HTTP 400 / Invalid JSON

The proxy can't parse the content format. Ensure `patch-proxy.sh` was applied during build:

```bash
docker compose build --no-cache claude-proxy
docker compose up -d
```

### Error 401 / Token expired

```bash
# Re-login on the host
claude login

# Restart proxy to pick up the new token
docker compose restart claude-proxy
```

### Dashboard not accessible

```bash
# Check ports
docker compose ps

# Check token
grep DASHBOARD_TOKEN docker/.env

# Access: http://localhost:18789?token=<TOKEN>
```

---

## Telegram DM policies

| Policy | Description | When to use |
|--------|-------------|-------------|
| `pairing` | User messages → receives code → admin approves | **Default, most secure** |
| `allowlist` | Only user IDs in the list can message | When you know who will use it |
| `open` | Anyone can message | Demo/testing only |

Change policy in config (`docker/config/openclaw.json` or live config):

```json
"channels": {
  "telegram": {
    "dmPolicy": "pairing"
  }
}
```

> Get your Telegram User ID: send `/start` to `@userinfobot`

---

## Technical notes

- **Go proxy** (`meaning-systems/claude-code-proxy`) is patched to support both content formats: string (`"content": "text"`) and array (`"content": [{"type":"text","text":"..."}]`)
- **OpenClaw container** runs as user `node`, config at `/home/node/.openclaw/`
- **Claude OAuth token** is mounted read-only from the host (`~/.claude:/root/.claude:ro`)
- **Concurrent requests**: Claude Max has rate limits based on subscription tier. The proxy processes requests serially (one at a time)
