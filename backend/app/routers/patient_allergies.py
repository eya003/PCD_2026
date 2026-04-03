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


@router.post(
    "/patients/{patient_id}/allergies",
    response_model=schemas.PatientAllergy,
    status_code=status.HTTP_201_CREATED,
)
def create_patient_allergy(
    patient_id: int,
    payload: schemas.PatientAllergyCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role != "doctor":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only doctors can add patient allergies",
        )

    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Patient not found")

    if not cruds.is_doctor_linked_to_patient(
        db,
        doctor_id=current_user.id,
        patient_id=patient_id,
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Doctor is not linked to this patient",
        )

    try:
        return cruds.create_patient_allergy(
            db=db,
            patient_id=patient_id,
            doctor_id=current_user.id,
            payload=payload,
        )
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Allergy conflict",
        ) from None


@router.get(
    "/patients/{patient_id}/allergies",
    response_model=list[schemas.PatientAllergy],
)
def read_patient_allergies(
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Patient not found")

    _ensure_patient_access(db, current_user=current_user, patient_id=patient_id)
    return cruds.get_patient_allergies(
        db=db,
        patient_id=patient_id,
        skip=skip,
        limit=limit,
    )
