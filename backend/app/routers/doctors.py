from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import cruds, schemas
from ..deps import get_current_user, get_db

router = APIRouter()


def _ensure_doctor_self_access(
    *,
    db: Session,
    doctor_id: int,
    current_user,
):
    if current_user.role != "doctor":
        raise HTTPException(status_code=403, detail="Not allowed")
    if current_user.id != doctor_id:
        raise HTTPException(status_code=403, detail="Not allowed")

    doctor_user = cruds.get_user(db, doctor_id)
    if doctor_user is None or doctor_user.role != "doctor":
        raise HTTPException(status_code=404, detail="Doctor user not found")


@router.post("/link-patient", response_model=schemas.DoctorPatientLink, status_code=201)
def link_doctor_to_patient(
    payload: schemas.DoctorPatientLinkCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role != "doctor":
        raise HTTPException(status_code=403, detail="Not allowed")

    doctor_user = cruds.get_user(db, payload.doctor_id)
    if doctor_user is None or doctor_user.role != "doctor":
        raise HTTPException(status_code=404, detail="Doctor user not found")

    patient = cruds.get_patient(db, payload.patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")

    existing_link = cruds.get_doctor_patient_link(
        db, doctor_id=payload.doctor_id, patient_id=payload.patient_id
    )
    if existing_link:
        raise HTTPException(status_code=400, detail="Doctor already linked to patient")

    try:
        return cruds.link_doctor_to_patient(
            db=db,
            doctor_id=payload.doctor_id,
            patient_id=payload.patient_id,
        )
    except cruds.RoleConstraintError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from None
    except cruds.BusinessRuleError as exc:
        status_code = 404 if str(exc) == "Patient not found" else 400
        raise HTTPException(status_code=status_code, detail=str(exc)) from None
    except IntegrityError:
        raise HTTPException(status_code=400, detail="Unable to link doctor") from None


@router.get("/{doctor_id}/patients", response_model=list[schemas.Patient])
def read_doctor_patients(
    doctor_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role != "doctor":
        raise HTTPException(status_code=403, detail="Not allowed")

    doctor_user = cruds.get_user(db, doctor_id)
    if doctor_user is None or doctor_user.role != "doctor":
        raise HTTPException(status_code=404, detail="Doctor user not found")

    return cruds.get_patients_by_doctor(db=db, doctor_id=doctor_id, skip=skip, limit=limit)


@router.get("/{doctor_id}/appointments", response_model=list[schemas.Appointment])
def read_doctor_appointments(
    doctor_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    _ensure_doctor_self_access(
        db=db,
        doctor_id=doctor_id,
        current_user=current_user,
    )

    return cruds.get_appointments_by_doctor(
        db=db,
        doctor_id=doctor_id,
        skip=skip,
        limit=limit,
    )


@router.get(
    "/{doctor_id}/appointments/",
    response_model=list[schemas.Appointment],
    include_in_schema=False,
)
def read_doctor_appointments_trailing_slash(
    doctor_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    _ensure_doctor_self_access(
        db=db,
        doctor_id=doctor_id,
        current_user=current_user,
    )
    return cruds.get_appointments_by_doctor(
        db=db,
        doctor_id=doctor_id,
        skip=skip,
        limit=limit,
    )


@router.get("/{doctor_id}/medications", response_model=list[schemas.Medication])
def read_doctor_medications(
    doctor_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    _ensure_doctor_self_access(db=db, doctor_id=doctor_id, current_user=current_user)
    return cruds.get_medications_by_doctor(
        db=db,
        doctor_id=doctor_id,
        skip=skip,
        limit=limit,
    )


@router.delete(
    "/{doctor_id}/patients/{patient_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def unlink_doctor_from_patient(
    doctor_id: int,
    patient_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role != "doctor":
        raise HTTPException(status_code=403, detail="Not allowed")

    doctor_user = cruds.get_user(db, doctor_id)
    if doctor_user is None or doctor_user.role != "doctor":
        raise HTTPException(status_code=404, detail="Doctor user not found")

    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")

    link = cruds.get_doctor_patient_link(db, doctor_id=doctor_id, patient_id=patient_id)
    if link is None:
        raise HTTPException(status_code=404, detail="Doctor-patient link not found")

    try:
        cruds.delete_doctor_patient_link(db=db, doctor_id=doctor_id, patient_id=patient_id)
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Unable to delete doctor-patient link") from None
    return Response(status_code=status.HTTP_204_NO_CONTENT)
