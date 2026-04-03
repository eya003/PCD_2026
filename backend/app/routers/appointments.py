from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import cruds, schemas
from ..deps import get_current_user, get_db

router = APIRouter()


@router.post("/", response_model=schemas.Appointment, status_code=status.HTTP_201_CREATED)
def create_appointment(
    payload: schemas.AppointmentCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role != "doctor":
        raise HTTPException(status_code=403, detail="Not allowed")
    if payload.doctor_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not allowed")

    patient = cruds.get_patient(db, payload.patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")

    doctor = cruds.get_user(db, payload.doctor_id)
    if doctor is None or doctor.role != "doctor":
        raise HTTPException(status_code=404, detail="Doctor user not found")
    if not cruds.is_doctor_linked_to_patient(
        db,
        doctor_id=payload.doctor_id,
        patient_id=payload.patient_id,
    ):
        raise HTTPException(
            status_code=403,
            detail="Doctor is not linked to this patient",
        )

    try:
        return cruds.create_appointment(db=db, payload=payload)
    except cruds.BusinessRuleError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from None
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Appointment conflict") from None


@router.get("/", response_model=list[schemas.Appointment])
def read_appointments(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role != "doctor":
        raise HTTPException(status_code=403, detail="Not allowed")
    return cruds.get_appointments_by_doctor(
        db=db,
        doctor_id=current_user.id,
        skip=skip,
        limit=limit,
    )


@router.get("/{appointment_id}", response_model=schemas.Appointment)
def read_appointment(
    appointment_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role != "doctor":
        raise HTTPException(status_code=403, detail="Not allowed")

    appointment = cruds.get_appointment(db, appointment_id)
    if appointment is None:
        raise HTTPException(status_code=404, detail="Appointment not found")
    if appointment.doctor_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not allowed")
    return appointment


@router.put("/{appointment_id}", response_model=schemas.Appointment)
def update_appointment(
    appointment_id: int,
    payload: schemas.AppointmentUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role != "doctor":
        raise HTTPException(status_code=403, detail="Not allowed")

    db_appointment = cruds.get_appointment(db, appointment_id)
    if db_appointment is None:
        raise HTTPException(status_code=404, detail="Appointment not found")
    if db_appointment.doctor_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not allowed")

    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(status_code=400, detail="No fields provided for update")

    if payload.patient_id is not None:
        patient = cruds.get_patient(db, payload.patient_id)
        if patient is None:
            raise HTTPException(status_code=404, detail="Patient not found")
        if not cruds.is_doctor_linked_to_patient(
            db,
            doctor_id=current_user.id,
            patient_id=payload.patient_id,
        ):
            raise HTTPException(
                status_code=403,
                detail="Doctor is not linked to this patient",
            )

    if payload.doctor_id is not None:
        doctor = cruds.get_user(db, payload.doctor_id)
        if doctor is None or doctor.role != "doctor":
            raise HTTPException(status_code=404, detail="Doctor user not found")
        if payload.doctor_id != current_user.id:
            raise HTTPException(status_code=403, detail="Not allowed")

    try:
        return cruds.update_appointment(
            db=db,
            db_appointment=db_appointment,
            payload=payload,
        )
    except cruds.BusinessRuleError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from None
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Appointment conflict") from None


@router.patch("/{appointment_id}/complete", response_model=schemas.Appointment)
def mark_appointment_complete(
    appointment_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role != "doctor":
        raise HTTPException(status_code=403, detail="Not allowed")

    db_appointment = cruds.get_appointment(db, appointment_id)
    if db_appointment is None:
        raise HTTPException(status_code=404, detail="Appointment not found")
    if db_appointment.doctor_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not allowed")

    try:
        return cruds.mark_appointment_completed(
            db=db,
            db_appointment=db_appointment,
        )
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Appointment conflict") from None


@router.delete("/{appointment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_appointment(
    appointment_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role != "doctor":
        raise HTTPException(status_code=403, detail="Not allowed")

    db_appointment = cruds.get_appointment(db, appointment_id)
    if db_appointment is None:
        raise HTTPException(status_code=404, detail="Appointment not found")
    if db_appointment.doctor_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not allowed")

    try:
        cruds.delete_appointment(db=db, db_appointment=db_appointment)
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Unable to delete appointment") from None
    return Response(status_code=status.HTTP_204_NO_CONTENT)
