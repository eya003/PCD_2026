from fastapi import APIRouter, Depends, HTTPException, status
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


def _ensure_family_admin_can_record_location(
    db: Session,
    *,
    current_user,
    patient_id: int,
):
    if current_user.role != "family":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only family admin can record location",
        )

    requester_link = cruds.get_family_patient_link(
        db,
        user_id=current_user.id,
        patient_id=patient_id,
    )
    if requester_link is None or requester_link.family_role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only family admin can record location",
        )


@router.post("/", response_model=schemas.PatientLocation, status_code=status.HTTP_201_CREATED)
def create_location(
    payload: schemas.PatientLocationCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    patient = cruds.get_patient(db, payload.patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")

    _ensure_family_admin_can_record_location(
        db,
        current_user=current_user,
        patient_id=payload.patient_id,
    )

    try:
        return cruds.create_patient_location(db=db, payload=payload)
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Location conflict") from None


@router.get("/{location_id}", response_model=schemas.PatientLocation)
def read_location(
    location_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    location = cruds.get_patient_location(db, location_id)
    if location is None:
        raise HTTPException(status_code=404, detail="Location not found")

    _ensure_patient_access(
        db,
        current_user=current_user,
        patient_id=location.patient_id,
    )

    return location
