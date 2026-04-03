from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import cruds, schemas
from ..deps import get_db

router = APIRouter()


@router.post("/", response_model=schemas.Questionnaire, status_code=status.HTTP_201_CREATED)
def create_questionnaire(
    payload: schemas.QuestionnaireCreate,
    db: Session = Depends(get_db),
):
    patient = cruds.get_patient(db, payload.patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")

    if payload.filled_by is not None:
        filled_by_user = cruds.get_user(db, payload.filled_by)
        if filled_by_user is None:
            raise HTTPException(status_code=404, detail="Filled-by user not found")

    try:
        return cruds.create_questionnaire(db=db, payload=payload)
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Questionnaire conflict") from None


@router.get("/", response_model=list[schemas.Questionnaire])
def read_questionnaires(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return cruds.get_questionnaires(db=db, skip=skip, limit=limit)


@router.get("/{questionnaire_id}", response_model=schemas.Questionnaire)
def read_questionnaire(questionnaire_id: int, db: Session = Depends(get_db)):
    questionnaire = cruds.get_questionnaire(db, questionnaire_id)
    if questionnaire is None:
        raise HTTPException(status_code=404, detail="Questionnaire not found")
    return questionnaire


@router.put("/{questionnaire_id}", response_model=schemas.Questionnaire)
def update_questionnaire(
    questionnaire_id: int,
    payload: schemas.QuestionnaireUpdate,
    db: Session = Depends(get_db),
):
    db_questionnaire = cruds.get_questionnaire(db, questionnaire_id)
    if db_questionnaire is None:
        raise HTTPException(status_code=404, detail="Questionnaire not found")

    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(status_code=400, detail="No fields provided for update")

    if payload.patient_id is not None:
        patient = cruds.get_patient(db, payload.patient_id)
        if patient is None:
            raise HTTPException(status_code=404, detail="Patient not found")

    if "filled_by" in updates and payload.filled_by is not None:
        filled_by_user = cruds.get_user(db, payload.filled_by)
        if filled_by_user is None:
            raise HTTPException(status_code=404, detail="Filled-by user not found")

    try:
        return cruds.update_questionnaire(
            db=db,
            db_questionnaire=db_questionnaire,
            payload=payload,
        )
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Questionnaire conflict") from None


@router.delete("/{questionnaire_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_questionnaire(questionnaire_id: int, db: Session = Depends(get_db)):
    db_questionnaire = cruds.get_questionnaire(db, questionnaire_id)
    if db_questionnaire is None:
        raise HTTPException(status_code=404, detail="Questionnaire not found")

    try:
        cruds.delete_questionnaire(db=db, db_questionnaire=db_questionnaire)
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Unable to delete questionnaire") from None
    return Response(status_code=status.HTTP_204_NO_CONTENT)
