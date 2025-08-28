#!/usr/bin/env bash
set -euo pipefail

# Detect container runtime and appropriate compose command
# Exports:
#   RUNTIME - either 'docker' or 'podman'
#   COMPOSE - compose command (e.g., 'docker compose')

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    RUNTIME="docker"
    COMPOSE="docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    RUNTIME="docker"
    COMPOSE="docker-compose"
  else
    echo "Docker found but no compose support available" >&2
    exit 1
  fi
elif command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
  if podman compose version >/dev/null 2>&1; then
    RUNTIME="podman"
    COMPOSE="podman compose"
  else
    echo "Podman found but podman compose is not available" >&2
    exit 1
  fi
else
  echo "Neither Docker nor Podman found" >&2
  exit 1
fi

export RUNTIME COMPOSE
