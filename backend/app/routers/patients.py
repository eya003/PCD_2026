from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import cruds, schemas
from ..deps import get_current_user, get_db

router = APIRouter()


def _ensure_patient_access(
    db: Session,
    *,
    current_user,
    patient_id: int,
):
    if not cruds.can_user_access_patient(db, current_user, patient_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not allowed to access this patient",
        )


def _ensure_family_admin_manage_safe_zone(
    db: Session,
    *,
    current_user,
    patient_id: int,
):
    if current_user.role != "family":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only family admin can update safe zone",
        )

    requester_link = cruds.get_family_patient_link(
        db,
        user_id=current_user.id,
        patient_id=patient_id,
    )
    if requester_link is None or requester_link.family_role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only family admin can update safe zone",
        )


@router.post("/", response_model=schemas.Patient, status_code=201)
def create_patient(
    patient: schemas.PatientCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role != "doctor":
        raise HTTPException(status_code=403, detail="Only doctors can create patients")

    existing_patient = cruds.get_patient_by_code(db, patient.patient_code)
    if existing_patient:
        raise HTTPException(status_code=409, detail="Patient code already exists")

    existing_cin = cruds.get_patient_by_cin(db, patient.cin)
    if existing_cin:
        raise HTTPException(status_code=409, detail="Patient CIN already exists")

    try:
        db_patient = cruds.create_patient(db=db, patient=patient, commit=False)
        cruds.link_doctor_to_patient(
            db=db,
            doctor_id=current_user.id,
            patient_id=db_patient.id,
            commit=False,
        )
        db.commit()
        db.refresh(db_patient)
        return db_patient
    except cruds.RoleConstraintError as exc:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(exc)) from None
    except cruds.BusinessRuleError as exc:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(exc)) from None
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Unable to create patient") from None


@router.get("/", response_model=list[schemas.Patient])
def read_patients(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return cruds.get_patients(db=db, skip=skip, limit=limit)


@router.get("/search", response_model=schemas.Patient)
def search_patient(
    first_name: str,
    last_name: str,
    birth_date: date,
    db: Session = Depends(get_db),
):
    db_patient = cruds.get_patient_by_identity(
        db=db,
        first_name=first_name,
        last_name=last_name,
        birth_date=birth_date,
    )
    if db_patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    return db_patient


@router.get("/autocomplete", response_model=list[schemas.Patient])
def autocomplete_patients(
    q: str = "",
    limit: int = 10,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Recherche patients du médecin par CIN ou nom (correspondance partielle)."""
    if current_user.role != "doctor":
        raise HTTPException(status_code=403, detail="Only doctors can search patients")
    return cruds.search_patients_autocomplete(
        db=db,
        query=q,
        doctor_id=current_user.id,
        limit=min(limit, 20),
    )


@router.get("/{patient_id}/doctors", response_model=list[schemas.User])
def read_patient_doctors(
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
):
    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    return cruds.get_doctors_by_patient(db=db, patient_id=patient_id, skip=skip, limit=limit)


@router.get("/{patient_id}/family-members", response_model=list[schemas.FamilyPatientMember])
def read_patient_family_members(
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
):
    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")

    members = cruds.get_family_members_by_patient(
        db=db,
        patient_id=patient_id,
        skip=skip,
        limit=limit,
    )
    return [
        schemas.FamilyPatientMember(
            user_id=link.user_id,
            patient_id=link.patient_id,
            family_role=link.family_role,
            relation_to_patient=link.relation_to_patient,
            first_name=user.first_name,
            last_name=user.last_name,
            cin=user.cin,
            email=user.email,
        )
        for link, user in members
    ]


@router.get("/{patient_id}/appointments", response_model=list[schemas.Appointment])
def read_patient_appointments(
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    _ensure_patient_access(db, current_user=current_user, patient_id=patient_id)
    return cruds.get_appointments_by_patient(
        db=db,
        patient_id=patient_id,
        skip=skip,
        limit=limit,
    )


@router.get("/{patient_id}/medications", response_model=list[schemas.Medication])
def read_patient_medications(
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    _ensure_patient_access(db, current_user=current_user, patient_id=patient_id)
    return cruds.get_medications_by_patient(
        db=db,
        patient_id=patient_id,
        skip=skip,
        limit=limit,
    )


@router.get(
    "/{patient_id}/active-medications",
    response_model=list[schemas.MedicationSummary],
)
def read_patient_active_medications(
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    _ensure_patient_access(db, current_user=current_user, patient_id=patient_id)
    return cruds.get_medications_by_patient_status(
        db=db,
        patient_id=patient_id,
        status_value=cruds.MEDICATION_STATUS_ACTIVE,
        skip=skip,
        limit=limit,
    )


@router.get(
    "/{patient_id}/completed-medications",
    response_model=list[schemas.MedicationSummary],
)
def read_patient_completed_medications(
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    _ensure_patient_access(db, current_user=current_user, patient_id=patient_id)
    return cruds.get_medications_by_patient_status(
        db=db,
        patient_id=patient_id,
        status_value=cruds.MEDICATION_STATUS_COMPLETED,
        skip=skip,
        limit=limit,
    )


@router.get("/{patient_id}/medication-intakes", response_model=list[schemas.MedicationIntake])
def read_patient_medication_intakes(
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    _ensure_patient_access(db, current_user=current_user, patient_id=patient_id)
    return cruds.get_intakes_by_patient(db=db, patient_id=patient_id, skip=skip, limit=limit)


@router.get("/{patient_id}/locations", response_model=list[schemas.PatientLocation])
def read_patient_locations(
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
):
    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    return cruds.get_locations_by_patient(db=db, patient_id=patient_id, skip=skip, limit=limit)


@router.get("/{patient_id}/questionnaires", response_model=list[schemas.Questionnaire])
def read_patient_questionnaires(
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
):
    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    return cruds.get_questionnaires_by_patient(
        db=db,
        patient_id=patient_id,
        skip=skip,
        limit=limit,
    )


@router.get("/{patient_id}/diagnoses", response_model=list[schemas.Diagnosis])
def read_patient_diagnoses(
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
):
    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    return cruds.get_diagnoses_by_patient(
        db=db,
        patient_id=patient_id,
        skip=skip,
        limit=limit,
    )


@router.get("/{patient_id}/alerts", response_model=list[schemas.Alert])
def read_patient_alerts(
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
):
    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    return cruds.get_alerts_by_patient(
        db=db,
        patient_id=patient_id,
        skip=skip,
        limit=limit,
    )


@router.get("/{patient_id}/medical-notes", response_model=list[schemas.MedicalNote])
def read_patient_medical_notes(
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
):
    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    return cruds.get_medical_notes_by_patient(
        db=db,
        patient_id=patient_id,
        skip=skip,
        limit=limit,
    )


@router.get("/{patient_id}/last-location", response_model=schemas.PatientLocation)
def read_patient_last_location(patient_id: int, db: Session = Depends(get_db)):
    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")

    location = cruds.get_last_location_for_patient(db=db, patient_id=patient_id)
    if location is None:
        raise HTTPException(status_code=404, detail="Location not found")
    return location


@router.get("/{patient_id}/safe-zone", response_model=schemas.PatientSafeZone)
def read_patient_safe_zone(
    patient_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")

    _ensure_patient_access(db, current_user=current_user, patient_id=patient_id)

    safe_zone = cruds.get_patient_safe_zone(db=db, patient_id=patient_id)
    if safe_zone is None:
        raise HTTPException(status_code=404, detail="Safe zone not found")
    return safe_zone


@router.put("/{patient_id}/safe-zone", response_model=schemas.PatientSafeZone)
def upsert_patient_safe_zone(
    patient_id: int,
    payload: schemas.PatientSafeZoneUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")

    _ensure_family_admin_manage_safe_zone(
        db,
        current_user=current_user,
        patient_id=patient_id,
    )

    try:
        return cruds.upsert_patient_safe_zone(
            db=db,
            patient_id=patient_id,
            origin_latitude=payload.origin_latitude,
            origin_longitude=payload.origin_longitude,
            radius_meters=payload.radius_meters,
            updated_by=current_user.id,
        )
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Safe zone update conflict") from None


@router.put("/{patient_id}", response_model=schemas.Patient)
def update_patient(
    patient_id: int,
    payload: schemas.PatientUpdate,
    db: Session = Depends(get_db),
):
    db_patient = cruds.get_patient(db, patient_id)
    if db_patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")

    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(status_code=400, detail="No fields provided for update")

    patient_code = updates.get("patient_code")
    if patient_code:
        existing = cruds.get_patient_by_code(db, patient_code)
        if existing and existing.id != patient_id:
            raise HTTPException(status_code=409, detail="Patient code already exists")

    cin = updates.get("cin")
    if cin:
        existing_cin = cruds.get_patient_by_cin(db, cin)
        if existing_cin and existing_cin.id != patient_id:
            raise HTTPException(status_code=409, detail="Patient CIN already exists")

    try:
        return cruds.update_patient(db=db, db_patient=db_patient, payload=payload)
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Patient update conflict") from None


@router.delete("/{patient_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_patient(patient_id: int, db: Session = Depends(get_db)):
    db_patient = cruds.get_patient(db, patient_id)
    if db_patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")

    try:
        cruds.delete_patient(db=db, db_patient=db_patient)
    except IntegrityError:
        raise HTTPException(
            status_code=409,
            detail="Patient cannot be deleted due to related records",
        ) from None
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{patient_id}", response_model=schemas.Patient)
def read_patient(patient_id: int, db: Session = Depends(get_db)):
    db_patient = cruds.get_patient(db=db, patient_id=patient_id)
    if db_patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    return db_patient
