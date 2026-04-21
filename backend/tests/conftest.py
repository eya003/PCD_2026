import os
import sys
from datetime import date
from pathlib import Path
from urllib.parse import quote_plus
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session, sessionmaker

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app import models
from app.deps import get_db
from app.routers import medication_calendar, medication_intakes, medications, prescriptions
from app.security import create_access_token


def _build_test_database_url() -> str:
    explicit_url = os.getenv("TEST_DATABASE_URL")
    if explicit_url:
        return explicit_url

    db_user = os.getenv("DB_USER", "postgres")
    db_password = quote_plus(os.getenv("DB_PASSWORD", "pcd.123@!!"))
    db_host = os.getenv("DB_HOST", "localhost")
    db_port = os.getenv("DB_PORT", "5432")
    db_name = os.getenv("DB_NAME", "pcd")
    return f"postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"


@pytest.fixture(scope="session")
def test_engine():
    engine = create_engine(_build_test_database_url(), future=True)
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
    except Exception as exc:  # pragma: no cover - infrastructure dependent
        pytest.skip(f"PostgreSQL is not reachable for tests: {exc}")

    yield engine
    engine.dispose()


@pytest.fixture
def db_session(test_engine) -> Session:
    schema_name = f"pytest_{uuid4().hex}"
    quoted_schema = f'"{schema_name}"'

    with test_engine.begin() as connection:
        connection.execute(text(f"CREATE SCHEMA {quoted_schema}"))

    connection = test_engine.connect()
    connection.execute(text(f"SET search_path TO {quoted_schema}"))
    models.Base.metadata.create_all(bind=connection)

    testing_session_factory = sessionmaker(
        autocommit=False,
        autoflush=False,
        bind=connection,
    )
    session = testing_session_factory()

    try:
        yield session
    finally:
        session.close()
        connection.close()
        with test_engine.begin() as cleanup_connection:
            cleanup_connection.execute(
                text(f"DROP SCHEMA IF EXISTS {quoted_schema} CASCADE")
            )


@pytest.fixture
def app(db_session: Session):
    test_app = FastAPI()
    test_app.include_router(
        medications.router,
        prefix="/medications",
        tags=["medications"],
    )
    test_app.include_router(
        medication_intakes.router,
        prefix="/medication-intakes",
        tags=["medication-intakes"],
    )
    test_app.include_router(
        medication_calendar.router,
        prefix="/medication-calendar",
        tags=["medication-calendar"],
    )
    test_app.include_router(prescriptions.router)

    def _override_get_db():
        yield db_session

    test_app.dependency_overrides[get_db] = _override_get_db
    return test_app


@pytest.fixture
def client(app):
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
def seeded_access_context(db_session: Session):
    unique = uuid4().hex[:8]

    doctor = models.User(
        cin=f"DOC{unique.upper()}",
        email=f"doctor.{unique}@example.com",
        first_name="Dr",
        last_name="House",
        role="doctor",
        password_hash="test_hash",
    )
    family_admin = models.User(
        cin=f"FAMADM{unique.upper()}",
        email=f"family.admin.{unique}@example.com",
        first_name="Alice",
        last_name="Admin",
        role="family",
        password_hash="test_hash",
    )
    family_viewer = models.User(
        cin=f"FAMVIW{unique.upper()}",
        email=f"family.viewer.{unique}@example.com",
        first_name="Bob",
        last_name="Viewer",
        role="family",
        password_hash="test_hash",
    )
    patient = models.Patient(
        patient_code=f"PAT-{unique.upper()}",
        first_name="Jean",
        last_name="Patient",
        birth_date=date(1942, 5, 11),
        cin=f"P{unique.upper()}",
    )

    db_session.add_all([doctor, family_admin, family_viewer, patient])
    db_session.flush()

    db_session.add(
        models.DoctorPatient(
            doctor_id=doctor.id,
            patient_id=patient.id,
        )
    )
    db_session.add(
        models.FamilyPatient(
            user_id=family_admin.id,
            patient_id=patient.id,
            family_role="admin",
            relation_to_patient="child",
        )
    )
    db_session.add(
        models.FamilyPatient(
            user_id=family_viewer.id,
            patient_id=patient.id,
            family_role="viewer",
            relation_to_patient="sibling",
        )
    )
    db_session.commit()

    def _headers_for(user: models.User) -> dict[str, str]:
        token = create_access_token(str(user.id), role=user.role)
        return {"Authorization": f"Bearer {token}"}

    return {
        "patient": patient,
        "doctor": doctor,
        "family_admin": family_admin,
        "family_viewer": family_viewer,
        "doctor_headers": _headers_for(doctor),
        "family_admin_headers": _headers_for(family_admin),
        "family_viewer_headers": _headers_for(family_viewer),
    }
