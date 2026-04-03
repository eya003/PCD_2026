from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import cruds, schemas
from ..deps import get_db

router = APIRouter()


@router.post("/", response_model=schemas.MedicalNote, status_code=status.HTTP_201_CREATED)
def create_medical_note(payload: schemas.MedicalNoteCreate, db: Session = Depends(get_db)):
    patient = cruds.get_patient(db, payload.patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")

    if payload.doctor_id is not None:
        doctor = cruds.get_user(db, payload.doctor_id)
        if doctor is None or doctor.role != "doctor":
            raise HTTPException(status_code=404, detail="Doctor user not found")

    try:
        return cruds.create_medical_note(db=db, payload=payload)
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Medical note conflict") from None


@router.get("/", response_model=list[schemas.MedicalNote])
def read_medical_notes(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return cruds.get_medical_notes(db=db, skip=skip, limit=limit)


@router.get("/{note_id}", response_model=schemas.MedicalNote)
def read_medical_note(note_id: int, db: Session = Depends(get_db)):
    note = cruds.get_medical_note(db, note_id)
    if note is None:
        raise HTTPException(status_code=404, detail="Medical note not found")
    return note


@router.put("/{note_id}", response_model=schemas.MedicalNote)
def update_medical_note(
    note_id: int,
    payload: schemas.MedicalNoteUpdate,
    db: Session = Depends(get_db),
):
    db_note = cruds.get_medical_note(db, note_id)
    if db_note is None:
        raise HTTPException(status_code=404, detail="Medical note not found")

    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(status_code=400, detail="No fields provided for update")

    if payload.patient_id is not None:
        patient = cruds.get_patient(db, payload.patient_id)
        if patient is None:
            raise HTTPException(status_code=404, detail="Patient not found")

    if "doctor_id" in updates and payload.doctor_id is not None:
        doctor = cruds.get_user(db, payload.doctor_id)
        if doctor is None or doctor.role != "doctor":
            raise HTTPException(status_code=404, detail="Doctor user not found")

    try:
        return cruds.update_medical_note(db=db, db_note=db_note, payload=payload)
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Medical note conflict") from None


@router.delete("/{note_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_medical_note(note_id: int, db: Session = Depends(get_db)):
    db_note = cruds.get_medical_note(db, note_id)
    if db_note is None:
        raise HTTPException(status_code=404, detail="Medical note not found")

    try:
        cruds.delete_medical_note(db=db, db_note=db_note)
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Unable to delete medical note") from None
    return Response(status_code=status.HTTP_204_NO_CONTENT)
