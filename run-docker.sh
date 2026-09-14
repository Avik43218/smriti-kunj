#!/usr/bin/env bash
set -e

MONGO_CONTAINER="mongo-dev"

# Colors
C_RESET="\033[0m"
C_GREEN="\033[1;32m"
C_CYAN="\033[1;36m"
C_PURPLE="\033[1;35m"
C_YELLOW="\033[1;33m"

printf "${C_YELLOW}[SYSTEM]${C_RESET} │ Ensuring Podman MongoDB container is running...\n"
if podman ps -a --format "{{.Names}}" | grep -q "^${MONGO_CONTAINER}$"; then
  if ! podman ps --format "{{.Names}}" | grep -q "^${MONGO_CONTAINER}$"; then
    podman start "$MONGO_CONTAINER"
    printf "${C_GREEN}[MONGO]${C_RESET}  │ Started existing Podman container '${MONGO_CONTAINER}'.\n"
  else
    printf "${C_GREEN}[MONGO]${C_RESET}  │ Podman container '${MONGO_CONTAINER}' is already running.\n"
  fi
else
  printf "${C_YELLOW}[MONGO]${C_RESET}  │ Creating and starting Podman container '${MONGO_CONTAINER}'...\n"
  podman run -d --name "$MONGO_CONTAINER" -p 27017:27017 -v mongo-data:/data/db docker.io/library/mongo:latest
  printf "${C_GREEN}[MONGO]${C_RESET}  │ Podman container '${MONGO_CONTAINER}' created and started.\n"
fi

printf "\n${C_YELLOW}[SYSTEM]${C_RESET} │ Building & starting Docker containers for backend and frontend...\n"
docker compose up -d --build --force-recreate

printf "\n${C_GREEN}======================================================================${C_RESET}\n"
printf "  Services successfully started!\n"
printf "  - MongoDB (Podman):       localhost:27017 (Container: %s)\n" "$MONGO_CONTAINER"
printf "  - Backend API (Docker):   ${C_PURPLE}http://fedora:8000${C_RESET} (Docs: http://fedora:8000/docs)\n"
printf "  - Frontend Portal (Docker):${C_CYAN}http://fedora:5173${C_RESET}\n"
printf "  - Patient App:            Targeting ${C_PURPLE}http://fedora:8000${C_RESET} (Untouched)\n"
printf "${C_GREEN}======================================================================${C_RESET}\n"
printf "To view logs:   docker compose logs -f\n"
printf "To stop stack:  docker compose down\n\n"

# View backend logs
printf "${C_YELLOW}[BACKEND]${C_RESET}  │ Watching backend logs... (Press Ctrl + C to exit)\n"
docker logs -f smritikunj-backend
