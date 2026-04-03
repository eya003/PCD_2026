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
            detail="Only doctors can manage medications",
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


@router.post("/", response_model=schemas.Medication, status_code=status.HTTP_201_CREATED)
def create_medication(
    payload: schemas.MedicationCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    _ensure_doctor_role(current_user)

    if payload.doctor_id is not None and payload.doctor_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="doctor_id must match the authenticated doctor",
        )

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

    if payload.prescription_id is not None:
        prescription = cruds.get_prescription(db, payload.prescription_id)
        if prescription is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Prescription not found",
            )
        if prescription.patient_id != payload.patient_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Prescription does not belong to this patient",
            )
        if prescription.doctor_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only add medications to your own prescriptions",
            )

    try:
        payload_for_create = payload.model_copy(update={"doctor_id": current_user.id})
        return cruds.create_medication(db=db, payload=payload_for_create)
    except cruds.BusinessRuleError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from None
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Medication conflict",
        ) from None


@router.get("/", response_model=list[schemas.Medication])
def read_medications(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role == "doctor":
        return cruds.get_medications_by_doctor(
            db=db,
            doctor_id=current_user.id,
            skip=skip,
            limit=limit,
        )
    if current_user.role == "family":
        return cruds.get_medications_by_family_user(
            db=db,
            user_id=current_user.id,
            skip=skip,
            limit=limit,
        )
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed")


@router.get("/{medication_id}", response_model=schemas.Medication)
def read_medication(
    medication_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    medication = cruds.get_medication(db, medication_id)
    if medication is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medication not found")

    _ensure_patient_access(
        db,
        current_user=current_user,
        patient_id=medication.patient_id,
    )
    return medication


@router.put("/{medication_id}", response_model=schemas.Medication)
def update_medication(
    medication_id: int,
    payload: schemas.MedicationUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    _ensure_doctor_role(current_user)

    db_medication = cruds.get_medication(db, medication_id)
    if db_medication is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medication not found")

    if db_medication.doctor_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the prescribing doctor can update this medication",
        )

    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields provided for update",
        )

    effective_start_date = (
        payload.start_date
        if "start_date" in updates
        else db_medication.start_date
    )
    effective_end_date = (
        payload.end_date
        if "end_date" in updates
        else db_medication.end_date
    )
    if (
        effective_end_date is not None
        and effective_start_date is not None
        and effective_end_date < effective_start_date
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="end_date must be on or after start_date",
        )

    if payload.patient_id is not None:
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

    if payload.doctor_id is not None and payload.doctor_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="doctor_id cannot be changed to another doctor",
        )

    if payload.prescription_id is not None:
        prescription = cruds.get_prescription(db, payload.prescription_id)
        if prescription is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Prescription not found",
            )
        target_patient_id = payload.patient_id or db_medication.patient_id
        if prescription.patient_id != target_patient_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Prescription does not belong to this patient",
            )
        if prescription.doctor_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only attach your own prescriptions",
            )

    try:
        return cruds.update_medication(
            db=db,
            db_medication=db_medication,
            payload=payload,
        )
    except cruds.BusinessRuleError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from None
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Medication conflict",
        ) from None


@router.patch("/{medication_id}/complete", response_model=schemas.Medication)
def mark_medication_completed(
    medication_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    _ensure_doctor_role(current_user)
    db_medication = cruds.get_medication(db, medication_id)
    if db_medication is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medication not found")
    if db_medication.doctor_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the prescribing doctor can complete this medication",
        )
    try:
        return cruds.set_medication_status(
            db=db,
            db_medication=db_medication,
            status_value=cruds.MEDICATION_STATUS_COMPLETED,
        )
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Unable to complete medication",
        ) from None


@router.patch("/{medication_id}/cancel", response_model=schemas.Medication)
def cancel_medication(
    medication_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    _ensure_doctor_role(current_user)
    db_medication = cruds.get_medication(db, medication_id)
    if db_medication is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medication not found")
    if db_medication.doctor_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the prescribing doctor can cancel this medication",
        )
    try:
        return cruds.set_medication_status(
            db=db,
            db_medication=db_medication,
            status_value=cruds.MEDICATION_STATUS_CANCELLED,
        )
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Unable to cancel medication",
        ) from None

@router.delete("/{medication_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_medication(
    medication_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    _ensure_doctor_role(current_user)

    db_medication = cruds.get_medication(db, medication_id)
    if db_medication is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medication not found")
    if db_medication.doctor_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the prescribing doctor can delete this medication",
        )

    try:
        cruds.delete_medication(db=db, db_medication=db_medication)
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Unable to delete medication",
        ) from None
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{medication_id}/intakes", response_model=list[schemas.MedicationIntake])
def read_medication_intakes(
    medication_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    medication = cruds.get_medication(db, medication_id)
    if medication is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medication not found")

    _ensure_patient_access(
        db,
        current_user=current_user,
        patient_id=medication.patient_id,
    )
    return cruds.get_intakes_by_medication(
        db=db,
        medication_id=medication_id,
        skip=skip,
        limit=limit,
    )
