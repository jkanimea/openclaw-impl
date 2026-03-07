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

### 3. Access OpenClaw
- **Web UI**: [https://localhost:8443](https://localhost:8443) (Bypass security warnings)
- **KDE Desktop**: [http://localhost:3002](http://localhost:3002)

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
