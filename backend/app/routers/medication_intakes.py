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
    "/",
    response_model=schemas.MedicationIntake,
    status_code=status.HTTP_201_CREATED,
)
def create_medication_intake(
    payload: schemas.MedicationIntakeCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role != "family":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only family members can submit medication intake follow-up",
        )

    medication = cruds.get_medication(db, payload.medication_id)
    if medication is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Medication not found",
        )

    if not cruds.is_family_linked_to_patient(
        db,
        user_id=current_user.id,
        patient_id=medication.patient_id,
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Family user is not linked to this patient",
        )

    try:
        return cruds.create_medication_intake(
            db=db,
            payload=payload,
            validated_by=current_user.id,
        )
    except cruds.BusinessRuleError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from None
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Medication intake conflict",
        ) from None


@router.get("/", response_model=list[schemas.MedicationIntake])
def read_medication_intakes(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role == "doctor":
        return cruds.get_medication_intakes_by_doctor(
            db=db,
            doctor_id=current_user.id,
            skip=skip,
            limit=limit,
        )
    if current_user.role == "family":
        return cruds.get_medication_intakes_by_family_user(
            db=db,
            user_id=current_user.id,
            skip=skip,
            limit=limit,
        )
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed")


@router.get("/{intake_id}", response_model=schemas.MedicationIntake)
def read_medication_intake(
    intake_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    intake = cruds.get_medication_intake(db, intake_id)
    if intake is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Medication intake not found",
        )

    medication = cruds.get_medication(db, intake.medication_id)
    if medication is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medication not found")

    _ensure_patient_access(
        db,
        current_user=current_user,
        patient_id=medication.patient_id,
    )
    return intake
