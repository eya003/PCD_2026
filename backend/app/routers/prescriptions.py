from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import cruds, schemas
from ..deps import get_current_user, get_db

router = APIRouter()


def _ensure_doctor_role(current_user):
    if current_user.role != "doctor":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only doctors can manage prescriptions",
        )


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
    "/prescriptions/",
    response_model=schemas.Prescription,
    status_code=status.HTTP_201_CREATED,
)
def create_prescription(
    payload: schemas.PrescriptionCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    _ensure_doctor_role(current_user)

    patient = cruds.get_patient(db, payload.patient_id)
    if patient is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Patient not found")

    if not cruds.is_doctor_linked_to_patient(
        db,
        doctor_id=current_user.id,
        patient_id=payload.patient_id,
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Doctor is not linked to this patient",
        )

    try:
        return cruds.create_prescription(
            db,
            patient_id=payload.patient_id,
            doctor_id=current_user.id,
            prescription_date=payload.prescription_date,
            notes=payload.notes,
            status=payload.status,
        )
    except cruds.BusinessRuleError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from None
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Prescription conflict",
        ) from None


@router.get("/prescriptions/", response_model=list[schemas.Prescription])
def read_prescriptions(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role == "doctor":
        return cruds.get_prescriptions_by_doctor(
            db=db,
            doctor_id=current_user.id,
            skip=skip,
            limit=limit,
        )
    if current_user.role == "family":
        return cruds.get_prescriptions_by_family_user(
            db=db,
            user_id=current_user.id,
            skip=skip,
            limit=limit,
        )
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed")


@router.get("/prescriptions/{prescription_id}", response_model=schemas.Prescription)
def read_prescription(
    prescription_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    prescription = cruds.get_prescription(db, prescription_id)
    if prescription is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prescription not found",
        )

    _ensure_patient_access(db, current_user=current_user, patient_id=prescription.patient_id)
    return prescription


@router.patch(
    "/prescriptions/{prescription_id}",
    response_model=schemas.Prescription,
)
def update_prescription(
    prescription_id: int,
    payload: schemas.PrescriptionUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    _ensure_doctor_role(current_user)

    prescription = cruds.get_prescription(db, prescription_id)
    if prescription is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prescription not found",
        )
    if prescription.doctor_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the prescribing doctor can update this prescription",
        )

    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields provided for update",
        )

    try:
        return cruds.update_prescription(
            db=db,
            db_prescription=prescription,
            payload=payload,
        )
    except cruds.BusinessRuleError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from None
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Prescription conflict",
        ) from None


@router.post(
    "/prescriptions/with-items",
    response_model=schemas.PrescriptionWithItemsResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_prescription_with_items(
    payload: schemas.PrescriptionWithItemsCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Crée une ordonnance et tous ses médicaments en une seule transaction atomique."""
    _ensure_doctor_role(current_user)

    patient = cruds.get_patient(db, payload.patient_id)
    if patient is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient not found",
        )
    if not cruds.is_doctor_linked_to_patient(
        db,
        doctor_id=current_user.id,
        patient_id=payload.patient_id,
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Doctor is not linked to this patient",
        )

    medications_data = [m.model_dump() for m in payload.medications]
    try:
        prescription, medications = cruds.create_prescription_with_medications(
            db=db,
            patient_id=payload.patient_id,
            doctor_id=current_user.id,
            prescription_date=payload.prescription_date,
            notes=payload.notes,
            status=payload.status,
            medications_data=medications_data,
        )
        return schemas.PrescriptionWithItemsResponse(
            prescription=schemas.Prescription.model_validate(prescription),
            medications=[schemas.Medication.model_validate(m) for m in medications],
        )
    except cruds.BusinessRuleError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from None
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Prescription or medication conflict",
        ) from None


@router.get(
    "/patients/{patient_id}/prescriptions",
    response_model=list[schemas.Prescription],
)
def read_patient_prescriptions(
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
    return cruds.get_prescriptions_by_patient(
        db=db,
        patient_id=patient_id,
        skip=skip,
        limit=limit,
    )
