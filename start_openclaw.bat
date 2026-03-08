@echo off
REM OpenClaw Startup Script for Windows
REM Run this after starting the podman containers

echo === OpenClaw Startup Script ===

REM Check if Node.js is already installed
echo Checking if Node.js is installed...
podman exec openclaw_gui_v2 sh -c "command -v node" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Node.js not found. Installing...
    podman exec -u root openclaw_gui_v2 sh -c "curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y nodejs" >nul 2>&1
    echo Node.js installed.
) else (
    echo Node.js already installed. Skipping.
)

REM Check if gateway is already running
echo Checking if gateway is running...
podman exec openclaw_gui_v2 sh -c "ss -tlnp | grep -q 18789" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Gateway not running. Starting...
    podman exec openclaw_gui_v2 sh -c "cd /config/openclaw && nohup node dist/index.js gateway run --force > /config/gateway.log 2>&1 &"
    timeout /t 10 /nobreak >nul
) else (
    echo Gateway already running. Skipping.
)

REM Always restart Caddy to ensure connection
echo Restarting Caddy proxy...
podman restart caddy_openclaw_proxy >nul 2>&1

echo.
echo === OpenClaw Started ===
echo Access https://localhost:8443/
