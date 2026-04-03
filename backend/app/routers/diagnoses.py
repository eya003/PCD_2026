from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import cruds, schemas
from ..deps import get_db

router = APIRouter()


@router.post("/", response_model=schemas.Diagnosis, status_code=status.HTTP_201_CREATED)
def create_diagnosis(payload: schemas.DiagnosisCreate, db: Session = Depends(get_db)):
    patient = cruds.get_patient(db, payload.patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")

    if payload.doctor_id is not None:
        doctor = cruds.get_user(db, payload.doctor_id)
        if doctor is None or doctor.role != "doctor":
            raise HTTPException(status_code=404, detail="Doctor user not found")

    if payload.questionnaire_id is not None:
        questionnaire = cruds.get_questionnaire(db, payload.questionnaire_id)
        if questionnaire is None:
            raise HTTPException(status_code=404, detail="Questionnaire not found")
        if questionnaire.patient_id != payload.patient_id:
            raise HTTPException(
                status_code=400,
                detail="Questionnaire does not belong to patient",
            )

    try:
        return cruds.create_diagnosis(db=db, payload=payload)
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Diagnosis conflict") from None


@router.get("/", response_model=list[schemas.Diagnosis])
def read_diagnoses(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return cruds.get_diagnoses(db=db, skip=skip, limit=limit)


@router.get("/{diagnosis_id}", response_model=schemas.Diagnosis)
def read_diagnosis(diagnosis_id: int, db: Session = Depends(get_db)):
    diagnosis = cruds.get_diagnosis(db, diagnosis_id)
    if diagnosis is None:
        raise HTTPException(status_code=404, detail="Diagnosis not found")
    return diagnosis


@router.put("/{diagnosis_id}", response_model=schemas.Diagnosis)
def update_diagnosis(
    diagnosis_id: int,
    payload: schemas.DiagnosisUpdate,
    db: Session = Depends(get_db),
):
    db_diagnosis = cruds.get_diagnosis(db, diagnosis_id)
    if db_diagnosis is None:
        raise HTTPException(status_code=404, detail="Diagnosis not found")

    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(status_code=400, detail="No fields provided for update")

    effective_patient_id = (
        payload.patient_id if payload.patient_id is not None else db_diagnosis.patient_id
    )

    if payload.patient_id is not None:
        patient = cruds.get_patient(db, payload.patient_id)
        if patient is None:
            raise HTTPException(status_code=404, detail="Patient not found")

    if "doctor_id" in updates and payload.doctor_id is not None:
        doctor = cruds.get_user(db, payload.doctor_id)
        if doctor is None or doctor.role != "doctor":
            raise HTTPException(status_code=404, detail="Doctor user not found")

    if "questionnaire_id" in updates and payload.questionnaire_id is not None:
        questionnaire = cruds.get_questionnaire(db, payload.questionnaire_id)
        if questionnaire is None:
            raise HTTPException(status_code=404, detail="Questionnaire not found")
        if questionnaire.patient_id != effective_patient_id:
            raise HTTPException(
                status_code=400,
                detail="Questionnaire does not belong to patient",
            )

    try:
        return cruds.update_diagnosis(
            db=db,
            db_diagnosis=db_diagnosis,
            payload=payload,
        )
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Diagnosis conflict") from None


@router.delete("/{diagnosis_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_diagnosis(diagnosis_id: int, db: Session = Depends(get_db)):
    db_diagnosis = cruds.get_diagnosis(db, diagnosis_id)
    if db_diagnosis is None:
        raise HTTPException(status_code=404, detail="Diagnosis not found")

    try:
        cruds.delete_diagnosis(db=db, db_diagnosis=db_diagnosis)
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Unable to delete diagnosis") from None
    return Response(status_code=status.HTTP_204_NO_CONTENT)
