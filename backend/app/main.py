import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import models
from .database import engine
from .routers import (
    alerts,
    appointments,
    auth,
    diagnoses,
    doctors,
    family,
    locations,
    medical_notes,
    medication_intakes,
    medications,
    patient_allergies,
    patients,
    prescriptions,
    questionnaires,
)

app = FastAPI()
models.Base.metadata.create_all(bind=engine)


def _build_cors_origins() -> list[str]:
    configured = os.getenv("CORS_ORIGINS", "").strip()
    if configured:
        return [origin.strip() for origin in configured.split(",") if origin.strip()]
    return [
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://localhost:8000",
        "http://127.0.0.1:8000",
    ]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_build_cors_origins(),
    allow_origin_regex=(
        r"https?://("
        r"localhost|127\.0\.0\.1|0\.0\.0\.0|"
        r"192\.168\.\d{1,3}\.\d{1,3}|"
        r"10\.\d{1,3}\.\d{1,3}\.\d{1,3}|"
        r"172\.(1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3}"
        r")(:\d+)?"
    ),
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept", "Origin"],
)

@app.get("/")
def root():
    return {"message": "PCD Backend Running"}

app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(doctors.router, prefix="/doctors", tags=["doctors"])
app.include_router(family.router, prefix="/family", tags=["family"])
app.include_router(patients.router, prefix="/patients", tags=["patients"])
app.include_router(
    appointments.router,
    prefix="/appointments",
    tags=["appointments"],
)
app.include_router(
    medications.router,
    prefix="/medications",
    tags=["medications"],
)
app.include_router(
    medication_intakes.router,
    prefix="/medication-intakes",
    tags=["medication-intakes"],
)
app.include_router(prescriptions.router, tags=["prescriptions"])
app.include_router(patient_allergies.router, tags=["patient-allergies"])
app.include_router(locations.router, prefix="/locations", tags=["locations"])
app.include_router(
    questionnaires.router,
    prefix="/questionnaires",
    tags=["questionnaires"],
)
app.include_router(
    diagnoses.router,
    prefix="/diagnoses",
    tags=["diagnoses"],
)
app.include_router(alerts.router, prefix="/alerts", tags=["alerts"])
app.include_router(
    medical_notes.router,
    prefix="/medical-notes",
    tags=["medical-notes"],
)
