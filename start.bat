@echo off
setlocal enabledelayedexpansion

REM Rocket.Chat Observability Stack - One-Click Startup Script for Windows
REM This script provides a simple way to get started with minimal configuration

echo 🚀 Rocket.Chat Observability Stack - One-Click Startup
echo ==================================================
echo.

REM Check if we're in the right directory
if not exist "compose.yml" (
    echo [ERROR] Please run this script from the rocketchat-observability directory
    pause
    exit /b 1
)

REM Detect container runtime
echo [INFO] Detecting container runtime...
set "COMPOSE="
set "ENVARG=--env-file .env"

docker compose version >nul 2>&1
if %errorlevel%==0 (
    set "COMPOSE=docker compose"
    echo [SUCCESS] Detected Docker Compose plugin
) else (
    docker-compose --version >nul 2>&1
    if %errorlevel%==0 (
    set "COMPOSE=docker-compose"
    set "ENVARG="
    echo [SUCCESS] Detected Docker Compose legacy
    ) else (
        podman compose version >nul 2>&1
        if %errorlevel%==0 (
            set "COMPOSE=podman compose"
            echo [SUCCESS] Detected Podman Compose
        ) else (
            echo [ERROR] Neither Docker Compose nor Podman Compose found.
            echo        Install Docker Desktop (with Compose) or Podman Compose.
            pause
            exit /b 1
        )
    )
)

REM Setup environment file
if not exist ".env" (
    echo [INFO] Creating .env file from template...
    copy .env.example .env >nul
    echo [SUCCESS] .env file created with default settings
    echo [WARNING] You can edit .env to customize ports, passwords, etc.
) else (
    echo [INFO] .env file already exists
)

REM Start the stack
echo [INFO] Starting Rocket.Chat Observability Stack...

REM Validate configuration first
echo [INFO] Validating configuration...
%COMPOSE% %ENVARG% -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml config >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Configuration validation failed. Showing details:
    echo --------------------------------------------------
    %COMPOSE% %ENVARG% -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml config
    echo --------------------------------------------------
    echo.
    echo Tip: Ensure all variables in .env are set and valid.
    pause
    exit /b 1
)

REM Start services
%COMPOSE% %ENVARG% -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml up -d
if %errorlevel% neq 0 (
    echo [ERROR] Failed to start services
    pause
    exit /b 1
)

echo [SUCCESS] Stack started successfully!
echo.
echo 🎉 Rocket.Chat Observability Stack is now running!
echo.
echo 📱 Access your services:
echo    • Rocket.Chat: http://localhost:3000
echo    • Grafana: http://localhost:5050
echo      - Username: admin
echo      - Password: rc-admin
echo    • Prometheus: http://127.0.0.1:9000
echo    • Traefik Dashboard: http://localhost:8080
echo.
echo 🔧 Useful commands:
echo    • View logs: make logs
echo    • Check status: make status
echo    • Stop stack: make down
echo    • Full help: make help
echo.
echo [WARNING] First startup may take a few minutes. Services will be ready when all containers show 'healthy' status.
echo.
pause
