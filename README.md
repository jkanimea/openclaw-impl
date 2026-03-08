# OpenClaw Docker/Podman Setup & GUI (v2026.3.3)

This environment provides a full Ubuntu KDE desktop and the OpenClaw Gateway service running inside Podman containers.

## 🚀 Quick Start (Windows)

### 1. Initialize Podman
Ensure your Podman Machine is running and healthy:
```powershell
podman machine start
# Verify the IP address if localhost:8443 is unreachable
wsl -d podman-machine-default ip -4 a show eth0
```

### 2. Start Containers
Run from this directory:
```powershell
podman compose up -d
```

### 3. Start Gateway (Required After Every Pod Restart)
After starting the pod, you MUST run these commands:
```powershell
# Install Node.js (only needed once after container is fresh)
podman exec -u root openclaw_gui_v2 sh -c "curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y nodejs"

# Start the gateway
podman exec -d openclaw_gui_v2 sh -c "cd /config/openclaw && nohup node dist/index.js gateway run --force > /config/gateway.log 2>&1 &"

# Restart Caddy proxy (to connect to gateway)
podman restart caddy_openclaw_proxy
```

Wait 10 seconds, then access https://localhost:8443/

### 3. Access OpenClaw
- **Web UI**: [https://localhost:8443](https://localhost:8443) (Bypass security warnings)
- **KDE Desktop**: [http://localhost:3002](http://localhost:3002)

### 4. Configuration Files
The OpenClaw config is stored in `openclaw_data/` on the host for easy editing:
```
openclaw_data/
└── .openclaw/
    ├── openclaw.json      # Main config (gateway, auth, tools)
    ├── agents/            # Agent configurations
    ├── models.json        # Model settings
    └── ...
```

**Editing Config**: Edit files directly in `openclaw_data/.openclaw/` on the host, then restart the gateway:
```powershell
podman exec openclaw_gui_v2 sh -c "pkill -f openclaw-gateway || true"
podman exec -d openclaw_gui_v2 sh -c "cd /config/openclaw && nohup node dist/index.js gateway run --force > /config/gateway.log 2>&1 &"
```

### 5. Default Auth Token
- **Token**: `c14b2b7664ad3f1ef2ab5d91206ad80931d0bf2b84a21e7b`

---

## 🔍 Resolved Features & Fixes

### 🌐 Web Search (DuckDuckGo)
The search tool has been fully patched to work without API keys:
- **Fast Execution**: Fixed the `NaN` timeout bug that caused 10-minute delays.
- **Clean Results**: Implemented ad-filtering and HTML cleaning for DuckDuckGo.
- **Provider**: Automatically defaults to `duckduckgo` in `openclaw.json`.

### 🛠️ Build & Compilation
If you modify the source code, use these commands to rebuild inside the container:
```bash
# 1. Compile Backend (Fixes TypeScript errors and logic)
podman exec openclaw_gui_v2 sh -c "cd /config/openclaw && npx pnpm build"

# 2. Rebuild UI Frontend (Crucial after backend build!)
podman exec openclaw_gui_v2 sh -c "cd /config/openclaw && npx pnpm ui:build"

# 3. Force Restart Gateway (Purges lockfiles and cache)
podman exec -d openclaw_gui_v2 sh -c "cd /config/openclaw && nohup node dist/index.js gateway run --force > /config/openclaw/gateway.log 2>&1 &"
```

---

## 📝 Troubleshooting & Logs
Refer to **[troubleshooting_log.md](troubleshooting_log.md)** for a detailed history of:
- **502/503 Gateway Errors**: Port locking and Caddy IP resolution.
- **TypeScript Overlap Errors**: `memory-search.ts` and `web-search.ts` patches.
- **UI Asset Missing**: How to recover the `dist/control-ui` folder.

### View Active Logs
```powershell
podman exec openclaw_gui_v2 tail -f /config/openclaw/gateway.log
```

---
*Maintained and documented by the Antigravity Agentic Assistant.*
