from fastapi import FastAPI, Response, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.routes import admin, analytics, auth, caregiver, difficulty, patients, risk, sync, voice
from app.database import db, init_db

app = FastAPI(title="Cognitive Assist API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(admin.router)
app.include_router(sync.router)
app.include_router(difficulty.router)
app.include_router(voice.router)
app.include_router(analytics.router)
app.include_router(caregiver.router)
app.include_router(patients.router)
app.include_router(patients.patient_alias_router)
app.include_router(risk.router)



@app.on_event("startup")
async def on_startup():
    await init_db()


@app.get("/health", status_code=status.HTTP_200_OK)
async def health():
    health_status = {
        "status": "healthy",
        "database": "connected",
    }

    try:
        # Run a minimal, lightweight ping against MongoDB
        # Using a low timeout ensures the health check fails fast rather than hanging
        await db.command("ping")
    except Exception as e:
        health_status["status"] = "unhealthy"
        health_status["database"] = f"disconnected: {str(e)}"

        # Return 503 so Render natively marks the instance as failing
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content=health_status,
        )

    return health_status


@app.get("/ping", status_code=status.HTTP_200_OK)
async def ping():
    return Response(content="pong", media_type="text/plain")
