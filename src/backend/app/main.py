from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import admin, analytics, auth, caregiver, difficulty, patients, risk, sync, voice
from app.database import init_db

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


@app.get("/health")
def health():
    return {"status": "ok"}
