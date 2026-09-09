#!/usr/bin/env bash

CONTAINER_NAME="mongo-dev"

# Color Palette
C_RESET="\033[0m"
C_MONGO="\033[1;32m"   # Neon Green
C_VITE="\033[1;36m"    # Cyan
C_API="\033[1;35m"     # Purple
C_SYS="\033[1;33m"     # Yellow

# Prefix Streamer: tags and aligns stdout/stderr in real time
tag_stream() {
  local tag="$1"
  local color="$2"
  while IFS= read -r line; do
    printf "${color}%-9s${C_RESET} │ %s\n" "$tag" "$line"
  done
}

# Auto-wipe: cleans up all child processes, pipes, and the Podman container
cleanup() {
  printf "\n${C_SYS}%-9s${C_RESET} │ Terminating all services...\n" "[SYSTEM]"
  trap - SIGINT SIGTERM EXIT
  kill 0 2>/dev/null
  podman stop -t 1 "$CONTAINER_NAME" >/dev/null 2>&1
  printf "${C_SYS}%-9s${C_RESET} │ All services terminated!\n" "[SYSTEM]"
  exit 0
}

# Trap INT, TERM, and EXIT signals
trap cleanup SIGINT SIGTERM EXIT

# 1. Start MongoDB via Podman (-a attaches logs to stream them cleanly)
printf "${C_SYS}%-9s${C_RESET} │ Spinning up MongoDB via Podman...\n" "[SYSTEM]"
podman start "$CONTAINER_NAME" 2>&1 \
  | tag_stream "[MONGO]" "$C_MONGO" &

# 2. Fire up the NPM dev server in an isolated subshell
if [ -d "src/frontend/caregiver_app" ]; then
  printf "${C_SYS}%-9s${C_RESET} │ Preparing & launching Vite dev server...\n" "[SYSTEM]"
  (
    cd src/frontend/caregiver_app || exit 1
    if [ ! -d "node_modules" ] || [ ! -d "dist" ]; then
      npm install
      npm run build
    fi
    exec npm run dev
  ) 2>&1 | tag_stream "[VITE]" "$C_VITE" &
fi

# 3. Launch FastAPI server with Uvicorn
if [ -d "src/backend" ]; then
  printf "${C_SYS}%-9s${C_RESET} │ Starting FastAPI server...\n" "[SYSTEM]"
  uvicorn app.main:app --host 0.0.0.0 --port 8000 --app-dir src/backend --reload 2>&1 \
    | tag_stream "[API]" "$C_API" &
fi

printf "${C_SYS}%-9s${C_RESET} │ Hit [Ctrl + C] right here to kill everything.\n" "[SYSTEM]"

# Block and hold the main process so traps stay armed
wait
