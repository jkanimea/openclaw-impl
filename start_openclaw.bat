@echo off
REM OpenClaw Startup Script for Windows
REM Run this after starting the podman containers

echo Starting OpenClaw Gateway...

REM Start gateway and restart Caddy
podman exec -d openclaw_gui_v2 sh -c "cd /config/openclaw && nohup node dist/index.js gateway run --force > /config/gateway.log 2>&1 &"
timeout /t 10 /nobreak > nul
podman restart caddy_openclaw_proxy

echo.
echo OpenClaw should be available at https://localhost:8443/
pause
