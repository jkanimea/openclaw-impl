# OpenClaw Troubleshooting Master Log (Consolidated)

### Issue: Agent Uses Web Search Instead of Browser for YouTube
**Scenario**: Agent uses DuckDuckGo web search instead of opening browser to navigate YouTube.
**Cause**: Browser tool is not enabled in openclaw.json.
**Resolution**:
1. Enable browser tool in openclaw.json:
   ```json
   "tools": {
     "web": {
       "search": {
         "provider": "duckduckgo",
         "enabled": true
       }
     },
     "browser": {
       "enabled": true
     }
   }
   ```
2. Update openclaw_container.json (local backup):
   ```bash
   podman cp openclaw_container.json openclaw_gui_v2:/config/.openclaw/.openclaw/openclaw.json
   ```
3. Restart gateway:
   ```bash
   podman exec openclaw_gui_v2 sh -c "pkill -f openclaw-gateway || true"
   podman exec -d openclaw_gui_v2 sh -c "cd /config/openclaw && nohup node dist/index.js gateway run --force > /config/gateway.log 2>&1 &"
   ```

### Issue: Container Loses Node.js After Restart
**Cause**: The webtop container image doesn't include Node.js. It must be installed after first start.
**Resolution**:
1. After container starts, install Node.js:
   ```bash
   podman exec -u root openclaw_gui_v2 sh -c "curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y nodejs"
   ```
2. Start gateway:
   ```bash
   podman exec -d openclaw_gui_v2 sh -c "cd /config/openclaw && nohup node dist/index.js gateway run --force > /config/gateway.log 2>&1 &"
   ```

### Issue: Editing openclaw.json - Config Files Not Visible in Project Folder
**Scenario**: The `openclaw.json` and agent configs are stored in a Podman volume, not visible in the host filesystem.
**Cause**: docker-compose.yml was using `config_vol:/config` (Podman managed volume).
**Resolution**:
1. Changed docker-compose.yml to mount host folder instead:
   ```yaml
   volumes:
     - ./openclaw_data:/config
   ```
2. Config files are now in `openclaw_data/.openclaw/` on the host:
   - `openclaw.json` - Main gateway config
   - `agents/main/agent/agent.json` - Agent tool config
   - `agents/main/agent/models.json` - Model context window settings
3. After editing, restart gateway:
   ```bash
   podman exec openclaw_gui_v2 sh -c "pkill -f openclaw-gateway || true"
   podman exec -d openclaw_gui_v2 sh -c "cd /config/openclaw && nohup node dist/index.js gateway run --force > /config/gateway.log 2>&1 &"
   ```

### Issue: Slow Response Times / High CPU Usage (GPU Acceleration Fix)
**Scenario**: Model generation is slow (longer than a few seconds) or causing high CPU usage because Ollama is running in a CPU-only Podman container.
**Resolution**:
1. **Containerized GPU (Hyper-Speed)**: Use Podman's CDI (Container Device Interface) to pass the NVIDIA GPU directly to the Ollama container.
   - **Requirement**: Install `nvidia-container-toolkit` in the WSL distribution and generate CDI spec (`nvidia-ctk cdi generate`).
   - **Compose Config**: Use the `devices` mapping with the CDI string: `nvidia.com/gpu=all`.
2. **Hybrid Setup**: Use the native **Ollama for Windows** (host) instead of the containerized version.
   - Set `baseUrl` in `openclaw.json` to `http://host.containers.internal:11434`.
3. **Performance Gain**: Responses for a 2B model should be near-instant (typically < 1 second).

### Issue: "control ui requires device identity" or "WebCrypto API missing"
**Cause**: OpenClaw UI disables crypto interfaces (required for device identity auth) when accessed via IP addresses because browsers consider IPs to be "insecure contexts".
**Resolution**: 
1. The fastest native fix is to use your machine's IPv6 localhost address directly instead of the IP: `http://[::1]:18789`.
2. Alternatively, a Caddy proxy container was added to serve local trusted HTTPS via `mkcert` on `https://localhost:8443`.
3. **Configuration**: Modify `openclaw.json` to include `"dangerouslyAllowHostHeaderOriginFallback": true` and `"allowInsecureAuth": true` for local development.

### Issue: "pairing required" / Approval Loop
**Scenario**: Even with the correct token, you get "pairing required" and are stuck in a loop.
**Resolution**:
1. List pending devices:
   ```bash
   podman exec openclaw_gui_v2 sh -c "cd /config/openclaw && node dist/index.js devices list"
   ```
2. Approve each pending device using the Request ID (first column):
   ```bash
   # Replace <REQUEST_ID> with the ID from the Request column (e.g., 16b996fd-eb64-465b-89e5-2c0d1fc23673)
   podman exec openclaw_gui_v2 sh -c "cd /config/openclaw && node dist/index.js devices approve <REQUEST_ID>"
   ```
3. Verify approved devices:
   ```bash
   podman exec openclaw_gui_v2 sh -c "cd /config/openclaw && node dist/index.js devices list"
   ```

### Issue: "ERR_CONNECTION_REFUSED" on port 3001
**Cause**: Port `3001` is often locked by Windows WSL or system processes.
**Resolution**: Changed the Webtop desktop mapping to port `3002`. Access the GUI at `http://localhost:3002`.

### Issue: Webtop WebSocket Disconnecting Constanty
**Cause**: Permission mismatch on the `/config` directory when mounted from Windows NTFS.
**Resolution**: Switched to a managed Podman volume `config_vol:/config` which natively handles Linux file permissions (`abc:users`).

### Issue: Ollama Model Loading Errors (500)
**Cause**: Context window too large (KV Cache overflow) or Memory exhausted.
**Resolution**:
1. Set `contextWindow` to exactly `16384` in both global and agent-specific `models.json`.
2. Ensure `OLLAMA_KEEP_ALIVE=24h` is set to keep models in memory.
3. Use the host GPU whenever possible to offload processing from the container's CPU.

### Issue: 502 Bad Gateway (Caddy)
**Cause**: Gateway Node process crashed (usually syntax error in `openclaw.json`) or Node.js missing after an image upgrade.
**Resolution**: 
1. Re-install Node 22.x inside the container.
2. Verify `openclaw.json` syntax (ensure no missing commas).
3. Trust the proxy in `openclaw.json`: `"trustedProxies": ["10.89.0.0/16", "127.0.0.1"]`.

### Issue: Web Fetch 401 Error (Anti-bot blockage)
**Scenario**: Trying to fetch sites like Reuters or major news outlets results in a `401 Unauthorized` or "Please enable JS" error.
**Cause**: These sites use anti-bot security (e.g., DataDome). OpenClaw's default direct fetch is blocked, and the Firecrawl fallback requires an API key.
**Resolution (No-API Workaround)**:
1. **Enable Browser Tool**: OpenClaw includes a `browser` tool that uses a hidden Chromium instance. This tool can bypass most anti-bot mirrors.
2. **Agent Config**: In `/config/.openclaw/agents/main/agent/agent.json`, add:
   ```json
   "tools": { "allow": ["all"] }
   ```
3. **Manual Search**: If you don't have a Search API key (Brave/Google), ask the agent to: *"Use the browser to go to Google and search for [topic]"*.

### Issue: Persistent 502 Bad Gateway (Internal Resolution)
**Cause**: Caddy intermittently fails to resolve the internal container name `ubuntu-gui` or hits a "ghost" process lock on port 18789.
**Resolution**:
1. Use the explicit internal IP of the GUI container in the `Caddyfile`:
   ```caddy
   reverse_proxy 10.89.0.2:18789
   ```
2. If the port is locked by a ghost process, kill it: `podman exec -u root openclaw_gui_v2 fuser -k 18789/tcp`.
3. Restart Caddy: `podman restart caddy_openclaw_proxy`.

### Issue: Connectivity / Internet Access
**Test**: Verify internet from GUI container: `podman exec openclaw_gui_v2 curl -I https://www.google.com`.
**Fix**: If no access, restart the Podman machine: `podman machine stop && podman machine start`.

### Issue: 502 Bad Gateway (Invalid Config / IP Mismatch)
**Cause**: 
1. `openclaw.json` contained an unrecognized key `tools` under `agents.defaults` or at the root, causing the gateway to fail at startup without obvious logs in the container stdout.
2. The `Caddyfile` was pointing to an outdated internal container IP. The GUI container IP is assigned dynamically by Podman and can change upon restart (e.g., from `10.89.0.2` to `10.89.0.6`).
**Resolution**:
1. Check process run status: `podman exec openclaw_gui_v2 npx pm2 status` or `podman exec openclaw_gui_v2 ss -tlnp | grep 18789`.
2. Inspect `openclaw.json` for syntax errors or invalid root elements: `podman cp openclaw_gui_v2:/config/.openclaw/openclaw.json openclaw_container.json`.
3. Find the actual GUI container IP and verify it matches the Caddyfile: `podman inspect -f "{{.NetworkSettings.IPAddress}}" openclaw_gui_v2` or `podman exec openclaw_gui_v2 ip -4 addr show eth0`.
4. Update the `Caddyfile` with the correct container IP and restart Caddy: `podman restart caddy_openclaw_proxy`.
5. Start gateway directly to view hidden errors: `podman exec openclaw_gui_v2 sh -c "cd /config/openclaw && node dist/index.js gateway run"`
### Issue: 503 Service Unavailable / "Control UI assets not found"
**Cause**: The Gateway started successfully but the `dist/control-ui` directory is missing because the frontend was never compiled. If the Gateway was already running when the assets were missing, it explicitly caches this failure state and will continue throwing 503s even after you build the assets.
**Resolution**: 
1. Run the UI build script inside the container: `podman exec openclaw_gui_v2 sh -c "cd /config/openclaw && npx pnpm ui:build"`

> [!IMPORTANT]
> Running a full `podman exec openclaw_gui_v2 sh -c "cd /config/openclaw && npx pnpm build"` (which compiles the backend) will often clear the `dist` folder and **delete your UI assets**. If you rebuild the backend, you almost always need to follow up with `pnpm ui:build`.

2. **Crucial Next Step**: You MUST restart the Gateway process so it can discover the newly built assets. If the standard container restart fails due to ghost lockfiles (see below), run:
`podman exec -d openclaw_gui_v2 sh -c "cd /config/openclaw && nohup node dist/index.js gateway run --force > /config/openclaw/gateway.log 2>&1 &"`

### Issue: "unknown command 'call'" or missing DuckDuckGo configuration
**Cause**: Making code edits in the `src_copy` (or local `src`) directory does not automatically compile them to the `dist` directory that the container uses to run the process.
**Resolution**:
1. Copy changes to the container (if edited locally instead of via a bind mount).
2. Fix any TypeScript errors (e.g. invalid escape sequences in `tsconfig.json`).
3. Compile the changes inside the container bypassing full UI failures: `podman exec openclaw_gui_v2 sh -c "cd /config/openclaw && npx pnpm tsdown"`
4. Restart the container: `podman restart openclaw_gui_v2`

### Issue: "The value of 'delay' is out of range. It must be an integer. Received NaN"
**Cause**: DuckDuckGo search invocation attempts to set a timeout parameter via `AbortSignal.timeout(delay)`. Default config parsing via `resolveTimeoutSeconds` wasn't strictly guarding against `undefined` inputs passed down from `tools.web.search.timeoutSeconds`. When `fallback` was `undefined`, it produced `Math.floor(NaN)`, crashing Node `fetch`.
**Resolution**:
1. Modified `src/agents/tools/web-shared.ts` to explicitly check numeric integrity.
2. Rebuilt the TypeScript container dist via `podman exec openclaw_gui_v2 sh -c "cd /config/openclaw && npx pnpm build"`.
3. Restarted `openclaw_gui_v2`. Agent DuckDuckGo searching works consistently.

### Issue: 502 Bad Gateway - Ghost Lockfiles Blocking Port 18789 (Address already in use)
**Symptom**:
After restarting the container, `https://localhost:8443` returns 502 Bad Gateway. Inside the container, `/config/openclaw/gateway.log` shows `Gateway is binding to a non-loopback address` then silently dies, but `pm2 status` shows nothing and `ss -tlnp` shows port 18789 is unused.

**Cause**:
A previous run of the `openclaw-gateway` process crashed or was killed abruptly (e.g. `killall` or container stopping), leaving behind a `.lock` file in `/tmp/openclaw-0/` that prevents the Node server from initializing a new listener. 

**Resolution**:
Run the gateway with the built-in force command to automatically clear phantom port bindings and flush old socket locks:
`podman exec -d openclaw_gui_v2 sh -c "cd /config/openclaw && nohup node dist/index.js gateway run --force > /config/openclaw/gateway.log 2>&1 &"`

### Issue: DuckDuckGo Results Formatted Poorly (Ads and Raw HTML)
**Symptom**:
Search results for "weather" or other common terms contain hotel ads, sponsored links, and raw HTML fragments like `<<<EXTERNAL_UNTRUSTED_CONTENT>>>`.

**Cause**:
The original `parseDuckDuckGoHtml` regex was too generic, picking up advertisement containers that use the same class names as organic results. It also failed to strip HTML entities and tags from titles and snippets.

**Resolution**:
1. Updated `src/agents/tools/web-search.ts` with a robust parser that identifies and skips `result--ad` and `ad_provider` blocks.
2. Implemented a data-cleaning step to strip HTML tags and entities from the search result strings before returning them to the model.

### Issue: Project Rebuild Fails (TypeScript Overlap Errors)
**Symptom**:
Running `pnpm build` inside the container fails with errors in `web-search.ts` (signature mismatch) and `memory-search.ts` (Narrowed type comparison overlap).

**Cause**:
The container's source code was slightly out of sync with the local development branch, and newer TypeScript checks caught instances where the `provider` type narrowing prevented a valid comparison with `"ollama"`.

**Resolution**:
1. Patched `web-search.ts` to use individual arguments for `runDuckDuckGoSearch`.
2. Patched `memory-search.ts` with `(provider as any)` casts to bypass the restricted type checks.
3. Re-ran `pnpm build` and `pnpm ui:build` to deploy the fixes.

---
*Documented by Antigravity.*

