# Podman Containerization Guide

This project supports running via **Podman** either using **Podman Compose** or native **Podman Pods**.

---

## Prerequisites
- [Podman](https://podman.io/) installed (`podman --version`)
- (Optional for Compose): `podman-compose` or `docker-compose`

---

## Method 1: Using Podman Compose (Recommended for Multi-Container Workflows)

Run the entire stack (MongoDB, FastAPI Backend, and Caregiver Frontend):

```bash
# Build and start all services in the background
podman compose up -d --build

# View logs in real-time
podman compose logs -f

# Check running status & health
podman compose ps

# Stop all services
podman compose down
```

### Available Endpoints:
- **Caregiver Web Dashboard**: [http://localhost:5173](http://localhost:5173)
- **FastAPI Documentation**: [http://localhost:8000/docs](http://localhost:8000/docs)
- **FastAPI Health Check**: [http://localhost:8000/health](http://localhost:8000/health)
- **MongoDB**: `mongodb://localhost:27017`

---

## Method 2: Using Native Podman Pod (`podman-run.sh`)

If you don't have `podman-compose` installed, you can use the bundled orchestrator script that uses native Podman Pods:

```bash
./podman-run.sh
```

### Why Podman Pods?
All containers run inside the `sih-pod` network namespace, meaning:
- Containers can reach each other via `localhost` (e.g. backend connects directly to `localhost:27017`).
- All ports (`27017`, `8000`, `5173`) are published at the pod boundary.
- Pressing `Ctrl + C` cleanly stops and tears down the pod.

---

## Connecting the Patient Mobile App (Flutter)

The Patient Flutter app (`src/patient_app`) runs on physical Android/iOS devices or emulators outside the container.

1. Connect your Android device via USB with USB debugging enabled.
2. Forward port 8000 so the device can access the containerized backend:
   ```bash
   adb reverse tcp:8000 tcp:8000
   ```
3. Run the Flutter app:
   ```bash
   cd src/patient_app
   flutter run
   ```

---

## Building Individual Container Images Manually

If you need to test or build container images individually:

### Backend
```bash
podman build -t sih-backend -f src/backend/Containerfile src/backend
```

Run standalone:
```bash
podman run -d --name sih-backend -p 8000:8000 \
  -e MONGODB_URL="mongodb://host.containers.internal:27017" \
  sih-backend
```

### Caregiver Frontend
```bash
podman build -t sih-frontend -f src/frontend/caregiver_app/Containerfile src/frontend/caregiver_app
```

Run standalone:
```bash
podman run -d --name sih-frontend -p 5173:80 sih-frontend
```

---

## Data Persistence & Storage Notes
MongoDB data is persisted using the named volume `mongo_data` (or `sih_mongo_data` in `podman-run.sh`).
To inspect or reset the database volume:
```bash
# List volumes
podman volume ls

# Reset database data
podman volume rm mongo_data
```
